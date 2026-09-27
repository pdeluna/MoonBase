import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/presentation/debug_error_details.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';
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
/// The resolve [Future] is held in [State] and reused across rebuilds (chat
/// stream emissions). Creating a new future every [build] left peer images
/// stuck on the loading placeholder after relog.
///
/// Failure contract: [MediaStorage.resolveUri] throws a typed `Failure` →
/// `FutureBuilder.hasError` → [MediaBrokenTile], whose icon and tooltip vary
/// by failure (`cloud_off` for network, `lock` for permission,
/// `broken_image` otherwise) and which retries on tap by evicting the held
/// future. Network decode/download failures → [CachedNetworkImage.errorWidget]
/// → the same broken tile. There is no path that leaves the tile on the
/// loading placeholder forever after a terminal failure.
///
/// This widget is the **only** sanctioned "dumb tile" that reads a provider
/// directly; URI resolution is platform-specific infrastructure that does
/// not belong in a controller. See Phase 3 architectural constraint #3 in
/// `docs/PHASE3_DOD_ACTION_LIST.md`.
class MediaTile extends ConsumerStatefulWidget {
  const MediaTile({
    super.key,
    required this.media,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.onTap,
    this.showDebugDetails = kMoonbaseDebugUi,
  });

  final MediaRef media;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  /// Developer-only long-press details on the broken state. Defaults to the
  /// compile-time [kMoonbaseDebugUi]; tests force either branch.
  final bool showDebugDetails;

  /// Called when the user taps the tile. Typical wiring: push a
  /// `MediaPreview` route for the same `MediaRef`.
  final VoidCallback? onTap;

  @override
  ConsumerState<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends ConsumerState<MediaTile> {
  Future<String>? _uriFuture;
  String? _boundKey;
  MediaStorage? _boundStorage;

  /// Key passed to [MediaStorage.resolveUri] and used as the network cache key.
  String get _resolveKey {
    final media = widget.media;
    if (media.type == MediaType.video && media.thumbnailKey != null) {
      return media.thumbnailKey!;
    }
    return media.storageKey;
  }

  void _ensureUriFuture(MediaStorage storage) {
    final key = _resolveKey;
    if (_uriFuture != null &&
        _boundKey == key &&
        identical(_boundStorage, storage)) {
      return;
    }
    _boundKey = key;
    _boundStorage = storage;
    _uriFuture = storage.resolveUri(key);
  }

  /// Drops the held (failed) future so the next build resolves again.
  /// `FirebaseMediaStorage` evicts failed futures from its memo, so this is a
  /// real second `getDownloadURL`, not a replay of the cached error.
  void _retry() {
    if (!mounted) return;
    setState(() => _uriFuture = null);
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(mediaStorageProvider);
    _ensureUriFuture(storage);
    final resolveKey = _boundKey!;
    final uriFuture = _uriFuture!;

    return FutureBuilder<String>(
      future: uriFuture,
      builder: (context, snap) {
        final Widget body;
        if (snap.hasError ||
            (snap.connectionState == ConnectionState.done &&
                snap.data == null)) {
          // resolveUri threw, or completed without a URI → broken, never spin.
          body = MediaBrokenTile(
            error: snap.error,
            stackTrace: snap.stackTrace,
            onRetry: _retry,
            width: widget.width,
            height: widget.height,
            showDebugDetails: widget.showDebugDetails,
          );
        } else if (snap.connectionState != ConnectionState.done) {
          body = _Placeholder(width: widget.width, height: widget.height);
        } else {
          body = _renderFor(snap.data!, cacheKey: resolveKey);
        }
        return GestureDetector(
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: body,
            ),
          ),
        );
      },
    );
  }

  Widget _renderFor(String uri, {required String cacheKey}) {
    switch (widget.media.type) {
      case MediaType.image:
        return _ImageView(
          uri: uri,
          fit: widget.fit,
          cacheKey: cacheKey,
          width: widget.width,
          height: widget.height,
          onRetry: _retry,
          showDebugDetails: widget.showDebugDetails,
        );
      case MediaType.video:
        final poster = widget.media.thumbnailKey != null
            ? _ImageView(
                uri: uri,
                fit: widget.fit,
                cacheKey: cacheKey,
                width: widget.width,
                height: widget.height,
                onRetry: _retry,
                showDebugDetails: widget.showDebugDetails,
              )
            : null;
        return VideoThumbnail(
          duration: widget.media.duration,
          width: widget.width,
          height: widget.height,
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
    required this.onRetry,
    required this.showDebugDetails,
    this.width,
    this.height,
  });

  final String uri;
  final BoxFit fit;
  final String cacheKey;
  final VoidCallback onRetry;
  final bool showDebugDetails;
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
        errorWidget: (_, __, error) => MediaBrokenTile(
          error: error,
          onRetry: onRetry,
          width: width,
          height: height,
          showDebugDetails: showDebugDetails,
        ),
      );
    }

    final path = scheme == 'file' ? Uri.parse(uri).toFilePath() : uri;
    return Image(
      image: FileImage(File(path)),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, error, stackTrace) => MediaBrokenTile(
        error: error,
        stackTrace: stackTrace,
        onRetry: onRetry,
        width: width,
        height: height,
        showDebugDetails: showDebugDetails,
      ),
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

/// Broken-media state for [MediaTile].
///
/// Icon and tooltip follow the `Failure` type so the user (and the S1 device
/// gate) can tell "offline" from "not allowed" from "gone":
///
/// | Failure | Icon |
/// |---|---|
/// | [NetworkFailure], [NetworkTimeoutFailure] | `cloud_off` |
/// | [PermissionDeniedFailure], [UnauthenticatedFailure] | `lock` |
/// | [MediaNotFoundFailure], anything else | `broken_image` |
///
/// Tap → [onRetry] (the tile evicts its held future and resolves again).
/// In debug builds the tile is also long-pressable for the raw error
/// ([DebugErrorDetails]); never in profile/release.
class MediaBrokenTile extends StatelessWidget {
  const MediaBrokenTile({
    super.key,
    required this.error,
    required this.onRetry,
    this.stackTrace,
    this.width,
    this.height,
    this.showDebugDetails = kMoonbaseDebugUi,
  });

  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;
  final double? width;
  final double? height;
  final bool showDebugDetails;

  /// Visible for testing.
  static IconData iconFor(Object? error) {
    if (error is NetworkFailure || error is NetworkTimeoutFailure) {
      return Icons.cloud_off_outlined;
    }
    if (error is PermissionDeniedFailure || error is UnauthenticatedFailure) {
      return Icons.lock_outline;
    }
    return Icons.broken_image_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRetry,
      child: ColoredBox(
        color: cs.errorContainer,
        child: SizedBox(
          width: width,
          height: height,
          child: Center(
            child: Icon(iconFor(error), color: cs.onErrorContainer),
          ),
        ),
      ),
    );
    if (showDebugDetails) {
      // Debug builds: long-press → raw details (which include the user copy).
      // A second long-press Tooltip here would win the gesture arena.
      return DebugErrorDetails(
        error: error,
        stackTrace: stackTrace,
        enabled: true,
        child: tile,
      );
    }
    return Tooltip(
      message: '${userMessage(error)} Tap to retry.',
      child: tile,
    );
  }
}
