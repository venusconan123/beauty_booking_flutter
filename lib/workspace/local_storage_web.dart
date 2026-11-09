import 'dart:js_interop';

@JS('window.localStorage.getItem')
external JSString? _read(JSString key);
@JS('window.localStorage.setItem')
external void _write(JSString key, JSString value);

const _key = 'men-hair-booking-ui-v1';
String? readWorkspace() {
  try {
    return _read(_key.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

void writeWorkspace(String value) => _write(_key.toJS, value.toJS);
