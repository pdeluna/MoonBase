import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';

/// Opens this app's page in the host OS Settings app (permissions, etc.).
///
/// Returns `true` when the platform channel accepted the request. On mobile
/// this typically lands on the app-details screen where the user can enable
/// camera or photo-library access. Returns `false` only when the channel
/// throws (rare; e.g. unsupported desktop target).
///
/// Wired from `MediaPickerSheet` "Open Settings" (POL-2). Presentation code
/// should call this helper rather than importing `app_settings` directly so
/// tests can inject a stub handler.
Future<bool> openAppPermissionSettings() => openAppSettingsHandler();

/// Injectable handler for tests. Defaults to [AppSettings.openAppSettings].
Future<bool> Function() openAppSettingsHandler = _defaultOpenAppSettings;

Future<bool> _defaultOpenAppSettings() async {
  try {
    await AppSettings.openAppSettings(type: AppSettingsType.settings);
    return true;
  } catch (_) {
    return false;
  }
}

/// Restores [openAppSettingsHandler] after widget/unit tests override it.
@visibleForTesting
void resetOpenAppSettingsHandler() {
  openAppSettingsHandler = _defaultOpenAppSettings;
}
