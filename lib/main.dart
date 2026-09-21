// main.dart

import 'dart:async' show unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strefa_ciszy/offline/offline_api.dart';
import 'package:strefa_ciszy/services/admin_api.dart';
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/services/event_log_service.dart';
import 'package:strefa_ciszy/services/push_router.dart';
import 'package:strefa_ciszy/services/push_service.dart';

import 'firebase_options.dart';
import 'offline/sync_orchestrator_stub.dart'
    if (dart.library.io) 'offline/sync_orchestrator.dart';
import 'screens/login_screen.dart';
import 'screens/main_menu_screen.dart';
import 'widgets/web_scroll_behaviour.dart';

SyncOrchestrator? _syncOrchestrator;
final GlobalKey<NavigatorState> appNavKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    // Explicit, since a browser that can't/won't persist to IndexedDB
    // (privacy settings, "clear on close" extensions, etc.) would otherwise
    // silently fall back to a session that doesn't survive a tab close.
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    EventLogService.unhandledError(
      context: 'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    EventLogService.unhandledError(
      context: 'PlatformDispatcher',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  if (!kReleaseMode) {
    _syncOrchestrator = await SyncOrchestrator.create();
    _syncOrchestrator!.start();
  }

  // await SystemChrome.setPreferredOrientations([
  //   DeviceOrientation.portraitUp,
  //   DeviceOrientation.landscapeRight,
  //   DeviceOrientation.landscapeLeft,
  //   // DeviceOrientation.portraitDown,
  // ]);

  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
      appleProvider: kReleaseMode
          ? AppleProvider.appAttestWithDeviceCheckFallback
          : AppleProvider.debug,
    );
  }

  runApp(const StrefaCiszyApp());
  _postBootstrap();
}

Future<void> _postBootstrap() async {
  try {
    await warmProductCache();
  } catch (e, st) {
    debugPrint('warmProductCache error: $e');
    debugPrint('$st');
  }

  try {
    await ApiService.init();
    await AdminApi.init();
  } catch (e, st) {
    debugPrint('postBootstrap error: $e');
    debugPrint('$st');
  }
}

class KeyboardHidingNavigatorObserver extends NavigatorObserver {
  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _hideKeyboard());
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _hideKeyboard());
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _hideKeyboard());
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

class StrefaCiszyApp extends StatelessWidget {
  const StrefaCiszyApp({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushRouter.instance.start(navKey: appNavKey);
    });
    return MaterialApp(
      navigatorKey: appNavKey,
      title: 'Strefa Ciszy',
      theme: ThemeData(primarySwatch: Colors.blue),
      scrollBehavior: WebScrollBehavior(),
      locale: const Locale('pl', 'PL'),
      supportedLocales: const [Locale('pl', 'PL')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [KeyboardHidingNavigatorObserver()],
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: child,
        );
      },
      home: const AuthGate(),
      // home: kReleaseMode ? const AuthGate() : const DevOfflineTestScreen(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _lastUser;

  static const _wasSignedInKey = 'auth_was_signed_in_v1';
  static const _lastUidKey = 'auth_last_uid_v1';
  static const _lastEmailKey = 'auth_last_email_v1';

  @override
  void initState() {
    super.initState();
    _checkColdStartSessionLoss();
  }

  // Waits for the real first authStateChanges() emission (no arbitrary
  // delay/guess) and, if it's null but this device previously had a
  // successful sign-in recorded, logs it. This is the one moment
  // authUnexpectedSignOut structurally cannot cover, since that check needs
  // an in-memory previous user and _lastUser always starts null on a fresh
  // process — i.e. exactly the "closed the app, reopened it, already logged
  // out" case.
  Future<void> _checkColdStartSessionLoss() async {
    final firstUser = await FirebaseAuth.instance.authStateChanges().first;
    if (firstUser != null) return;

    final prefs = await SharedPreferences.getInstance();
    final wasSignedIn = prefs.getBool(_wasSignedInKey) ?? false;
    if (!wasSignedIn) return;

    await EventLogService.authSessionLostOnLaunch(
      lastKnownUid: prefs.getString(_lastUidKey),
      lastKnownEmail: prefs.getString(_lastEmailKey),
    );
  }

  Future<void> _rememberSignedIn(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wasSignedInKey, true);
    await prefs.setString(_lastUidKey, user.uid);
    if (user.email != null) await prefs.setString(_lastEmailKey, user.email!);
  }

  Future<void> _forgetSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wasSignedInKey);
    await prefs.remove(_lastUidKey);
    await prefs.remove(_lastEmailKey);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!authSnap.hasData) {
          final previousUser = _lastUser;
          if (previousUser != null) {
            if (EventLogService.manualSignOutInProgress) {
              EventLogService.manualSignOutInProgress = false;
              unawaited(_forgetSignedIn());
            } else {
              EventLogService.authUnexpectedSignOut(
                uid: previousUser.uid,
                email: previousUser.email,
              );
            }
          }
          _lastUser = null;
          return const LoginScreen();
        }
        final user = authSnap.data!;
        _lastUser = user;
        EventLogService.flushPendingEvents();
        unawaited(_rememberSignedIn(user));

        // PUSH
        WidgetsBinding.instance.addPostFrameCallback((_) {
          PushService.instance.startForCurrentUser();
        });

        return FutureBuilder<IdTokenResult>(
          future: user.getIdTokenResult(true),
          builder: (ctx, tokenSnap) {
            if (tokenSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (tokenSnap.hasError) {
              EventLogService.authTokenRefreshFailed(
                uid: user.uid,
                email: user.email,
                error: tokenSnap.error!,
              );
            }
            final claims = tokenSnap.data?.claims ?? {};
            final isAdmin = claims['admin'] == true;
            return MainMenuScreen(role: isAdmin ? 'admin' : 'user');
          },
        );
      },
    );
  }
}
