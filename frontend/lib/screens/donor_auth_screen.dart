import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/auth_panel.dart';

class DonorAuthScreen extends StatefulWidget {
  final ValueChanged<AuthPortal> onPortalChanged;

  const DonorAuthScreen({super.key, required this.onPortalChanged});

  @override
  State<DonorAuthScreen> createState() => _DonorAuthScreenState();
}

class _DonorAuthScreenState extends State<DonorAuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  String _bloodGroup = AppConstants.bloodGroups.first;
  String? _gender;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final result = _isLogin
          ? await api.post('/auth/donor/login', body: {
              'phone': _phone.text.trim(),
              'password': _password.text,
            })
          : await api.post('/auth/donor/signup', body: {
              'full_name': _fullName.text.trim(),
              'phone': _phone.text.trim(),
              'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
              'password': _password.text,
              'blood_group': _bloodGroup,
              'age': int.tryParse(_age.text) ?? 0,
              'gender': _gender,
              'address': _address.text.trim(),
            });

      if (!mounted) return;
      await context
          .read<AuthProvider>()
          .setSession(result['token'], 'donor', result['user']);
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
      portal: AuthPortal.donor,
      isLogin: _isLogin,
      allowRegistration: true,
      signInLabel: 'Sign In to Account',
      registrationLabel: 'Register New Donor',
      sectionTitle: _isLogin ? 'Volunteer Donor Sign In' : 'Donor Registration',
      sectionDescription: _isLogin
          ? 'Sign in with your registered mobile number and password.'
          : 'Create your donor account to receive compatible hospital requests.',
      footerMessage: 'Secure donor account access',
      onModeChanged: (isLogin) => setState(() => _isLogin = isLogin),
      onPortalChanged: widget.onPortalChanged,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isLogin) ...[
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(
                    labelText: 'Full name', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Mobile number', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Enter a valid 10-digit number'
                  : null,
            ),
            const SizedBox(height: 12),
            if (!_isLogin) ...[
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _bloodGroup,
                      decoration: const InputDecoration(
                          labelText: 'Blood group',
                          border: OutlineInputBorder()),
                      items: AppConstants.bloodGroups
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _bloodGroup = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Age', border: OutlineInputBorder()),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 18 || n > 65) return '18-65 only';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(
                    labelText: 'Gender (optional)',
                    border: OutlineInputBorder()),
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                maxLength: 255,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Full address',
                  hintText: 'Street, city, region, postal code',
                  prefixIcon: Icon(Icons.place_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your address'
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Password', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isLogin ? 'Sign In' : 'Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
