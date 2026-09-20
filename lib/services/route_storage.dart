import 'package:shared_preferences/shared_preferences.dart';

/// Helper service to persist and restore the user's active route across refreshes.
class RouteStorage {
  static const String _keyLastRoute = 'skillsense_last_route';

  static const List<String> _ignoredRoutes = [
    '/',
    '/welcome',
  ];

  static Future<void> saveLastRoute(String routeName) async {
    if (_ignoredRoutes.contains(routeName) || routeName.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastRoute, routeName);
    } catch (_) {}
  }

  static Future<String?> getLastRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString(_keyLastRoute);
      if (route != null && route.isNotEmpty && !_ignoredRoutes.contains(route)) {
        return route;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearLastRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastRoute);
    } catch (_) {}
  }
}
