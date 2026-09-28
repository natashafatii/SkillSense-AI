import 'package:web/web.dart' as web;

String? read(String key) => web.window.localStorage.getItem(key);
void write(String key, String value) => web.window.localStorage.setItem(key, value);
