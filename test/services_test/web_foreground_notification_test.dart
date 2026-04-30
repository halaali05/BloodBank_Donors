import 'package:flutter_test/flutter_test.dart';
import 'package:bloodbank_donors/notifications/web_foreground_notification.dart';
void main() {
  test('calling notification does not throw', () {
    expect(
      () => showWebForegroundNotification(
        title: 'Test',
        body: 'Body',
        data: {'type': 'x'},
      ),
      returnsNormally,
    );
  });

test('handles empty data', () {
  expect(
    () => showWebForegroundNotification(
      title: '',
      body: '',
      data: {},
    ),
    returnsNormally,
  );
});

test('handles complex data map', () {
  expect(
    () => showWebForegroundNotification(
      title: 'Hi',
      body: 'There',
      data: {
        'requestId': 123,
        'type': 'alert',
        'nested': {'a': 1}
      },
    ),
    returnsNormally,
  );
});

}