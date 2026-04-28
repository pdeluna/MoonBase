import 'dart:convert';
import 'package:moonbase_skeleton/legacy/models/enums.dart';

class MediaRef {
  const MediaRef({
  required this.id,
  required this.type,
  required this.uri,
  this.width,
  this.height,
  this.duration,
  this.thumbnailUri,
  });

  factory MediaRef.fromJson(String source) => MediaRef.fromMap(json.decode(source) as Map<String, dynamic>);

  factory MediaRef.fromMap(Map<String, dynamic> map) => MediaRef(
    id: map['id'] as String,
    type: MediaType.values.byName(map['type'] as String),
    uri: map['uri'] as String,
    width: map['width'] as int?,
    height: map['height'] as int?,
    duration: map['durationMs'] != null ? Duration(milliseconds: map['durationMs'] as int) : null,
    thumbnailUri: map['thumbnailUri'] as String?,
  );

  final String id; // uuid v4 for local persistence
  final MediaType type; // image/video/link
  final String uri; // local path or remote URL
  final int? width;
  final int? height;
  final Duration? duration; // for video/audio
  final String? thumbnailUri; // optional pre-rendered thumb


  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'uri': uri,
    'width': width,
    'height': height,
    'durationMs': duration?.inMilliseconds,
    'thumbnailUri': thumbnailUri,
  };

  String toJson() => json.encode(toMap());
}