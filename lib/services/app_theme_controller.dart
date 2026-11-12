import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ValueNotifier<ThemeMode> {
  AppThemeController(this._preferences) : super(_readMode(_preferences));

  static const _key = 'app_theme_mode';
  final SharedPreferences? _preferences;
  Future<void> _pendingSave = Future.value();

  static Future<AppThemeController> load() async {
    try {
      return AppThemeController(await SharedPreferences.getInstance());
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
      return AppThemeController(null);
    }
  }

  static ThemeMode _readMode(SharedPreferences? preferences) {
    final saved = preferences?.get(_key);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.light,
    );
  }

  Future<void> select(ThemeMode mode) {
    if (mode == value) return _pendingSave;
    value = mode;
    return _pendingSave = _pendingSave.then((_) => _save(mode));
  }

  Future<void> _save(ThemeMode mode) async {
    try {
      final preferences = _preferences ?? await SharedPreferences.getInstance();
      if (!await preferences.setString(_key, mode.name)) {
        throw StateError('Could not save theme preference');
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    }
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppThemeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()!.notifier!;
}
