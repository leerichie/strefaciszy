import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:strefa_ciszy/widgets/app_shell.dart';

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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainMenuScreen(role: 'admin')),
      );
    } on FirebaseAuthException catch (e) {
      final friendly = _friendlyMessageForCode(e.code);
      setState(() => _error = friendly);
    } catch (e) {
      setState(() => _error = 'Nieoczekiwany błąd. Spróbuj ponownie.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/strefa_ciszy_logo.png', width: 200),
              Text('_Inventory'),
              SizedBox(height: 48),

              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: Colors.red)),
                SizedBox(height: 16),
              ],

              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {
                  FocusScope.of(context).nextFocus();
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                decoration: InputDecoration(labelText: 'Hasło'),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_isLoading) _signIn();
                },
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                child: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Zaloguj sie'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
