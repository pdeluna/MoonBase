import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/platform_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_constraints.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_pick_request.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/usecases/pick_and_persist_multiple_images.dart';
import 'package:moonbase_skeleton/features/media/presentation/providers/media_providers.dart';

/// Modal bottom sheet that offers the four OS-mediated capture/pick paths:
///
/// 1. Camera (Photo)
/// 2. Camera (Video)
/// 3. Photo Library
/// 4. Video Library
///
/// Each option drives the appropriate pick use case, then pops the sheet with
/// the resulting refs. Returns an empty list on cancel or pick failure.
///
/// Pick failures dismiss the sheet first, then show a [SnackBar] on
/// [hostContext]'s scaffold so the message is not hidden behind the modal
/// layer (POL-1). `PermissionDeniedFailure` adds an "Open Settings" action
/// that deep-links to the app's OS settings page (POL-2).
class MediaPickerSheet extends ConsumerWidget {
  const MediaPickerSheet({
    super.key,
    required this.baseId,
    required this.hostContext,
    required this.remainingSlots,
  });

  final BaseId baseId;

  /// Scaffold context below the modal (e.g. [ChatScreen]). Snackbars are
  /// shown here after the sheet is dismissed.
  final BuildContext hostContext;

  /// How many more attachments the caller can stage (caps gallery multi-pick).
  final int remainingSlots;

  /// Convenience entrypoint. Returns picked refs (empty on cancel / failure).
  ///
  /// [remainingSlots] limits gallery multi-select (POL-3). Camera and video
  /// library paths always return at most one item.
  static Future<List<MediaRef>> show(
    BuildContext context,
    BaseId baseId, {
    int remainingSlots = MediaConstraints.maxMediaPerMessageDefault,
  }) async {
    final hostContext = context;
    final result = await showModalBottomSheet<List<MediaRef>?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MediaPickerSheet(
        baseId: baseId,
        hostContext: hostContext,
        remainingSlots: remainingSlots,
      ),
    );
    return result ?? const [];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PickerOption(
              icon: Icons.photo_camera_outlined,
              label: 'Camera (Photo)',
              onTap: () => _runPick(
                context,
                ref,
                source: MediaSource.camera,
                kind: MediaType.image,
              ),
            ),
            _PickerOption(
              icon: Icons.videocam_outlined,
              label: 'Camera (Video)',
              onTap: () => _runPick(
                context,
                ref,
                source: MediaSource.camera,
                kind: MediaType.video,
              ),
            ),
            const Divider(height: 8),
            _PickerOption(
              icon: Icons.photo_library_outlined,
              label: 'Photo Library',
              onTap: () => _runGalleryImages(sheetContext: context, ref: ref),
            ),
            _PickerOption(
              icon: Icons.video_library_outlined,
              label: 'Video Library',
              onTap: () => _runPick(
                context,
                ref,
                source: MediaSource.gallery,
                kind: MediaType.video,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runGalleryImages({
    required BuildContext sheetContext,
    required WidgetRef ref,
  }) async {
    if (remainingSlots <= 0) {
      Navigator.of(sheetContext).pop(const <MediaRef>[]);
      return;
    }

    final useCase = ref.read(pickAndPersistMultipleImagesUseCaseProvider);
    final request = MediaPickRequest(
      baseId: baseId,
      kind: MediaType.image,
      source: MediaSource.gallery,
    );
    final Either<Failure, List<MediaRef>> result = await useCase(
      PickMultipleImagesParams(request: request, limit: remainingSlots),
    );

    if (!sheetContext.mounted) return;

    result.match(
      (failure) => _showFailure(sheetContext, failure),
      (refs) => Navigator.of(sheetContext).pop(refs),
    );
  }

  Future<void> _runPick(
    BuildContext sheetContext,
    WidgetRef ref, {
    required MediaSource source,
    required MediaType kind,
  }) async {
    final useCase = ref.read(pickAndPersistMediaUseCaseProvider);
    final request = MediaPickRequest(
      baseId: baseId,
      kind: kind,
      source: source,
    );
    final Either<Failure, MediaRef?> result = await useCase(request);

    if (!sheetContext.mounted) return;

    result.match(
      (failure) => _showFailure(sheetContext, failure),
      (mediaRef) {
        final refs = mediaRef == null ? const <MediaRef>[] : [mediaRef];
        Navigator.of(sheetContext).pop(refs);
      },
    );
  }

  void _showFailure(BuildContext sheetContext, Failure failure) {
    // Dismiss the modal first — snackbars on the sheet's scaffold render
    // underneath the bottom sheet and are invisible until the user closes it.
    Navigator.of(sheetContext).pop();
    if (!hostContext.mounted) return;

    final messenger = ScaffoldMessenger.of(hostContext);
    if (failure is PermissionDeniedFailure) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Permission required. Enable camera or photo access in Settings.',
          ),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: () => _openSettingsFromSnackBar(messenger),
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(_friendlyFailure(failure))),
    );
  }

  void _openSettingsFromSnackBar(ScaffoldMessengerState messenger) {
    openAppPermissionSettings().then((opened) {
      if (opened || !hostContext.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not open Settings on this device.'),
        ),
      );
    });
  }

  String _friendlyFailure(Failure f) {
    if (f is MediaTooLargeFailure) return 'That file is too large to attach.';
    if (f is MediaTooLongFailure) return 'That video is longer than allowed.';
    if (f is MediaUnsupportedFailure) {
      return 'That file type isn’t supported here.';
    }
    return f.message;
  }
}

class _PickerOption extends StatelessWidget {
  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
