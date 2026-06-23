import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/platform_settings.dart';

void main() {
  tearDown(resetOpenAppSettingsHandler);

  test('openAppPermissionSettings delegates to injectable handler', () async {
    var invoked = false;
    openAppSettingsHandler = () async {
      invoked = true;
      return true;
    };

    final result = await openAppPermissionSettings();

    expect(invoked, isTrue);
    expect(result, isTrue);
  });

  test('openAppPermissionSettings surfaces handler returning false', () async {
    openAppSettingsHandler = () async => false;

    final result = await openAppPermissionSettings();

    expect(result, isFalse);
  });
}
