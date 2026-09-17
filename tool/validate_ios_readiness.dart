import 'dart:convert';
import 'dart:io';

const String _expectedFlutterVersion = '3.29.2';
const String _expectedBundleId = 'com.deluna.moonbase';
const String _expectedProjectId = 'moonbase-aaff7';
const String _expectedSenderId = '137107376205';
const String _expectedDeploymentTarget = '15.0';
const String _expectedPlistPath = 'ios/Runner/GoogleService-Info.plist';

void main(List<String> arguments) {
  const pendingFlag = '--allow-pending-firebase-registration';
  final unknown = arguments.where((argument) => argument != pendingFlag);
  if (unknown.isNotEmpty) {
    stderr.writeln(
      'Usage: fvm dart run tool/validate_ios_readiness.dart [$pendingFlag]',
    );
    exitCode = 64;
    return;
  }

  final root = File.fromUri(Platform.script).parent.parent;
  final validator = _IosReadinessValidator(
    root: root,
    allowPendingFirebaseRegistration: arguments.contains(pendingFlag),
  )..validate();

  for (final message in validator.passes) {
    stdout.writeln('PASS: $message');
  }
  for (final message in validator.externalBlockers) {
    stdout.writeln('EXTERNAL: $message');
  }
  for (final message in validator.errors) {
    stderr.writeln('FAIL: $message');
  }

  if (validator.errors.isNotEmpty) {
    stderr.writeln(
      'iOS readiness validation failed with '
      '${validator.errors.length} repository error(s).',
    );
    exitCode = 1;
    return;
  }

  if (validator.externalBlockers.isNotEmpty) {
    stdout.writeln(
      'Repository structure is coherent up to the documented Firebase '
      'registration boundary.',
    );
    return;
  }

  stdout.writeln('Strict iOS repository readiness validation passed.');
}

class _IosReadinessValidator {
  _IosReadinessValidator({
    required this.root,
    required this.allowPendingFirebaseRegistration,
  });

  final Directory root;
  final bool allowPendingFirebaseRegistration;
  final List<String> passes = <String>[];
  final List<String> externalBlockers = <String>[];
  final List<String> errors = <String>[];

  void validate() {
    final fvmConfig = _decodeJsonObject(_read('.fvmrc'));
    _expect(
      fvmConfig['flutter'] == _expectedFlutterVersion,
      'FVM pins Flutter $_expectedFlutterVersion.',
      '.fvmrc must pin Flutter $_expectedFlutterVersion.',
    );

    final xcodeProject = _read('ios/Runner.xcodeproj/project.pbxproj');
    _validateXcodeProject(xcodeProject);
    _validateDeploymentTargets();
    _validatePermissions();
    _validateFirebase(xcodeProject);
  }

  void _validateXcodeProject(String project) {
    final identifiers = RegExp(
      r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);',
    ).allMatches(project).map((match) => match.group(1)!).toList();
    final runnerIdentifiers = identifiers
        .where((identifier) => !identifier.endsWith('.RunnerTests'))
        .toList();
    final testIdentifiers = identifiers
        .where((identifier) => identifier.endsWith('.RunnerTests'))
        .toList();

    _expect(
      runnerIdentifiers.length == 3 &&
          runnerIdentifiers.every(
            (identifier) => identifier == _expectedBundleId,
          ),
      'Runner Debug/Profile/Release use $_expectedBundleId.',
      'Runner Debug/Profile/Release must all use $_expectedBundleId.',
    );
    _expect(
      testIdentifiers.length == 3 &&
          testIdentifiers.every(
            (identifier) => identifier == '$_expectedBundleId.RunnerTests',
          ),
      'RunnerTests identifiers derive from the Runner identifier.',
      'RunnerTests Debug/Profile/Release must use '
          '$_expectedBundleId.RunnerTests.',
    );

    final assetSymbolSettings = RegExp(
      r'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;',
    ).allMatches(project).length;
    _expect(
      assetSymbolSettings == 3,
      'Asset-symbol generation uses valid boolean settings.',
      'Every Xcode project configuration must set asset-symbol generation '
          'to YES.',
    );

