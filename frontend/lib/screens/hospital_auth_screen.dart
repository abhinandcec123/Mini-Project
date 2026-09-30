import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/auth_panel.dart';

class HospitalAuthScreen extends StatefulWidget {
  final ValueChanged<AuthPortal> onPortalChanged;

  const HospitalAuthScreen({super.key, required this.onPortalChanged});

  @override
  State<HospitalAuthScreen> createState() => _HospitalAuthScreenState();
}

class _HospitalAuthScreenState extends State<HospitalAuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  String? _error;
  String _facilityType = 'Trauma Center (Level 1/2)';
  bool _isAccredited = false;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _regNumber = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _address = TextEditingController();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final requestBody = _isLogin
          ? {
              'phone': _phone.text.trim(),
              'password': _password.text,
            }
          : {
              'name': _name.text.trim(),
              'registration_number': _regNumber.text.trim(),
              'phone': _phone.text.trim(),
              'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
              'password': _password.text,
              'address': _address.text.trim(),
            };

      final result = await api.post(
        _isLogin ? '/auth/hospital/login' : '/auth/hospital/signup',
        body: requestBody,
      );

      if (!mounted) return;
      await context
          .read<AuthProvider>()
          .setSession(result['token'], 'hospital', result['user']);
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

  InputDecoration _fieldDecoration({String? hintText, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18),
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Color(0xFF9AA5B1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCF2349), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB32635)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB32635), width: 1.5),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Color(0xFF19212D),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Color(0xFFCF2349)),
                  )
                ]
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPanel(
      portal: AuthPortal.hospital,
      isLogin: _isLogin,
      allowRegistration: true,
      signInLabel: 'Sign In to Account',
      registrationLabel: 'Register New Hospital',
      sectionTitle: _isLogin ? 'Hospital Sign In' : 'Hospital Medical Facility Registration',
      sectionDescription: _isLogin
          ? 'Access your hospital dashboard and live blood request queue.'
          : 'Enroll your medical facility to issue emergency blood requisitions.',
      footerMessage: 'Strict single-phone registration & persistent auth layer',
      onModeChanged: (isLogin) => setState(() => _isLogin = isLogin),
      onPortalChanged: widget.onPortalChanged,
      child: Form(
        key: _formKey,
        child: _isLogin
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: _fieldDecoration(
                      hintText: '+1 (555) 911-BLOD',
                      prefixIcon: Icons.phone_outlined,
                    ),
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? 'Enter a valid 10-digit number'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: _fieldDecoration(
                      hintText: 'Enter your facility password',
                      prefixIcon: Icons.lock_outline,
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFB32635))),
                    ),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFCF2349),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sign In to Account'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF9C8D2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCF2349),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_hospital_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hospital Medical Facility Registration',
                                style: TextStyle(
                                  color: Color(0xFF19212D),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Enroll your medical facility to issue emergency blood requisitions.',
                                style: TextStyle(
                                  color: Color(0xFF5E6B7A),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Facility Name', required: true),
                            TextFormField(
                              controller: _name,
                              decoration: _fieldDecoration(hintText: 'e.g. Memorial Trauma Center'),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Facility Code', required: true),
                            TextFormField(
                              controller: _regNumber,
                              decoration: _fieldDecoration(hintText: 'e.g. MTC-09'),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Facility Email'),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _fieldDecoration(
                                hintText: 'emergency@memorial.org',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Facility Type', required: true),
                            DropdownButtonFormField<String>(
                              initialValue: _facilityType,
                              decoration: _fieldDecoration(hintText: 'Select facility type'),
                              items: const [
                                'Trauma Center (Level 1/2)',
                                'General Hospital',
                                'Children\'s Hospital',
                                'Private Clinic',
                              ].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _facilityType = value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Emergency 24/7 Hotline', required: true),
                            TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              decoration: _fieldDecoration(
                                hintText: '+1 (555) 911-BLOD',
                                prefixIcon: Icons.phone_outlined,
                              ),
                              validator: (v) => (v == null || v.trim().length < 10)
                                  ? 'Enter a valid 10-digit number'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('ER Director / Contact'),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _fieldDecoration(
                                hintText: 'Dr. Sarah Johnson (Chief of Surgery)',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _label('Facility Security Password (Strict Policy)', required: true),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: _fieldDecoration(
                      hintText: 'Min 8 chars with uppercase, lowercase, number, symbol',
                      prefixIcon: Icons.lock_outline,
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                  ),
                  const SizedBox(height: 18),
                  _label('Street Address', required: true),
                  TextFormField(
                    controller: _address,
                    maxLength: 255,
                    maxLines: 2,
                    decoration: _fieldDecoration(
                      hintText: '450 Medical Center Boulevard',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Enter the hospital address'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  CheckboxListTile(
                    value: _isAccredited,
                    onChanged: (value) => setState(() => _isAccredited = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFFCF2349),
                    title: const Text(
                      'I certify that this facility is an accredited medical entity authorized to request and transfer blood products.',
                      style: TextStyle(fontSize: 15, color: Color(0xFF2B3340)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFB32635))),
                    ),
                  FilledButton(
                    onPressed: _loading || !_isAccredited ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFCF2349),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_hospital_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Register Accredited Healthcare Center'),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
