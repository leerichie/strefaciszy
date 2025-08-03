import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';

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
    } catch (_) {
      // swallow; fallback placeholder will show
    }
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

      if (!mounted) return;

      // currently hardcoded role; replace with real role resolution if available
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainMenuScreen(role: 'admin')),
      );
    } on FirebaseAuthException catch (e) {
      final friendly = _friendlyMessageForCode(e.code);
      setState(() => _error = friendly);
    } catch (_) {
      setState(() => _error = 'Nieoczekiwany błąd. Spróbuj ponownie.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 40),
                    Image.asset(
                      'assets/images/strefa_ciszy_logo.png',
                      width: 200,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '_Inventory',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 48),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: 'Hasło'),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_isLoading) _signIn();
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Zaloguj się'),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 8,
              left: 12,
              child: Text(
                _version.isNotEmpty ? _version : 'v.?_?',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),

            Positioned(
              bottom: 8,
              right: 12,
              child: Image.asset(
                'assets/images/Lee_logo_app_dev.png',
                width: 80,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