    final automaticSigningCount =
        RegExp(r'CODE_SIGN_STYLE = Automatic;').allMatches(project).length;
    _expect(
      automaticSigningCount >= 6,
      'Runner and RunnerTests use automatic signing.',
      'Every Runner and RunnerTests configuration must use automatic signing.',
    );
    _expect(
      !RegExp(r'DEVELOPMENT_TEAM\s*=').hasMatch(project),
      'No developer team is committed; the Personal Team remains local.',
      'Do not commit a developer team; select the Personal Team locally.',
    );
  }

  void _validateDeploymentTargets() {
    final project = _read('ios/Runner.xcodeproj/project.pbxproj');
    final xcodeTargets = RegExp(
      r'IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);',
    ).allMatches(project).map((match) => match.group(1)!).toList();
    _expect(
      xcodeTargets.length == 3 &&
          xcodeTargets.every(
            (target) => target == _expectedDeploymentTarget,
          ),
      'Xcode project configurations target iOS $_expectedDeploymentTarget.',
      'Every Xcode project configuration must target iOS '
          '$_expectedDeploymentTarget.',
    );

    final podfile = _read('ios/Podfile');
    _expect(
      podfile.contains("platform :ios, '$_expectedDeploymentTarget'") &&
          podfile.contains(
            "config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = "
            "'$_expectedDeploymentTarget'",
          ),
      'Runner and pods share the iOS $_expectedDeploymentTarget target.',
      'Podfile platform and pod overrides must both target iOS '
          '$_expectedDeploymentTarget.',
    );

    final frameworkPlist = _read('ios/Flutter/AppFrameworkInfo.plist');
    _expect(
      _plistValue(frameworkPlist, 'MinimumOSVersion') ==
          _expectedDeploymentTarget,
      'AppFrameworkInfo.plist targets iOS $_expectedDeploymentTarget.',
      'AppFrameworkInfo.plist MinimumOSVersion must be '
          '$_expectedDeploymentTarget.',
    );
  }

  void _validatePermissions() {
    final infoPlist = _read('ios/Runner/Info.plist');
    final cameraDescription =
        _plistValue(infoPlist, 'NSCameraUsageDescription');
    final photoDescription =
        _plistValue(infoPlist, 'NSPhotoLibraryUsageDescription');

    _expect(
      cameraDescription != null &&
          cameraDescription.isNotEmpty &&
          !cameraDescription.toLowerCase().contains('video'),
      'Camera usage text is photo-only.',
      'NSCameraUsageDescription must explain photo capture only.',
    );
    _expect(
      photoDescription != null &&
          photoDescription.isNotEmpty &&
          !photoDescription.toLowerCase().contains('video'),
      'Photo-library usage text is image-only.',
      'NSPhotoLibraryUsageDescription must explain photo selection only.',
    );
    _expect(
      _plistValue(infoPlist, 'NSMicrophoneUsageDescription') == null,
      'No microphone permission is declared.',
      'Images-only chat must not declare NSMicrophoneUsageDescription.',
    );
    _expect(
      _plistValue(infoPlist, 'NSPhotoLibraryAddUsageDescription') == null,
      'No unused photo-library write permission is declared.',
      'Do not declare NSPhotoLibraryAddUsageDescription without a save flow.',
    );
  }

  void _validateFirebase(String xcodeProject) {
    final optionsSource = _read('lib/firebase_options.dart');
    final firebaseJson = _decodeJsonObject(_read('firebase.json'));
    final flutterConfig = _mapValue(firebaseJson['flutter']);
    final platforms = _mapValue(flutterConfig?['platforms']);
    final iosPlatform = _mapValue(platforms?['ios']);
    final iosDefault = _mapValue(iosPlatform?['default']);
    final dartPlatform = _mapValue(platforms?['dart']);
    final dartOptions = _mapValue(dartPlatform?['lib/firebase_options.dart']);
    final dartConfigurations = _mapValue(dartOptions?['configurations']);

    final options = _firebaseIosOptions(optionsSource);
    final optionsConfigured = RegExp(r'case TargetPlatform\.iOS:\s+return ios;')
            .hasMatch(optionsSource) &&
        options.isNotEmpty;
    final jsonAppId = _stringValue(iosDefault?['appId']);
    final jsonConfigured = jsonAppId != null;
    final plistFile = File(_path(_expectedPlistPath));
    final plistConfigured = plistFile.existsSync();
    final xcodeConfigured =
        xcodeProject.contains('GoogleService-Info.plist in Resources');

    final firebaseSurfaces = <bool>[
      optionsConfigured,
      jsonConfigured,
      plistConfigured,
      xcodeConfigured,
    ];
    if (firebaseSurfaces.every((configured) => !configured)) {
      const boundary =
          'Firebase iOS app registration is pending. Authenticate an owner of '
          '$_expectedProjectId, run the documented FlutterFire command, commit '
          'firebase_options.dart, firebase.json, GoogleService-Info.plist, and '
          'the Xcode resource update, then rerun strict validation.';
      if (allowPendingFirebaseRegistration) {
        externalBlockers.add(boundary);
      } else {
        errors.add(boundary);
      }
      return;
    }

    _expect(
      firebaseSurfaces.every((configured) => configured),
      'All four Firebase iOS configuration surfaces are present.',
      'Firebase iOS configuration is partial; options, firebase.json, plist, '
          'and Xcode resource membership must land together.',
    );
    if (!firebaseSurfaces.every((configured) => configured)) {
      return;
    }

    final plist = plistFile.readAsStringSync();
    final plistAppId = _plistValue(plist, 'GOOGLE_APP_ID');
    final plistApiKey = _plistValue(plist, 'API_KEY');
    final plistProjectId = _plistValue(plist, 'PROJECT_ID');
    final plistBundleId = _plistValue(plist, 'BUNDLE_ID');
    final plistSenderId = _plistValue(plist, 'GCM_SENDER_ID');
    final plistStorageBucket = _plistValue(plist, 'STORAGE_BUCKET');

    _expect(
      plistProjectId == _expectedProjectId &&
          _stringValue(iosDefault?['projectId']) == _expectedProjectId &&
          options['projectId'] == _expectedProjectId,
      'Firebase project ID agrees across generated surfaces.',
      'PROJECT_ID must be $_expectedProjectId in options, firebase.json, '
          'and GoogleService-Info.plist.',
    );
    _expect(
      plistBundleId == _expectedBundleId &&
          options['iosBundleId'] == _expectedBundleId,
      'Firebase and Xcode use the same case-sensitive bundle identifier.',
      'Firebase BUNDLE_ID and iosBundleId must be $_expectedBundleId.',
    );
    _expect(
      plistAppId == jsonAppId &&
          options['appId'] == jsonAppId &&
          _stringValue(dartConfigurations?['ios']) == jsonAppId &&
          RegExp(r'^1:137107376205:ios:[0-9a-f]+$').hasMatch(jsonAppId!),
      'Firebase iOS app ID agrees across generated surfaces.',
      'GOOGLE_APP_ID must be one registered $_expectedProjectId iOS app ID '
          'in options, firebase.json, and the plist.',
    );
    _expect(
      plistApiKey != null &&
          plistApiKey.isNotEmpty &&
          options['apiKey'] == plistApiKey,
      'Firebase iOS API key agrees across generated surfaces.',
      'API_KEY must agree between firebase_options.dart and the plist.',
    );
    _expect(
      plistSenderId == _expectedSenderId &&
          options['messagingSenderId'] == _expectedSenderId,
      'Firebase sender ID agrees across generated surfaces.',
      'GCM_SENDER_ID and messagingSenderId must be $_expectedSenderId.',
    );
    _expect(
      plistStorageBucket != null &&
          plistStorageBucket.isNotEmpty &&
          options['storageBucket'] == plistStorageBucket,
      'Firebase Storage bucket agrees across generated surfaces.',
      'STORAGE_BUCKET must agree between firebase_options.dart and the plist.',
    );
    _expect(
      _stringValue(iosDefault?['fileOutput']) == _expectedPlistPath,
      'firebase.json points to the tracked Runner plist.',
      'firebase.json iOS fileOutput must be $_expectedPlistPath.',
    );
  }

  String _read(String relativePath) =>
      File(_path(relativePath)).readAsStringSync();

  String _path(String relativePath) =>
      '${root.path}${Platform.pathSeparator}$relativePath';

  void _expect(bool condition, String pass, String failure) {
    if (condition) {
      passes.add(pass);
    } else {
      errors.add(failure);
    }
  }
}

