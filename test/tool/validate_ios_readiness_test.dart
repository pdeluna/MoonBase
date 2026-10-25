import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Tooling lives outside lib/ so it cannot enter the application dependency
// graph. A relative import is intentional for this validator-only test.
// ignore: always_use_package_imports
import '../../tool/validate_ios_readiness.dart';

const String _androidAppId = '1:137107376205:android:f74e18c46e57a45b9bf404';
const String _iosAppId = '1:137107376205:ios:abcdef1234567890';

enum _FirebaseSurface { options, json, plist, xcodeResource }

enum _ResourceState { absent, member, dangling }

void main() {
  late Directory root;
  late _IosReadinessFixture fixture;

  setUp(() {
    root = Directory.systemTemp.createTempSync('moonbase_ios_validator_');
    fixture = _IosReadinessFixture(root)..writeBase();
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  IosReadinessValidator validate({
    bool allowPendingFirebaseRegistration = true,
  }) =>
      IosReadinessValidator(
        root: root,
        allowPendingFirebaseRegistration: allowPendingFirebaseRegistration,
      )..validate();

  test('fully absent Firebase iOS config is allowed only in pending mode', () {
    final pending = validate();
    expect(pending.errors, isEmpty);
    expect(pending.externalBlockers, hasLength(1));

    final strict = validate(allowPendingFirebaseRegistration: false);
    expect(strict.errors, hasLength(1));
    expect(strict.externalBlockers, isEmpty);
  });

  for (final surface in _FirebaseSurface.values) {
    test('partial Firebase config fails when only ${surface.name} exists', () {
      fixture.enable(<_FirebaseSurface>{surface});

      final validator = validate();

      expect(
        validator.errors,
        contains(
          contains('Firebase iOS configuration is partial'),
        ),
      );
      expect(validator.externalBlockers, isEmpty);
    });
  }

  test('coherent generated Firebase config passes strict validation', () {
    fixture.enable(_FirebaseSurface.values.toSet());

    final validator = validate(allowPendingFirebaseRegistration: false);

    expect(validator.errors, isEmpty);
    expect(validator.externalBlockers, isEmpty);
  });

  test('mismatched iOS app IDs fail strict validation', () {
    fixture.enable(_FirebaseSurface.values.toSet());
    fixture.writeFirebaseJson(iosAppId: '1:137107376205:ios:feedface');

    final validator = validate(allowPendingFirebaseRegistration: false);

    expect(
      validator.errors,
      contains(
        contains('GOOGLE_APP_ID must be one registered'),
      ),
    );
  });

  test('dangling plist declaration outside Runner resources fails', () {
    fixture.enable(<_FirebaseSurface>{
      _FirebaseSurface.options,
      _FirebaseSurface.json,
      _FirebaseSurface.plist,
    });
    fixture.writeXcodeProject(_ResourceState.dangling);

    final validator = validate();

    expect(
      validator.errors,
      contains(
        contains('Firebase iOS configuration is partial'),
      ),
    );
  });

  test('Android FlutterFire mapping drift fails in pending mode', () {
    fixture.writeFirebaseJson(androidAppId: 'different-android-app');

    final validator = validate();

    expect(
      validator.errors,
      contains(
        contains('firebase.json must preserve the established Android'),
      ),
    );
  });
}

class _IosReadinessFixture {
  _IosReadinessFixture(this.root);

  final Directory root;

  void writeBase() {
    _write('.fvmrc', '{"flutter":"3.29.2"}');
    _write(
      'ios/Podfile',
      "platform :ios, '15.0'\n"
          "config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'\n",
    );
    _write(
      'ios/Flutter/AppFrameworkInfo.plist',
      _plist(<String, String>{'MinimumOSVersion': '15.0'}),
    );
    _write(
      'ios/Runner/Info.plist',
      _plist(<String, String>{
        'NSCameraUsageDescription': 'Take photos to share in chat.',
        'NSPhotoLibraryUsageDescription': 'Choose photos to share in chat.',
      }),
    );
    writeXcodeProject(_ResourceState.absent);
    writeFirebaseOptions(includeIos: false);
    writeFirebaseJson();
    _write('android/app/google-services.json', _googleServicesJson());
    _write(
      'android/app/build.gradle.kts',
      'namespace = "com.deluna.moonbase"\n'
          'applicationId = "com.deluna.moonbase"\n',
    );
  }

  void enable(Set<_FirebaseSurface> surfaces) {
    if (surfaces.contains(_FirebaseSurface.options)) {
      writeFirebaseOptions(includeIos: true);
    }
    if (surfaces.contains(_FirebaseSurface.json)) {
      writeFirebaseJson(iosAppId: _iosAppId);
    }
    if (surfaces.contains(_FirebaseSurface.plist)) {
      _write(
        'ios/Runner/GoogleService-Info.plist',
        _plist(<String, String>{
          'PROJECT_ID': 'moonbase-aaff7',
          'GOOGLE_APP_ID': _iosAppId,
          'BUNDLE_ID': 'com.deluna.moonbase',
          'GCM_SENDER_ID': '137107376205',
          'API_KEY': 'ios-api-key',
          'STORAGE_BUCKET': 'moonbase-aaff7.firebasestorage.app',
        }),
      );
    }
    if (surfaces.contains(_FirebaseSurface.xcodeResource)) {
      writeXcodeProject(_ResourceState.member);
    }
  }

  void writeFirebaseOptions({required bool includeIos}) {
    _write(
      'lib/firebase_options.dart',
      '''
class DefaultFirebaseOptions {
  static Object get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        ${includeIos ? 'return ios;' : "throw UnsupportedError('pending');"}
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAididoK_KvnH0a9Oukiyu2dte4-f4pzVA',
    appId: '$_androidAppId',
    messagingSenderId: '137107376205',
    projectId: 'moonbase-aaff7',
    storageBucket: 'moonbase-aaff7.firebasestorage.app',
  );
${includeIos ? _iosOptions : ''}
}
''',
    );
  }

  void writeFirebaseJson({
    String androidAppId = _androidAppId,
    String? iosAppId,
  }) {
    final platforms = <String, Object?>{
      'android': <String, Object?>{
        'default': <String, Object?>{
          'projectId': 'moonbase-aaff7',
          'appId': androidAppId,
          'fileOutput': 'android/app/google-services.json',
        },
      },
      'dart': <String, Object?>{
        'lib/firebase_options.dart': <String, Object?>{
          'projectId': 'moonbase-aaff7',
          'configurations': <String, Object?>{
            'android': _androidAppId,
            if (iosAppId != null) 'ios': iosAppId,
          },
        },
      },
      if (iosAppId != null)
        'ios': <String, Object?>{
          'default': <String, Object?>{
            'projectId': 'moonbase-aaff7',
            'appId': iosAppId,
            'fileOutput': 'ios/Runner/GoogleService-Info.plist',
          },
        },
    };
    _write(
      'firebase.json',
      jsonEncode(<String, Object?>{
        'flutter': <String, Object?>{'platforms': platforms},
      }),
    );
  }

  void writeXcodeProject(_ResourceState state) {
    const runnerTargetId = 'AAAAAAAAAAAAAAAAAAAAAAAA';
    const resourcesPhaseId = 'BBBBBBBBBBBBBBBBBBBBBBBB';
    const runnerGroupId = 'CCCCCCCCCCCCCCCCCCCCCCCC';
    const buildFileId = 'DDDDDDDDDDDDDDDDDDDDDDDD';
    const fileReferenceId = 'EEEEEEEEEEEEEEEEEEEEEEEE';
    final declaresResource = state != _ResourceState.absent;
    final isMember = state == _ResourceState.member;

    _write(
      'ios/Runner.xcodeproj/project.pbxproj',
      '''
${declaresResource ? '$buildFileId /* GoogleService-Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = $fileReferenceId /* GoogleService-Info.plist */; };' : ''}
${declaresResource ? '$fileReferenceId /* GoogleService-Info.plist */ = {isa = PBXFileReference; path = GoogleService-Info.plist; sourceTree = "<group>"; };' : ''}
$runnerGroupId /* Runner */ = {
  isa = PBXGroup;
  children = (
    ${declaresResource ? '$fileReferenceId /* GoogleService-Info.plist */,' : ''}
  );
};
$resourcesPhaseId /* Resources */ = {
  isa = PBXResourcesBuildPhase;
  files = (
    ${isMember ? '$buildFileId /* GoogleService-Info.plist in Resources */,' : ''}
  );
};
$runnerTargetId /* Runner */ = {
  isa = PBXNativeTarget;
  buildPhases = (
    $resourcesPhaseId /* Resources */,
  );
};
${List<String>.filled(3, 'PRODUCT_BUNDLE_IDENTIFIER = com.deluna.moonbase;').join('\n')}
${List<String>.filled(3, 'PRODUCT_BUNDLE_IDENTIFIER = com.deluna.moonbase.RunnerTests;').join('\n')}
${List<String>.filled(3, 'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;').join('\n')}
${List<String>.filled(6, 'CODE_SIGN_STYLE = Automatic;').join('\n')}
${List<String>.filled(3, 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;').join('\n')}
''',
    );
  }

  void _write(String relativePath, String contents) {
    final file = File(
      '${root.path}${Platform.pathSeparator}$relativePath',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }
}

const String _iosOptions = '''

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'ios-api-key',
    appId: '$_iosAppId',
    messagingSenderId: '137107376205',
    projectId: 'moonbase-aaff7',
    storageBucket: 'moonbase-aaff7.firebasestorage.app',
    iosBundleId: 'com.deluna.moonbase',
  );
''';

String _plist(Map<String, String> values) {
  final entries = values.entries
      .map(
        (entry) => '<key>${entry.key}</key><string>${entry.value}</string>',
      )
      .join();
  return '<plist><dict>$entries</dict></plist>';
}

String _googleServicesJson() => jsonEncode(<String, Object?>{
      'project_info': <String, Object?>{
        'project_number': '137107376205',
        'project_id': 'moonbase-aaff7',
        'storage_bucket': 'moonbase-aaff7.firebasestorage.app',
      },
      'client': <Object?>[
        <String, Object?>{
          'client_info': <String, Object?>{
            'mobilesdk_app_id': _androidAppId,
            'android_client_info': <String, Object?>{
              'package_name': 'com.deluna.moonbase',
            },
          },
          'api_key': <Object?>[
            <String, Object?>{
              'current_key': 'AIzaSyAididoK_KvnH0a9Oukiyu2dte4-f4pzVA',
            },
          ],
        },
      ],
    });
