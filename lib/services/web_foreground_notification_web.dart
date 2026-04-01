// Conditional web implementation; dart:html is the standard approach here.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

void showWebForegroundNotification({
  required String title,
  required String body,
  required Map<String, dynamic> data,
}) {
  if (html.Notification.permission != 'granted') return;
  try {
    final tag =
        '${data['requestId'] ?? ''}_${data['type'] ?? 'msg'}'.trim();
    final n = html.Notification(
      title,
      body: body.isEmpty ? ' ' : body,
      tag: tag.isEmpty ? 'hayat_msg' : tag,
    );
    n.onClick.listen((_) {
      try {
        n.close();
        final encoded = Uri.encodeComponent(jsonEncode(data));
        final origin = html.window.location.origin;
        html.window.location.assign('$origin/?notificationData=$encoded');
      } catch (_) {}
    });
  } catch (_) {}
}
