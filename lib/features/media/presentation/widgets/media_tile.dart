import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';
import 'package:moonbase_skeleton/features/media/presentation/providers/media_providers.dart';
import 'package:moonbase_skeleton/features/media/presentation/widgets/video_thumbnail.dart';

/// Pure scheme→`ImageProvider` dispatch.
///
/// Lifted out of `_ImageView` so unit tests can verify the
/// "file:// → FileImage, https:// → CachedNetworkImageProvider" contract
/// without spinning up a full widget tree.
///
/// For https, [cacheKey] must be the stable Storage path
/// (`bases/{baseId}/media/{uuid}.jpg`), never the tokenized download URL —
/// otherwise a rotated token forces a silent re-download every session.
///
/// Visible for testing.
ImageProvider imageProviderForUri(String uri, {String? cacheKey}) {
  final parsed = Uri.tryParse(uri);
  final scheme = parsed?.scheme ?? '';
  if (scheme == 'http' || scheme == 'https') {
    return CachedNetworkImageProvider(uri, cacheKey: cacheKey ?? uri);
  }
  final path = scheme == 'file' ? Uri.parse(uri).toFilePath() : uri;
  return FileImage(File(path));
}

/// Renders a single `MediaRef` as a small tile suitable for inline chat
/// bubbles, post grids, and story bubbles.
///
/// Resolution flow:
///
/// 1. Read `mediaStorageProvider` and resolve `storageKey` (images + video
///    without poster) or `thumbnailKey` (video poster, POL-4).
/// 2. Based on the returned URI scheme (`file://` vs `https://`), use
///    `Image.file` or `CachedNetworkImage` for images; for video, paint a
///    `VideoThumbnail` with an optional poster underlay.
///
/// Failure contract: [MediaStorage.resolveUri] throws → `FutureBuilder.hasError`
/// → broken-image widget. Network decode/download failures →
/// [CachedNetworkImage.errorWidget] → same broken-image widget. There is no
/// path that leaves the tile on the loading placeholder forever after a
/// terminal failure.
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

  /// Key passed to [MediaStorage.resolveUri] and used as the network cache key.
  String get _resolveKey {
    if (media.type == MediaType.video && media.thumbnailKey != null) {
      return media.thumbnailKey!;
    }
    return media.storageKey;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(mediaStorageProvider);
    final resolveKey = _resolveKey;
    final uriFuture = storage.resolveUri(resolveKey);
    return FutureBuilder<String>(
      future: uriFuture,
      builder: (context, snap) {
        final Widget body;
        if (snap.hasError ||
            (snap.connectionState == ConnectionState.done &&
                snap.data == null)) {
          // resolveUri threw, or completed without a URI → broken, never spin.
          body = _Broken(width: width, height: height);
        } else if (snap.connectionState != ConnectionState.done) {
          body = _Placeholder(width: width, height: height);
        } else {
          body = _renderFor(snap.data!, cacheKey: resolveKey);
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

  Widget _renderFor(String uri, {required String cacheKey}) {
    switch (media.type) {
      case MediaType.image:
        return _ImageView(
          uri: uri,
          fit: fit,
          cacheKey: cacheKey,
          width: width,
          height: height,
        );
      case MediaType.video:
        final poster = media.thumbnailKey != null
            ? _ImageView(
                uri: uri,
                fit: fit,
                cacheKey: cacheKey,
                width: width,
                height: height,
              )
            : null;
        return VideoThumbnail(
          duration: media.duration,
          width: width,
          height: height,
          borderRadius: BorderRadius.zero,
          child: poster,
        );
    }
  }
}

class _ImageView extends StatelessWidget {
  const _ImageView({
    required this.uri,
    required this.fit,
    required this.cacheKey,
    this.width,
    this.height,
  });

  final String uri;
  final BoxFit fit;
  final String cacheKey;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final parsed = Uri.tryParse(uri);
    final scheme = parsed?.scheme ?? '';
    if (scheme == 'http' || scheme == 'https') {
      // cacheKey = stable storage path, never the tokenized download URL.
      return CachedNetworkImage(
        imageUrl: uri,
        cacheKey: cacheKey,
        fit: fit,
        width: width,
        height: height,
        placeholder: (_, __) => _Placeholder(width: width, height: height),
        errorWidget: (_, __, ___) => _Broken(width: width, height: height),
      );
    }

    final path = scheme == 'file' ? Uri.parse(uri).toFilePath() : uri;
    return Image(
      image: FileImage(File(path)),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => _Broken(width: width, height: height),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _Placeholder(width: width, height: height);
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
