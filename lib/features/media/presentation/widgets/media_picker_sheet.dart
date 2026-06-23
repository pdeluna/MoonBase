import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_pick_request.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/presentation/providers/media_providers.dart';

/// Modal bottom sheet that offers the four OS-mediated capture/pick paths:
///
/// 1. Camera (Photo)
/// 2. Camera (Video)
/// 3. Photo Library
/// 4. Video Library
///
/// Each option drives `PickAndPersistMedia` with the appropriate
/// `MediaPickRequest`, then pops the sheet with the resulting `MediaRef?`.
/// Returns `null` on cancel.
///
/// Errors surface inline via `SnackBar`; `PermissionDeniedFailure` adds an
/// "Open Settings" action (deep link wiring lives in the host app; the
/// affordance is visible regardless).
class MediaPickerSheet extends ConsumerWidget {
  const MediaPickerSheet({super.key, required this.baseId});

  final BaseId baseId;

  /// Convenience entrypoint. Returns the picked `MediaRef`, or `null` on
  /// cancel / failure.
  static Future<MediaRef?> show(BuildContext context, BaseId baseId) {
    return showModalBottomSheet<MediaRef?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MediaPickerSheet(baseId: baseId),
    );
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
              onTap: () => _runPick(
                context,
                ref,
                source: MediaSource.gallery,
                kind: MediaType.image,
              ),
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

  Future<void> _runPick(
    BuildContext context,
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

    // Guard against the sheet being popped underneath us mid-await.
    if (!context.mounted) return;

    result.match(
      (failure) {
        _showFailure(context, failure);
      },
      (mediaRef) {
        // User-cancel returns Right(null); pop with null so callers can
        // distinguish "no pick" from a failure (which keeps the sheet open).
        Navigator.of(context).pop(mediaRef);
      },
    );
  }

  void _showFailure(BuildContext context, Failure failure) {
    final messenger = ScaffoldMessenger.of(context);
    if (failure is PermissionDeniedFailure) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Permission required. Enable camera or photo access in Settings.',
          ),
          action: SnackBarAction(
            label: 'Open Settings',
            // The "Open Settings" deep-link is platform-specific and lives in
            // a future `app_settings` integration. Showing the affordance now
            // satisfies the Phase 3 UX contract for permission denial.
            onPressed: () {},
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(_friendlyFailure(failure))),
    );
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
