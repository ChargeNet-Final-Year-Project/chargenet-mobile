import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/auth/auth_validators.dart';
import 'package:chargenet_mobile/features/auth/widgets/auth_scaffold.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:flutter/material.dart';

/// Sign-up form.
///
/// Registers, stores the returned token and flips [authStateNotifier] to
/// [AuthState.signedIn]. The server creates the wallet together with the
/// account, so the dashboard's `refreshAll()` shows it at RM 0.00 at once.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  String _walletCurrency = 'MYR';
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await ApiService.instance.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        walletCurrency: _walletCurrency,
      );
      await ApiService.instance.setToken(result.token);
      currentUserNotifier.value = result.user;
      authStateNotifier.value = AuthState.signedIn;
      // This screen was pushed on top of the gate's home, which has already
      // become the dashboard. Drop the pushed route so the dashboard is shown.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (e) {
      // `EMAIL_TAKEN` / `VALIDATION_ERROR` arrive as ready-to-show messages.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle:
          'One account unlocks every ChargeNet operator, no roaming fees.',
      error: _error,
      footer: TextButton(
        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        child: const Text('Already have an account? Log in'),
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Full name'),
                validator: AuthValidators.name,
              ),
              const SizedBox(height: AuthScaffold.childGap),
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
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Password',
                  helperText:
                      'At least ${AuthValidators.minPasswordLength} characters',
                  suffixIcon: _visibilityToggle(),
                ),
                validator: AuthValidators.newPassword,
              ),
              const SizedBox(height: AuthScaffold.childGap),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                decoration: const InputDecoration(hintText: 'Confirm password'),
                validator: (value) => AuthValidators.confirmPassword(
                  value,
                  _passwordController.text,
                ),
                onFieldSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 22),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _walletCurrency,
                decoration: const InputDecoration(
                  labelText: 'Wallet currency',
                  helperMaxLines: 3,
                  helperText: 'One wallet for charging in Malaysia, Singapore and Thailand.',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'MYR',
                    child: Text('MYR \u00b7 Malaysian ringgit'),
                  ),
                  DropdownMenuItem(
                    value: 'SGD',
                    child: Text('SGD \u00b7 Singapore dollar'),
                  ),
                  DropdownMenuItem(
                    value: 'THB',
                    child: Text('THB \u00b7 Thai baht'),
                  ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) =>
                          setState(() => _walletCurrency = value ?? 'MYR'),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _isSubmitting ? null : _register,
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
                      : const Text('Create account'),
                ),
              ),
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
