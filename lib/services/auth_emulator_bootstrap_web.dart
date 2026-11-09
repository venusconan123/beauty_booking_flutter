import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('prepareDemoAuthEmulator')
external JSPromise<JSAny?> _prepareDemoAuth(
  JSString host,
  JSNumber port,
  JSAny? options,
);

@JS('firebase_auth.getAuth')
external JSObject _getAuth();

Future<bool> prepareAuthEmulator(
  String host,
  int port,
  Map<String, dynamic> options,
) async {
  // Connect synchronously with initializeAuth, before FlutterFire awaits
  // persisted-session restoration. Only invoked by explicit emulator builds.
  await _prepareDemoAuth(host.toJS, port.toJS, options.jsify()).toDart;
  return true;
}

void verifyAuthEmulator(String host, int port) {
  final config = _getAuth().getProperty<JSObject?>('emulatorConfig'.toJS);
  if (config == null ||
      config.getProperty<JSString>('host'.toJS).toDart != host ||
      config.getProperty<JSNumber>('port'.toJS).toDartInt != port) {
    throw StateError('Auth chưa kết nối đúng Emulator; dừng bản demo.');
  }
}
