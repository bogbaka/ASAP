import 'package:flutter/material.dart';

import 'profile_setup_screen.dart';

class VerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const VerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<VerificationScreen> createState() =>
      _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _codeController =
      TextEditingController();

  final FocusNode _codeFocusNode = FocusNode();

  bool _isVerifying = false;
  bool _isResending = false;

  static const Color _primaryColor = Color(0xFF075E54);
  static const Color _backgroundColor = Color(0xFFF7F9F8);
  static const Color _headingColor = Color(0xFF202C33);
  static const Color _secondaryColor = Color(0xFF667781);
  static const Color _borderColor = Color(0xFFD9E2DF);

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  // Displays a message at the bottom of the screen.
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

  // Validates the code and navigates to Profile Setup.
  Future<void> _verifyCode() async {
    final String code = _codeController.text.trim();

    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _showMessage('Please enter a valid 6-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    // Temporary demo verification.
    // Real code verification will be handled by the backend.
    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSetupScreen(
          phoneNumber: widget.phoneNumber,
        ),
      ),
    );
  }

  // Temporary resend-code placeholder.
  Future<void> _resendCode() async {
    if (_isResending || _isVerifying) return;

    setState(() {
      _isResending = true;
    });

    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) return;

    setState(() {
      _isResending = false;
    });

    _showMessage(
      'SMS delivery will be available after backend integration.',
    );
  }

  // Returns the user to the previous screen.
  void _changePhoneNumber() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: _isVerifying
              ? null
              : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          color: _headingColor,
        ),
        title: const Text(
          'Verification',
          style: TextStyle(
            color: _headingColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Verification icon.
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(
                        alpha: 0.10,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      size: 52,
                      color: _primaryColor,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Heading.
                const Text(
                  'Verify your number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _headingColor,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Enter the 6-digit verification code '
                  'to continue setting up your ASAP account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _secondaryColor,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 18),

                // Phone number.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.phone_android,
                        color: _primaryColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.phoneNumber,
                          style: const TextStyle(
                            color: _headingColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _isVerifying
                            ? null
                            : _changePhoneNumber,
                        child: const Text(
                          'Change',
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Verification code label.
                const Text(
                  'Verification code',
                  style: TextStyle(
                    color: _headingColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                // Six-digit input field.
                TextField(
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  enabled: !_isVerifying,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _headingColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: const TextStyle(
                      color: Color(0xFFB0B8BC),
                      fontSize: 22,
                      letterSpacing: 8,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: _borderColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: _borderColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: _primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!_isVerifying) {
                      _verifyCode();
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Demo information.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _borderColor,
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: _primaryColor,
                        size: 21,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Demo mode: enter any 6-digit number. '
                          'Actual SMS verification will be '
                          'connected to the backend later.',
                          style: TextStyle(
                            color: _secondaryColor,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Verify button.
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isVerifying
                        ? null
                        : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          _primaryColor.withValues(
                        alpha: 0.6,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Resend code option.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Flexible(
                      child: Text(
                        "Didn't receive a code? ",
                        style: TextStyle(
                          color: _secondaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          (_isResending || _isVerifying)
                              ? null
                              : _resendCode,
                      child: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primaryColor,
                              ),
                            )
                          : const Text(
                              'Resend code',
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                const Text(
                  'ASAP — Stay connected, anytime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _secondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}