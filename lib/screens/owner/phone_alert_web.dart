import 'dart:js_interop';

@JS('Notification')
extension type _BrowserNotification._(JSObject _) implements JSObject {
  external factory _BrowserNotification(JSString title, JSObject options);
  external static JSString get permission;
  external static JSPromise<JSString> requestPermission();
}

@JS()
@anonymous
extension type _NotificationOptions._(JSObject _) implements JSObject {
  external factory _NotificationOptions({JSString body});
}

/// Asks the browser to show a phone notification when it is allowed.
Future<void> showPhoneAlert(String title, String body) async {
  try {
    var permission = _BrowserNotification.permission.toDart;
    if (permission == 'default') {
      permission = (await _BrowserNotification.requestPermission().toDart).toDart;
    }
    if (permission != 'granted') return;
    _BrowserNotification(title.toJS, _NotificationOptions(body: body.toJS));
  } catch (_) {}
}
