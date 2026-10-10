import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventease/theme/app_theme.dart';

void main() {
  setUp(() {
    AppTheme.configure(accentId: 'indigo', brightness: Brightness.light);
  });

  tearDown(() {
    AppTheme.configure(accentId: 'indigo', brightness: Brightness.light);
  });

  test('builds light and dark themes with the requested brightness', () {
    expect(AppTheme.lightTheme.brightness, Brightness.light);
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
  });

  test('applies a selected accent and brightness to theme colors', () {
    AppTheme.configure(accentId: 'teal', brightness: Brightness.dark);

    expect(AppTheme.darkTheme.colorScheme.primary, AppTheme.accentFor('teal'));
    expect(AppTheme.darkTheme.scaffoldBackgroundColor, AppTheme.background);
    expect(AppTheme.surface, isNot(Colors.white));
    expect(AppTheme.success, isNot(AppTheme.primary));
  });

  test('keeps text readable on bright accent colors', () {
    AppTheme.configure(accentId: 'orange', brightness: Brightness.light);

    expect(AppTheme.lightTheme.colorScheme.onPrimary, const Color(0xFF0F172A));
  });
}
