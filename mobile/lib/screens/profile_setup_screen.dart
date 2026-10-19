import 'package:flutter/material.dart';

import 'chats_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String phoneNumber;

  const ProfileSetupScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController =
      TextEditingController();

  static const Color _primaryColor = Color(0xFF075E54);
  static const Color _backgroundColor = Color(0xFFF7F9F8);
  static const Color _headingColor = Color(0xFF202C33);
  static const Color _secondaryColor = Color(0xFF667781);
  static const Color _borderColor = Color(0xFFD9E2DF);

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
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

  // Validates the display name and opens the Chats screen.
  Future<void> _continue() async {
    final String displayName = _nameController.text.trim();

    if (displayName.isEmpty) {
      _showMessage('Please enter your display name.');
      return;
    }

    if (displayName.length < 2) {
      _showMessage(
        'Your name must contain at least 2 characters.',
      );
      return;
    }

    if (displayName.length > 30) {
      _showMessage(
        'Your name cannot exceed 30 characters.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Temporary demo delay.
    // Profile data will be saved through the backend later.
    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    // Navigate to Chats after profile setup.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatsScreen(
          displayName: displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: _headingColor,
          onPressed: _isSaving
              ? null
              : () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile setup',
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
                const SizedBox(height: 12),

                // Screen heading.
                const Text(
                  'Create your profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _headingColor,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Choose a name your friends can recognize.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _secondaryColor,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 36),

                // Profile picture placeholder.
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(
                            alpha: 0.10,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 72,
                          color: _primaryColor,
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: _primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Add a profile photo later',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _secondaryColor,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 36),

                // Display name label.
                const Text(
                  'Display name',
                  style: TextStyle(
                    color: _headingColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                // Display name input.
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.done,
                  maxLength: 30,
                  enabled: !_isSaving,
                  onSubmitted: (_) {
                    if (!_isSaving) {
                      _continue();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    hintStyle: const TextStyle(
                      color: _secondaryColor,
                    ),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: _secondaryColor,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    counterText: '',
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
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
                ),

                const SizedBox(height: 12),

                // Information card.
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
                          'Your display name helps other people '
                          'recognize you on ASAP. You can change '
                          'it later.',
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

                const SizedBox(height: 32),

                // Continue button.
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _continue,
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
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Welcome to ASAP — stay connected, anytime.',
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