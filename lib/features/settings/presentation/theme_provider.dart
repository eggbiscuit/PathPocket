import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  late final SharedPreferences _prefs;

  @override
  ThemeMode build() {
    _prefs = ref.read(_prefsProvider);
    final saved = _prefs.getString(_kThemeModeKey);
    return _fromString(saved);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_kThemeModeKey, mode.name);
  }

  ThemeMode _fromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

// Internal provider — SharedPreferences must be overridden in main().
final _prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override _prefsProvider with SharedPreferences');
});

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Call this in ProviderScope.overrides to inject SharedPreferences.
Override themeModePrefsOverride(SharedPreferences prefs) =>
    _prefsProvider.overrideWithValue(prefs);
