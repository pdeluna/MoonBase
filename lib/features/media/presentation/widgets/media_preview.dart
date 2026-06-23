import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/presentation/providers/media_providers.dart';

/// Full-screen viewer for a single `MediaRef`.
///
/// - Images: pinch-zoom + double-tap to reset via `InteractiveViewer`.
/// - Videos: `video_player` with play/pause + scrubber.
///
/// Scheme-agnostic: delegates URI resolution to `MediaStorage.resolveUri`,
/// then dispatches to `Image.file`/`Image.network` or `VideoPlayerController.file`
/// /`VideoPlayerController.networkUrl` based on the resolved scheme.
class MediaPreview extends ConsumerWidget {
  const MediaPreview({super.key, required this.media});

  final MediaRef media;

  /// Convenience: push this preview as a fullscreen modal route. Kept here
  /// so callers (`MediaTile.onTap`, post detail, story viewer) don't repeat
  /// the same route boilerplate.
  static Future<void> open(BuildContext context, MediaRef media) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MediaPreview(media: media),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(mediaStorageProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: storage.resolveUri(media.storageKey),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snap.hasError || snap.data == null) {
            return const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white, size: 48),
            );
          }
          final uri = snap.data!;
          switch (media.type) {
            case MediaType.image:
              return _ImagePreview(uri: uri);
            case MediaType.video:
              return _VideoPreview(uri: uri);
          }
        },
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    final parsed = Uri.tryParse(uri);
    final scheme = parsed?.scheme ?? '';
    final ImageProvider provider;
    if (scheme == 'http' || scheme == 'https') {
      provider = NetworkImage(uri);
    } else {
      final path = scheme == 'file' ? Uri.parse(uri).toFilePath() : uri;
      provider = FileImage(File(path));
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image(
          image: provider,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.uri});

  final String uri;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      final parsed = Uri.tryParse(widget.uri);
      final scheme = parsed?.scheme ?? '';
      final controller = (scheme == 'http' || scheme == 'https')
          ? VideoPlayerController.networkUrl(Uri.parse(widget.uri))
          : VideoPlayerController.file(
              File(scheme == 'file'
                  ? Uri.parse(widget.uri).toFilePath()
                  : widget.uri),
            );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return const Center(
        child: Icon(Icons.error_outline, color: Colors.white, size: 48),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(controller),
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                backgroundColor: Colors.white24,
                bufferedColor: Colors.white54,
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  setState(() {
                    controller.value.isPlaying
                        ? controller.pause()
                        : controller.play();
                  });
                },
                child: AnimatedOpacity(
                  opacity: controller.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 72,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
