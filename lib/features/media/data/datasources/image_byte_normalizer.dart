import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:moonbase_skeleton/core/failure.dart';

/// Returns [bytes] when already under [maxBytes]. Otherwise lossy-compresses
/// (JPEG, max edge 2048px) until the cap is met or throws [MediaTooLargeFailure].
///
/// Used by [ImagePickerMediaPicker] so full-resolution gallery picks from modern
/// phone cameras can attach without raising the stored byte cap arbitrarily.
Future<Uint8List> normalizeImageBytes({
  required XFile source,
  required Uint8List bytes,
  required int maxBytes,
}) async {
  if (bytes.length <= maxBytes) return bytes;

  for (final quality in [85, 70, 55, 40, 25]) {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      quality: quality,
      minWidth: 2048,
      minHeight: 2048,
    );
    if (compressed.length <= maxBytes) {
      return Uint8List.fromList(compressed);
    }
  }

  final fromFile = await FlutterImageCompress.compressWithFile(
    source.path,
    quality: 25,
    minWidth: 1920,
    minHeight: 1920,
  );
  if (fromFile != null && fromFile.length <= maxBytes) {
    return Uint8List.fromList(fromFile);
  }

  throw const MediaTooLargeFailure();
}

/// True when [normalized] is smaller than the raw pick bytes (compression ran).
bool imageWasCompressed(int rawLength, Uint8List normalized) =>
    normalized.length < rawLength;
