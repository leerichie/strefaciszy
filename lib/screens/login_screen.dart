import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

      if (!mounted) return;

      // currently hardcoded role; replace with real role resolution if available
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainMenuScreen(role: 'admin')),
      );
    } on FirebaseAuthException catch (e) {
      final friendly = _friendlyMessageForCode(e.code);
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 700;

            return Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
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
                    'assets/images/dev_logo.png',
                    width: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            );
          },
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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Image.asset('assets/images/strefa_ciszy_logo.png', width: 200),
            const SizedBox(height: 8),
            const Text(
              '_Inventory',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: 'Hasło'),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!isLoading) onSignIn();
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: isLoading ? null : onSignIn,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Zaloguj się'),
            ),
          ],
        ),
      ),
    );
  }
}
