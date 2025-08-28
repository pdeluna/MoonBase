import 'dart:convert';
import 'enums.dart';

class MediaRef {
  final String id; // uuid v4 for local persistence
  final MediaType type; // image/video/link
  final String uri; // local path or remote URL
  final int? width;
  final int? height;
  final Duration? duration; // for video/audio
  final String? thumbnailUri; // optional pre-rendered thumb


  const MediaRef({
  required this.id,
  required this.type,
  required this.uri,
  this.width,
  this.height,
  this.duration,
  this.thumbnailUri,
  });


  Map<String, dynamic> toMap() => {
  'id': id,
  'type': type.name,
  'uri': uri,
  'width': width,
  'height': height,
  'durationMs': duration?.inMilliseconds,
  'thumbnailUri': thumbnailUri,
  };


  factory MediaRef.fromMap(Map<String, dynamic> map) => MediaRef(
  id: map['id'] as String,
  type: MediaType.values.byName(map['type'] as String),
  uri: map['uri'] as String,
  width: map['width'] as int?,
  height: map['height'] as int?,
  duration: map['durationMs'] != null ? Duration(milliseconds: map['durationMs'] as int) : null,
  thumbnailUri: map['thumbnailUri'] as String?,
  );


  String toJson() => json.encode(toMap());
  factory MediaRef.fromJson(String source) => MediaRef.fromMap(json.decode(source));
}