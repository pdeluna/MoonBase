import 'dart:convert';
import 'dart:io';

const String _expectedFlutterVersion = '3.29.2';
const String _expectedBundleId = 'com.deluna.moonbase';
const String _expectedProjectId = 'moonbase-aaff7';
const String _expectedSenderId = '137107376205';
const String _expectedStorageBucket = 'moonbase-aaff7.firebasestorage.app';
const String _expectedAndroidAppId =
    '1:137107376205:android:f74e18c46e57a45b9bf404';
const String _expectedAndroidApiKey = 'AIzaSyAididoK_KvnH0a9Oukiyu2dte4-f4pzVA';
const String _expectedAndroidConfigPath = 'android/app/google-services.json';
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
  final validator = IosReadinessValidator(
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

class IosReadinessValidator {
  IosReadinessValidator({
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

  void _validateAndroidFirebase({
    required String optionsSource,
    required Map<String, Object?>? androidDefault,
    required Map<String, Object?>? dartOptions,
    required Map<String, Object?>? dartConfigurations,
  }) {
    final options = _firebaseOptions(optionsSource, 'android');
    final googleServices = _decodeJsonObject(
      _read(_expectedAndroidConfigPath),
    );
    final projectInfo = _mapValue(googleServices['project_info']);
    final clients = _listValue(googleServices['client']);

    Map<String, Object?>? matchingClient;
    for (final value in clients ?? const <Object?>[]) {
      final client = _mapValue(value);
      final clientInfo = _mapValue(client?['client_info']);
      final androidInfo = _mapValue(clientInfo?['android_client_info']);
      if (_stringValue(androidInfo?['package_name']) == _expectedBundleId) {
        matchingClient = client;
        break;
      }
    }

    final clientInfo = _mapValue(matchingClient?['client_info']);
    final apiKeys = _listValue(matchingClient?['api_key']);
    final firstApiKey =
        apiKeys == null || apiKeys.isEmpty ? null : _mapValue(apiKeys.first);

    _expect(
      _stringValue(androidDefault?['projectId']) == _expectedProjectId &&
          _stringValue(androidDefault?['appId']) == _expectedAndroidAppId &&
          _stringValue(androidDefault?['fileOutput']) ==
              _expectedAndroidConfigPath,
      'firebase.json preserves the established Android app mapping.',
      'firebase.json must preserve the established Android project, app ID, '
          'and google-services.json path.',
    );
    _expect(
      _stringValue(dartOptions?['projectId']) == _expectedProjectId &&
          _stringValue(dartConfigurations?['android']) == _expectedAndroidAppId,
      'FlutterFire Dart mapping preserves Android project and app IDs.',
      'firebase.json Dart mapping must preserve Android project '
          '$_expectedProjectId and app $_expectedAndroidAppId.',
    );
    _expect(
      RegExp(r'case TargetPlatform\.android:\s+return android;')
              .hasMatch(optionsSource) &&
          options['apiKey'] == _expectedAndroidApiKey &&
          options['appId'] == _expectedAndroidAppId &&
          options['messagingSenderId'] == _expectedSenderId &&
          options['projectId'] == _expectedProjectId &&
          options['storageBucket'] == _expectedStorageBucket,
      'firebase_options.dart preserves established Android options.',
      'firebase_options.dart Android options drifted from the established '
          'moonbase-aaff7 app.',
    );
    _expect(
      _stringValue(projectInfo?['project_number']) == _expectedSenderId &&
          _stringValue(projectInfo?['project_id']) == _expectedProjectId &&
          _stringValue(projectInfo?['storage_bucket']) ==
              _expectedStorageBucket &&
          _stringValue(clientInfo?['mobilesdk_app_id']) ==
              _expectedAndroidAppId &&
          _stringValue(firstApiKey?['current_key']) == _expectedAndroidApiKey,
      'google-services.json preserves the established Android client.',
      'android/app/google-services.json drifted from the established '
          'moonbase-aaff7 Android client.',
    );

    final androidGradle = _read('android/app/build.gradle.kts');
    _expect(
      androidGradle.contains('namespace = "$_expectedBundleId"') &&
          androidGradle.contains('applicationId = "$_expectedBundleId"'),
      'Android Gradle identity remains $_expectedBundleId.',
      'Android namespace and applicationId must remain $_expectedBundleId.',
    );
  }

  void _validateFirebase(String xcodeProject) {
    final optionsSource = _read('lib/firebase_options.dart');
    final firebaseJson = _decodeJsonObject(_read('firebase.json'));
    final flutterConfig = _mapValue(firebaseJson['flutter']);
    final platforms = _mapValue(flutterConfig?['platforms']);
    final androidPlatform = _mapValue(platforms?['android']);
    final androidDefault = _mapValue(androidPlatform?['default']);
    final iosPlatform = _mapValue(platforms?['ios']);
    final iosDefault = _mapValue(iosPlatform?['default']);
    final dartPlatform = _mapValue(platforms?['dart']);
    final dartOptions = _mapValue(dartPlatform?['lib/firebase_options.dart']);
    final dartConfigurations = _mapValue(dartOptions?['configurations']);

    _validateAndroidFirebase(
      optionsSource: optionsSource,
      androidDefault: androidDefault,
      dartOptions: dartOptions,
      dartConfigurations: dartConfigurations,
    );

    final options = _firebaseOptions(optionsSource, 'ios');
    final optionsConfigured = RegExp(r'case TargetPlatform\.iOS:\s+return ios;')
            .hasMatch(optionsSource) &&
        options.isNotEmpty;
    final jsonAppId = _stringValue(iosDefault?['appId']);
    final jsonConfigured = jsonAppId != null;
    final plistFile = File(_path(_expectedPlistPath));
    final plistConfigured = plistFile.existsSync();
    final xcodeConfigured =
        _runnerResourcesContainGoogleServicePlist(xcodeProject);

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

bool _runnerResourcesContainGoogleServicePlist(String project) {
  final runnerTarget = RegExp(
    r'([A-Fa-f0-9]{24}) /\* Runner \*/ = \{\s*'
    r'isa = PBXNativeTarget;',
  ).firstMatch(project);
  if (runnerTarget == null) {
    return false;
  }

  final targetBlock = _pbxObjectBlock(project, runnerTarget.start);
  final resourcesPhaseId = RegExp(
    r'([A-Fa-f0-9]{24}) /\* Resources \*/,',
  ).firstMatch(targetBlock)?.group(1);
  if (resourcesPhaseId == null) {
    return false;
  }

  final phaseDeclaration = RegExp(
    '${RegExp.escape(resourcesPhaseId)} /\\* Resources \\*/ = \\{\\s*'
    'isa = PBXResourcesBuildPhase;',
  ).firstMatch(project);
  if (phaseDeclaration == null) {
    return false;
  }

  final phaseBlock = _pbxObjectBlock(project, phaseDeclaration.start);
  final files = RegExp(
    r'files = \((.*?)\);',
    dotAll: true,
  ).firstMatch(phaseBlock)?.group(1);
  final buildFileId = files == null
      ? null
      : RegExp(
          r'([A-Fa-f0-9]{24}) '
          r'/\* GoogleService-Info\.plist in Resources \*/,',
        ).firstMatch(files)?.group(1);
  if (buildFileId == null) {
    return false;
  }

  final buildFile = RegExp(
    '${RegExp.escape(buildFileId)} '
    r'/\* GoogleService-Info\.plist in Resources \*/ = \{\s*'
    r'isa = PBXBuildFile;\s*'
    r'fileRef = ([A-Fa-f0-9]{24}) '
    r'/\* GoogleService-Info\.plist \*/;\s*\};',
  ).firstMatch(project);
  final fileReferenceId = buildFile?.group(1);
  if (fileReferenceId == null) {
    return false;
  }

  final fileReference = RegExp(
    '${RegExp.escape(fileReferenceId)} '
    r'/\* GoogleService-Info\.plist \*/ = \{\s*'
    r'isa = PBXFileReference;(.*?)\};',
    dotAll: true,
  ).firstMatch(project)?.group(1);
  final rawPath = fileReference == null
      ? null
      : RegExp(r'path = ([^;]+);').firstMatch(fileReference)?.group(1);
  final path = rawPath == null ? null : _unquotePbxValue(rawPath.trim());
  if (path == 'Runner/GoogleService-Info.plist') {
    return true;
  }
  if (path != 'GoogleService-Info.plist') {
    return false;
  }

  final runnerGroup = RegExp(
    r'([A-Fa-f0-9]{24}) /\* Runner \*/ = \{\s*isa = PBXGroup;',
  ).firstMatch(project);
  if (runnerGroup == null) {
    return false;
  }
  return _pbxObjectBlock(project, runnerGroup.start)
      .contains('$fileReferenceId /* GoogleService-Info.plist */');
}

String _pbxObjectBlock(String source, int objectStart) {
  final openingBrace = source.indexOf('{', objectStart);
  if (openingBrace == -1) {
    return '';
  }

  var depth = 0;
  for (var index = openingBrace; index < source.length; index++) {
    final character = source[index];
    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(objectStart, index + 1);
      }
    }
  }
  return '';
}

String _unquotePbxValue(String value) {
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    return value.substring(1, value.length - 1);
  }
  return value;
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

List<Object?>? _listValue(Object? value) {
  if (value is! List<dynamic>) {
    return null;
  }
  return value.cast<Object?>();
}

String? _stringValue(Object? value) => value is String ? value : null;

String? _plistValue(String source, String key) {
  final match = RegExp(
    '<key>\\s*${RegExp.escape(key)}\\s*</key>\\s*'
    '<string>([^<]*)</string>',
  ).firstMatch(source);
  return match?.group(1)?.trim();
}

Map<String, String> _firebaseOptions(String source, String platform) {
  final block = RegExp(
    'static const FirebaseOptions ${RegExp.escape(platform)} = '
    r'FirebaseOptions\((.*?)\n\s*\);',
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
