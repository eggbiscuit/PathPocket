import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFontScaleKey = 'font_scale';

/// Available font scale steps shown in the settings UI.
const List<double> fontScaleSteps = [0.85, 1.0, 1.15, 1.3];

class FontScaleNotifier extends Notifier<double> {
  late final SharedPreferences _prefs;

  @override
  double build() {
    _prefs = ref.read(_fontPrefsProvider);
    final saved = _prefs.getDouble(_kFontScaleKey);
    return saved != null && fontScaleSteps.contains(saved) ? saved : 1.0;
  }

  Future<void> setScale(double scale) async {
    if (!fontScaleSteps.contains(scale)) return;
    state = scale;
    await _prefs.setDouble(_kFontScaleKey, scale);
  }
}

final _fontPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override _fontPrefsProvider with SharedPreferences');
});

final fontScaleProvider = NotifierProvider<FontScaleNotifier, double>(
  FontScaleNotifier.new,
);

Override fontScalePrefsOverride(SharedPreferences prefs) =>
    _fontPrefsProvider.overrideWithValue(prefs);
