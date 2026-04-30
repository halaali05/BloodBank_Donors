import 'web_foreground_notification_stub.dart'
    if (dart.library.html) 'web_foreground_notification_web.dart' as impl;

void showWebForegroundNotification({
  required String title,
  required String body,
  required Map<String, dynamic> data,
}) =>
    impl.showWebForegroundNotification(title: title, body: body, data: data);
