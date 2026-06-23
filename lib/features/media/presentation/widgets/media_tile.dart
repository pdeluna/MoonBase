import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/presentation/providers/media_providers.dart';
import 'package:moonbase_skeleton/features/media/presentation/widgets/video_thumbnail.dart';

/// Pure scheme→`ImageProvider` dispatch.
///
/// Lifted out of `_ImageView` so unit tests can verify the
/// "file:// → FileImage, https:// → NetworkImage" contract without spinning
/// up a full widget tree (which would otherwise schedule a real image
/// decode or HTTP fetch, hanging the test).
///
/// Visible for testing.
ImageProvider imageProviderForUri(String uri) {
  final parsed = Uri.tryParse(uri);
  final scheme = parsed?.scheme ?? '';
  if (scheme == 'http' || scheme == 'https') {
    return NetworkImage(uri);
  }
  final path = scheme == 'file' ? Uri.parse(uri).toFilePath() : uri;
  return FileImage(File(path));
}

/// Renders a single `MediaRef` as a small tile suitable for inline chat
/// bubbles, post grids, and story bubbles.
///
/// Resolution flow:
///
/// 1. Read `mediaStorageProvider` and call `resolveUri(storageKey)`.
/// 2. Based on the returned URI scheme (`file://` vs `https://`), use
///    `Image.file` or `Image.network` for images; for video, paint a
///    `VideoThumbnail` (tap → `onTap` to open `MediaPreview`).
///
/// This widget is the **only** sanctioned "dumb tile" that reads a provider
/// directly; URI resolution is platform-specific infrastructure that does
/// not belong in a controller. See Phase 3 architectural constraint #3 in
/// `docs/PHASE3_DOD_ACTION_LIST.md`.
class MediaTile extends ConsumerWidget {
  const MediaTile({
    super.key,
    required this.media,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.onTap,
  });

  final MediaRef media;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  /// Called when the user taps the tile. Typical wiring: push a
  /// `MediaPreview` route for the same `MediaRef`.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(mediaStorageProvider);
    return FutureBuilder<String>(
      future: storage.resolveUri(media.storageKey),
      builder: (context, snap) {
        final Widget body;
        if (snap.connectionState != ConnectionState.done) {
          body = _Placeholder(width: width, height: height);
        } else if (snap.hasError || snap.data == null) {
          body = _Broken(width: width, height: height);
        } else {
          body = _renderFor(snap.data!);
        }
        return GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: SizedBox(width: width, height: height, child: body),
          ),
        );
      },
    );
  }

  Widget _renderFor(String uri) {
    switch (media.type) {
      case MediaType.image:
        return _ImageView(uri: uri, fit: fit);
      case MediaType.video:
        return VideoThumbnail(
          duration: media.duration,
          width: width,
          height: height,
          borderRadius: BorderRadius.zero,
        );
    }
  }
}

class _ImageView extends StatelessWidget {
  const _ImageView({required this.uri, required this.fit});

  final String uri;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: imageProviderForUri(uri),
      fit: fit,
      errorBuilder: (_, __, ___) => const _Broken(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _Placeholder();
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _Broken extends StatelessWidget {
  const _Broken({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.errorContainer,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: cs.onErrorContainer),
        ),
      ),
    );
  }
}
