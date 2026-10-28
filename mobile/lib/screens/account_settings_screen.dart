
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'personal_information_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  static const Color _primaryColor = Color(0xFF2563EB);

  static const String _twoStepKey = 'account_two_step_verification';
  static const String _securityNotificationsKey =
      'account_security_notifications';

  bool _twoStepVerification = false;
  bool _securityNotifications = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _twoStepVerification = preferences.getBool(_twoStepKey) ?? false;
        _securityNotifications =
            preferences.getBool(_securityNotificationsKey) ?? true;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Unable to load account preferences: $error');

      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Unable to load saved settings.');
      }
    }
  }

  Future<void> _savePreference(String key, bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(key, value);
    } catch (error) {
      debugPrint('Unable to save account preference: $error');

      if (mounted) {
        _showMessage('Unable to save this setting. Please try again.');
      }
    }
  }

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

  void _openTwoStepVerification() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Two-step verification',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose whether to enable this preference. '
                  'Actual two-step account protection will require '
                  'ASAP backend integration.',
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable two-step verification'),
                  value: _twoStepVerification,
                  activeThumbColor: _primaryColor,
                  onChanged: (value) {
                    setSheetState(() => _twoStepVerification = value);
                    setState(() => _twoStepVerification = value);
                    _savePreference(_twoStepKey, value);
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline,
          color: Colors.red,
          size: 36,
        ),
        title: const Text('Delete account'),
        content: const Text(
          'Account deletion is not connected yet. '
          'No account will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: _primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      );

  Future<void> _openPersonalInformation() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => const PersonalInformationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionTitle('Security'),
                ListTile(
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: _primaryColor,
                  ),
                  title: const Text('Two-step verification'),
                  subtitle: Text(
                    _twoStepVerification
                        ? 'Preference enabled on this device'
                        : 'Add extra protection to your account',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openTwoStepVerification,
                ),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.notifications_active_outlined,
                    color: _primaryColor,
                  ),
                  title: const Text('Security notifications'),
                  subtitle: const Text(
                    'Notification preference for security changes',
                  ),
                  value: _securityNotifications,
                  activeThumbColor: _primaryColor,
                  onChanged: (value) {
                    setState(() => _securityNotifications = value);
                    _savePreference(_securityNotificationsKey, value);
                  },
                ),
                const Divider(height: 1),
                _sectionTitle('Account information'),
                ListTile(
                  leading: const Icon(
                    Icons.phone_outlined,
                    color: _primaryColor,
                  ),
                  title: const Text('Phone number'),
                  subtitle: const Text(
                    'Manage your registered phone number',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showMessage(
                    'Phone number management requires backend integration.',
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: _primaryColor,
                  ),
                  title: const Text('Personal information'),
                  subtitle: const Text(
                    'Manage your account information',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openPersonalInformation,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  title: const Text('Delete my account'),
                  subtitle: const Text(
                    'Permanently remove your account',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _confirmDeleteAccount,
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Security preferences are saved on this device. '
                    'Account security and account management still '
                    'require further backend integration.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
