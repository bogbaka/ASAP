import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asap/app_settings.dart';
import 'package:asap/screens/appearance_settings_screen.dart';

void main() {
  final settings = AppSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await settings.load();
  });

  group('AppSettings', () {
    test('uses system theme and blue accent by default', () {
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.accentColor.toARGB32(), 0xFF2563EB);
    });

    test('saves the selected theme', () async {
      await settings.setThemeMode(ThemeMode.dark);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('appearance_theme_mode'), 'dark');
    });

    test('loads a saved theme preference', () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('appearance_theme_mode', 'dark');

      await settings.load();

      expect(settings.themeMode, ThemeMode.dark);
    });

    test('saves the selected accent colour', () async {
      const green = Color(0xFF16A34A);

      await settings.setAccentColor(green);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('appearance_accent_color'), green.toARGB32());
    });

    test('loads a saved accent colour', () async {
      const greenValue = 0xFF16A34A;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt('appearance_accent_color', greenValue);

      await settings.load();

      expect(settings.accentColor.toARGB32(), greenValue);
    });
  });

  testWidgets('Appearance screen displays its options', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppearanceSettingsScreen()),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('ACCENT COLOUR'), findsOneWidget);
    expect(
      find.text('Choose a theme and accent colour for ASAP.'),
      findsOneWidget,
    );
  });

  testWidgets('selecting Dark updates the theme preference', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppearanceSettingsScreen()),
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
  });

  testWidgets('selecting Green updates the accent colour', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppearanceSettingsScreen()),
    );

    await tester.tap(find.bySemanticsLabel('Green accent colour'));
    await tester.pumpAndSettle();

    expect(settings.accentColor.toARGB32(), 0xFF16A34A);
  });
}
