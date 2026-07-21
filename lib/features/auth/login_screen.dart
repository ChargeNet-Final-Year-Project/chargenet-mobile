import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/auth/auth_validators.dart';
import 'package:chargenet_mobile/features/auth/register_screen.dart';
import 'package:chargenet_mobile/features/auth/widgets/auth_scaffold.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Email + password sign-in.
///
/// A successful login stores the token, publishes the user and flips
/// [authStateNotifier] to [AuthState.signedIn]; the app gate in `main.dart`
/// reacts by swapping this screen for the dashboard, whose first build kicks off
/// `AppStateService.refreshAll()`.
class LoginScreen extends StatefulWidget {
  /// Seeded demo account, offered through a debug-only shortcut.
  static const String demoEmail = 'demo@chargenet.my';
  static const String demoPassword = 'Demo1234!';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await ApiService.instance.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await ApiService.instance.setToken(result.token);
      currentUserNotifier.value = result.user;
      authStateNotifier.value = AuthState.signedIn;
    } on ApiException catch (e) {
      // `INVALID_CREDENTIALS` reads "Invalid email or password." straight from
      // the server, so that wording stays in one place.
      if (mounted) setState(() => _error = e.message);
    } finally {
      // A successful login unmounts this screen; only update it if it is alive.
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _useDemoAccount() {
    setState(() {
      _emailController.text = LoginScreen.demoEmail;
      _passwordController.text = LoginScreen.demoPassword;
      _error = null;
    });
  }

  void _openRegister() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'One wallet, every operator. Log in to start charging.',
      error: _error,
      footer: TextButton(
        onPressed: _isSubmitting ? null : _openRegister,
        child: const Text('New to ChargeNet? Create an account'),
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(hintText: 'Email'),
                validator: AuthValidators.email,
              ),
              const SizedBox(height: AuthScaffold.childGap),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Password',
                  suffixIcon: _visibilityToggle(),
                ),
                validator: AuthValidators.requiredPassword,
                onFieldSubmitted: (_) => _signIn(),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _isSubmitting ? null : _signIn,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      KConstants.circularBorderRadius,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Log in'),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _isSubmitting ? null : _useDemoAccount,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Use demo account'),
                ),
                Text(
                  '${LoginScreen.demoEmail} / ${LoginScreen.demoPassword}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _visibilityToggle() {
    return IconButton(
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
      ),
      tooltip: _obscurePassword ? 'Show password' : 'Hide password',
    );
  }
}
