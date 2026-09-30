import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/auth_panel.dart';

class AdminLoginScreen extends StatefulWidget {
  final ValueChanged<AuthPortal> onPortalChanged;

  const AdminLoginScreen({super.key, required this.onPortalChanged});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final result = await api.post('/auth/admin/login', body: {
        'email': _email.text.trim(),
        'password': _password.text,
      });
      if (!mounted) return;
      await context
          .read<AuthProvider>()
          .setSession(result['token'], 'admin', result['user']);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(
          () => _error = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPanel(
      portal: AuthPortal.admin,
      isLogin: true,
      allowRegistration: false,
      signInLabel: 'Sign In to Admin Account',
      registrationLabel: 'Admin Registration Disabled',
      sectionTitle: 'Administrator Sign In',
      sectionDescription: 'Sign in to manage the LifePulse donor network.',
      footerMessage: 'Admin accounts are created by the backend seed script',
      onModeChanged: (_) {},
      onPortalChanged: widget.onPortalChanged,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEBF0F1),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(Icons.admin_panel_settings,
                  size: 30, color: Color(0xFF52646C)),
            ),
            const SizedBox(height: 22),
            Text(
              'Administrator access',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF202A31),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to manage the LifePulse network.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF66736F)),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Admin email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEBED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFB32635))),
              ),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_loading ? 'Signing in' : 'Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
