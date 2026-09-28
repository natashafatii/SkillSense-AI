import 'dart:js_interop';
import 'package:skillsense_ai/services/auth_service_interface.dart';
import 'package:skillsense_ai/services/auth_service_web.dart';

@JS('Clerk')
external set clerkGlobal(JSObject value);
@JS('__clerkReady')
external set clerkReady(bool value);
@JS('__clerkError')
external set clerkError(JSString? value);

Future<void> checkSignOut() async {
  var navigations = 0;
  var callbacks = 0;
  clerkReady = true;
  clerkError = null;
  clerkGlobal =
      {
            'user': null,
            'session': null,
            'addListener': ((JSFunction listener) {}).toJS,
            'signOut': ((JSFunction? callback) {
              if (callback == null) {
                navigations++;
              } else {
                callbacks++;
                callback.callAsFunction();
              }
              return Future<JSAny?>.value(null).toJS;
            }).toJS,
          }.jsify()!
          as JSObject;
  final service = AuthServiceWeb();
  await service.initialize('test');
  await service.signOut();
  expect(navigations, 0);
  expect(callbacks, 1);
}

Future<void> checkRoleRejection() async {
  var activations = 0;
  var removals = 0;
  var signOuts = 0;
  final session =
      {
            'id': 'pending_session',
            'status': 'active',
            'getToken': (() => Future<JSString?>.value('proof'.toJS).toJS).toJS,
            'remove': (() {
              removals++;
              return Future<JSAny?>.value(null).toJS;
            }).toJS,
          }.jsify()!
          as JSObject;
  clerkReady = true;
  clerkError = null;
  clerkGlobal =
      {
            'user': null,
            'session': null,
            'client': {
              'sessions': [session],
              'signIn': {
                'create': ((JSObject params) => Future<JSObject>.value(
                  {
                        'status': 'complete',
                        'createdSessionId': 'pending_session',
                      }.jsify()!
                      as JSObject,
                ).toJS).toJS,
              },
            },
            'addListener': ((JSFunction listener) {}).toJS,
            'setActive': ((JSObject params) {
              activations++;
              return Future<JSAny?>.value(null).toJS;
            }).toJS,
            'signOut': ((JSFunction? callback) {
              signOuts++;
              return Future<JSAny?>.value(null).toJS;
            }).toJS,
          }.jsify()!
          as JSObject;
  final service = AuthServiceWeb()
    ..sessionValidator = (_) async {
      throw RoleMismatchException('RECRUITER');
    };
  await service.initialize('test');
  try {
    await service.login('test@example.com', 'password');
    throw StateError('Wrong-role login was accepted.');
  } on RoleMismatchException {
    // Expected rejection.
  }
  expect(activations, 0);
  expect(removals, 1);
  expect(signOuts, 0);
  expect(service.isSignedIn, false);
}

void expect(Object? actual, Object? expected) {
  if (actual != expected) throw StateError('Expected $expected, got $actual');
}

@JS('document.body.textContent')
external set resultText(String value);

Future<void> main() async {
  try {
    await checkSignOut();
    await checkRoleRejection();
    resultText = 'PASS: 2 web authentication checks';
  } catch (error, stack) {
    resultText = 'FAIL: $error\n$stack';
  }
}
