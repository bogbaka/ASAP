import 'package:flutter/material.dart';
import 'verification_screen.dart';

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() =>
      _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final TextEditingController _phoneController =
      TextEditingController();

  String _countryCode = '+234';

  bool _isContinuing = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // Validates the phone number and opens the verification screen.
  Future<void> _continue() async {
    if (_isContinuing) return;

    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      _showMessage('Please enter your phone number.');
      return;
    }

    // Accept digits only, between 7 and 15 digits.
    if (!RegExp(r'^[0-9]{7,15}$').hasMatch(phoneNumber)) {
      _showMessage('Please enter a valid phone number.');
      return;
    }

    final fullPhoneNumber = '$_countryCode $phoneNumber';

    setState(() {
      _isContinuing = true;
    });

    // Small delay to provide visual feedback.
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      _isContinuing = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationScreen(
          phoneNumber: fullPhoneNumber,
        ),
      ),
    );
  }

  // Displays validation messages.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF075E54);
    const backgroundColor = Color(0xFFF7F9F8);
    const headingColor = Color(0xFF202C33);
    const secondaryColor = Color(0xFF667781);
    const borderColor = Color(0xFFD9E2DF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back,
            color: headingColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height - 150,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Phone icon.
                const Center(
                  child: Icon(
                    Icons.phone_android_rounded,
                    size: 68,
                    color: primaryColor,
                  ),
                ),

                const SizedBox(height: 28),

                // Screen heading.
                const Center(
                  child: Text(
                    'Enter your phone number',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: headingColor,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Instructions.
                const Text(
                  'ASAP will send you a verification code to confirm '
                  'your phone number.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: secondaryColor,
                  ),
                ),

                const SizedBox(height: 36),

                const Text(
                  'Phone number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: headingColor,
                  ),
                ),

                const SizedBox(height: 10),

                // Country code and phone number input.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _countryCode,
                          borderRadius: BorderRadius.circular(12),
                          items: const [
                            DropdownMenuItem(
                              value: '+234',
                              child: Text('🇳🇬 +234'),
                            ),
                            DropdownMenuItem(
                              value: '+1',
                              child: Text('🇺🇸 +1'),
                            ),
                            DropdownMenuItem(
                              value: '+44',
                              child: Text('🇬🇧 +44'),
                            ),
                            DropdownMenuItem(
                              value: '+91',
                              child: Text('🇮🇳 +91'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _countryCode = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Phone number field.
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        maxLength: 15,
                        onSubmitted: (_) => _continue(),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '8012345678',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: borderColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: borderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: primaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                const Text(
                  'Select your country code and enter your number '
                  'without the country code.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: secondaryColor,
                  ),
                ),

                const SizedBox(height: 24),

                // Privacy information.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: primaryColor,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your phone number helps people identify '
                          'your account. Verification will be '
                          'connected to the ASAP backend later.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: headingColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Continue button.
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _isContinuing ? null : _continue,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          primaryColor.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isContinuing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}