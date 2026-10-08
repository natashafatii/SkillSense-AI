import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:ua_client_hints/ua_client_hints.dart';

void main() {
  test('browser client hints remain available to Clerk passkeys', () async {
    final data = await userAgentData();
    expect(data.platform, isNotEmpty);
    expect(data.package.appName, isNotEmpty);
  }, skip: !kIsWeb);
}