Map<String, Object?> _decodeJsonObject(String source) {
  final Object? decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object.');
  }
  return decoded.cast<String, Object?>();
}

Map<String, Object?>? _mapValue(Object? value) {
  if (value is! Map<String, dynamic>) {
    return null;
  }
  return value.cast<String, Object?>();
}

String? _stringValue(Object? value) => value is String ? value : null;

String? _plistValue(String source, String key) {
  final match = RegExp(
    '<key>\\s*${RegExp.escape(key)}\\s*</key>\\s*'
    '<string>([^<]*)</string>',
  ).firstMatch(source);
  return match?.group(1)?.trim();
}

Map<String, String> _firebaseIosOptions(String source) {
  final block = RegExp(
    r'static const FirebaseOptions ios = FirebaseOptions\((.*?)\n\s*\);',
    dotAll: true,
  ).firstMatch(source)?.group(1);
  if (block == null) {
    return const <String, String>{};
  }

  final values = <String, String>{};
  for (final key in <String>[
    'apiKey',
    'appId',
    'messagingSenderId',
    'projectId',
    'storageBucket',
    'iosBundleId',
  ]) {
    final value = RegExp("$key: '([^']+)'").firstMatch(block)?.group(1);
    if (value != null) {
      values[key] = value;
    }
  }
  return values;
}
