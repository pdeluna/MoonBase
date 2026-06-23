import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';

import 'package:moonbase_skeleton/core/app_navigator.dart';
import 'package:moonbase_skeleton/core/ids.dart';

/// Generates JPEG poster bytes for a local video file (first frame).
///
/// Default implementation uses [VideoPlayerController] + an offscreen
/// [OverlayEntry] (via [rootNavigatorKey]) and [RepaintBoundary.toImage].
/// Returns `null` on any failure — callers treat poster generation as
/// best-effort (POL-4).
typedef VideoPosterGenerator = Future<Uint8List?> Function(String filePath);

Future<Uint8List?> captureVideoPosterWithPlayer(String filePath) async {
  final overlay = rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return null;

  final controller = VideoPlayerController.file(File(filePath));
  OverlayEntry? entry;
  var entryRemoved = false;

  void removeEntry() {
    final e = entry;
    if (!entryRemoved && e != null) {
      e.remove();
      entryRemoved = true;
    }
  }

  try {
    await controller.initialize();
    if (!controller.value.isInitialized) return null;

    await controller.setVolume(0);
    await controller.seekTo(Duration.zero);
    await controller.pause();

    final boundaryKey = GlobalKey();
    final completer = Completer<Uint8List?>();

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,
        top: -10000,
        child: SizedBox(
          width: 480,
          height: 270,
          child: RepaintBoundary(
            key: boundaryKey,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
      ),
    );
    entry = overlayEntry;
    overlay.insert(overlayEntry);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Future<void>.delayed(const Duration(milliseconds: 250));

        final boundary = boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) {
          completer.complete(null);
          return;
        }

        final image = await boundary.toImage(pixelRatio: 1.0);
        final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();

        if (pngData == null) {
          completer.complete(null);
          return;
        }

        final jpeg = await FlutterImageCompress.compressWithList(
          pngData.buffer.asUint8List(),
          quality: 80,
          minWidth: 512,
          minHeight: 512,
        );
        completer.complete(Uint8List.fromList(jpeg));
      } catch (_) {
        completer.complete(null);
      }
    });

    return await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  } finally {
    removeEntry();
    await controller.dispose();
  }
}

/// Storage key for a video's optional poster JPEG sibling file.
String videoPosterStorageKey(BaseId baseId, MediaId mediaId) =>
    '${baseId.value}/${mediaId.value}.thumb.jpg';
