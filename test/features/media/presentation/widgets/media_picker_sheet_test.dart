import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/platform_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_pick_request.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_picker.dart';
import 'package:moonbase_skeleton/features/media/domain/usecases/pick_and_persist_media.dart';
import 'package:moonbase_skeleton/features/media/presentation/providers/media_providers.dart';
import 'package:moonbase_skeleton/features/media/presentation/widgets/media_picker_sheet.dart';

class _DummyPicker implements MediaPicker {
  @override
  Future<MediaRef?> pickImage(MediaPickRequest request) =>
      throw UnimplementedError();

  @override
  Future<MediaRef?> pickVideo(MediaPickRequest request) =>
      throw UnimplementedError();

  @override
  Future<MediaRef?> captureFromCamera(MediaPickRequest request) =>
      throw UnimplementedError();
}

class _StubPickAndPersist extends PickAndPersistMedia {
  _StubPickAndPersist(this.result) : super(_DummyPicker());

  final Either<Failure, MediaRef?> result;

  @override
  Future<Either<Failure, MediaRef?>> call(MediaPickRequest params) async =>
      result;
}

void main() {
  const baseId = BaseId('b1');

  tearDown(resetOpenAppSettingsHandler);

  Future<void> openSheetAndPickCamera(
    WidgetTester tester,
    Either<Failure, MediaRef?> result,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pickAndPersistMediaUseCaseProvider.overrideWith(
            (ref) => _StubPickAndPersist(result),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => MediaPickerSheet.show(context, baseId),
                  child: const Text('Attach'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Attach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camera (Photo)'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'permission failure dismisses sheet and shows snackbar on host scaffold',
    (tester) async {
      await openSheetAndPickCamera(
        tester,
        const Left(PermissionDeniedFailure()),
      );

      expect(find.byType(MediaPickerSheet), findsNothing);
      expect(
        find.text('Permission required. Enable camera or photo access in Settings.'),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsOneWidget);
    },
  );

  testWidgets('Open Settings tap invokes app settings handler', (tester) async {
    var settingsOpened = false;
    openAppSettingsHandler = () async {
      settingsOpened = true;
      return true;
    };

    await openSheetAndPickCamera(
      tester,
      const Left(PermissionDeniedFailure()),
    );

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(settingsOpened, isTrue);
  });

  testWidgets(
    'validation failure dismisses sheet and shows snackbar on host scaffold',
    (tester) async {
      await openSheetAndPickCamera(
        tester,
        const Left(MediaTooLargeFailure()),
      );

      expect(find.byType(MediaPickerSheet), findsNothing);
      expect(find.text('That file is too large to attach.'), findsOneWidget);
    },
  );
}
