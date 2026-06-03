import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';
import 'package:strefa_ciszy/services/event_log_service.dart';

class _LoginPalette {
  static const bodyFont = 'Bose (Regular)';
  static const headlineFont = 'Bose-Headline (Bold)';
  static const bg = Color(0xFFF4F6F7);
  static const bgEnd = Color(0xFFE8EEF1);
  static const surface = Colors.white;
  static const line = Color(0xFFD4DCE0);
  static const text = Color(0xFF1E2B2F);
  static const muted = Color(0xFF607176);
  static const brand = Color(0xFF2574A9);
  static const danger = Color(0xFFE04747);
}

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';

  const LoginScreen({super.key});
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;
  bool _isLoading = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = 'v.${info.version} _${info.buildNumber}';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _friendlyMessageForCode(String code) {
    return switch (code) {
      'invalid-email' => 'Email nieprawidłowy.',
      'user-disabled' => 'Konto zablokowany.',
      'user-not-found' => 'Nie znaleziono user.',
      'wrong-password' => 'Hasło nieprawidłowo.',
      'too-many-requests' => 'Za dużo prób. Spróbuj później.',
      'invalid-credential' => 'Login nieprawidłowy.',
      'credential-already-in-use' => 'Używany przez inne konto.',
      'expired-action-code' => 'Link wygasł. Wygeneruj go ponownie.',
      _ => 'Wystąpił błąd logowania: $code',
    };
  }

  Future<void> _signIn() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      await cred.user!.getIdToken(true);
      EventLogService.loginSuccess(cred.user!);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainMenuScreen(role: 'admin')),
      );
    } on FirebaseAuthException catch (e) {
      final friendly = _friendlyMessageForCode(e.code);
      EventLogService.loginFailed(_emailCtrl.text.trim(), e.code);
      setState(() => _error = friendly);
    } catch (_) {
      setState(() => _error = 'Mega error. Spróbuj znowu...');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LoginPalette.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_LoginPalette.bg, _LoginPalette.bgEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth >= 700;

              return Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 420 : double.infinity,
                        ),
                        child: _LoginCard(
                          emailCtrl: _emailCtrl,
                          passCtrl: _passCtrl,
                          error: _error,
                          isLoading: _isLoading,
                          onSignIn: _signIn,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 12,
                    left: 14,
                    child: Text(
                      _version.isNotEmpty ? _version : '',
                      style: const TextStyle(
                        fontFamily: _LoginPalette.bodyFont,
                        fontSize: 11,
                        color: _LoginPalette.muted,
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 8,
                    right: 12,
                    child: Image.asset(
                      'assets/images/dev_logo_PILL.png',
                      width: 72,
                      fit: BoxFit.contain,
                      color: _LoginPalette.bgEnd,
                      colorBlendMode: BlendMode.multiply,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final String? error;
  final bool isLoading;
  final VoidCallback onSignIn;

  const _LoginCard({
    required this.emailCtrl,
    required this.passCtrl,
    required this.error,
    required this.isLoading,
    required this.onSignIn,
  });

  static InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      fontFamily: _LoginPalette.bodyFont,
      color: _LoginPalette.muted,
      fontSize: 14,
    ),
    floatingLabelStyle: const TextStyle(
      fontFamily: _LoginPalette.bodyFont,
      color: _LoginPalette.brand,
      fontSize: 13,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _LoginPalette.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _LoginPalette.brand, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _LoginPalette.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _LoginPalette.danger, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    filled: true,
    fillColor: _LoginPalette.surface,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _LoginPalette.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Image.asset(
              'assets/images/strefa_ciszy_logo.png',
              width: 190,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '_Inventory',
              style: TextStyle(
                fontFamily: _LoginPalette.bodyFont,
                fontSize: 14,
                color: _LoginPalette.muted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 36),

          TextField(
            controller: emailCtrl,
            decoration: _fieldDecoration('Email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontFamily: _LoginPalette.bodyFont,
              color: _LoginPalette.text,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passCtrl,
            decoration: _fieldDecoration('Hasło'),
            obscureText: true,
            textInputAction: TextInputAction.done,
            style: const TextStyle(
              fontFamily: _LoginPalette.bodyFont,
              color: _LoginPalette.text,
            ),
            onSubmitted: (_) {
              if (!isLoading) onSignIn();
            },
          ),

          if (error != null) ...[
            const SizedBox(height: 14),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _LoginPalette.bodyFont,
                color: _LoginPalette.danger,
                fontSize: 13,
              ),
            ),
          ],

          const SizedBox(height: 28),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: _LoginPalette.brand,
                foregroundColor: _LoginPalette.surface,
                disabledBackgroundColor: _LoginPalette.line,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontFamily: _LoginPalette.headlineFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Zaloguj się'),
            ),
          ),
        ],
      ),
    );
  }
}
