
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends State<PersonalInformationScreen> {
  static const Color _primaryColor = Color(0xFF2563EB);

  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _aboutController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _aboutController.dispose();
    _authService.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _loadProfile() async {
    try {
      final accessToken = await _authService.getAccessToken();

      if (accessToken == null || accessToken.trim().isEmpty) {
        throw const AuthException(
          'Your session has expired. Please sign in again.',
        );
      }

      final profile = await _authService.getMyProfile(
        accessToken: accessToken,
      );

      if (!mounted) return;

      _displayNameController.text =
          profile['display_name']?.toString() ?? '';
      _emailController.text = profile['email']?.toString() ?? '';
      _aboutController.text = profile['about']?.toString() ?? '';

      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage(
        error is AuthException
            ? error.message
            : 'Unable to load your personal information.',
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);

    try {
      final accessToken = await _authService.getAccessToken();

      if (accessToken == null || accessToken.trim().isEmpty) {
        throw const AuthException(
          'Your session has expired. Please sign in again.',
        );
      }

      await _authService.updateMyProfile(
        accessToken: accessToken,
        displayName: _displayNameController.text.trim(),
        email: _emailController.text.trim(),
        about: _aboutController.text.trim(),
      );

      if (!mounted) return;

      _showMessage('Personal information saved successfully.');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error is AuthException
            ? error.message
            : 'Unable to save your changes. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: _primaryColor,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal information'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: Color(0xFFE8EEFF),
                      child: Icon(
                        Icons.person_outline,
                        color: _primaryColor,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your personal information',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Update the information associated with your ASAP account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _displayNameController,
                      enabled: !_isSaving,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 80,
                      decoration: _inputDecoration(
                        label: 'Display name',
                        hint: 'Enter your name',
                        icon: Icons.person_outline,
                      ),
                      validator: (value) {
                        final name = value?.trim() ?? '';

                        if (name.length < 2) {
                          return 'Enter at least 2 characters.';
                        }

                        if (name.length > 80) {
                          return 'Name cannot exceed 80 characters.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      maxLength: 255,
                      decoration: _inputDecoration(
                        label: 'Email address',
                        hint: 'Enter your email (optional)',
                        icon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) return null;

                        final emailPattern =
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                        if (!emailPattern.hasMatch(email)) {
                          return 'Enter a valid email address.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _aboutController,
                      enabled: !_isSaving,
                      maxLength: 139,
                      maxLines: 4,
                      minLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        label: 'About',
                        hint: 'Tell people a little about yourself',
                        icon: Icons.info_outline,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
