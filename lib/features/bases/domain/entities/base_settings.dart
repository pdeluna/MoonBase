import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/core/ids.dart';

/// MVP shape per Phase 3 DoD Section 2.1.1. Deliberately a narrower surface
/// than the legacy BaseSettings; the legacy class can be retired in Phase 4.
@immutable
class BaseSettings {
  const BaseSettings({
    required this.baseId,
    required this.updatedAt,
    required this.updatedByUserId,
    this.storiesEnabled = true,
    this.storiesArchiveEnabled = true,
    this.storyTtl = const Duration(hours: 24),
    this.maxMediaPerStory = 1,
  });

  final BaseId baseId;
  final bool storiesEnabled;
  final bool storiesArchiveEnabled;
  final Duration storyTtl;
  final int maxMediaPerStory;
  final DateTime updatedAt;
  final UserId updatedByUserId;

  BaseSettings copyWith({
    BaseId? baseId,
    bool? storiesEnabled,
    bool? storiesArchiveEnabled,
    Duration? storyTtl,
    int? maxMediaPerStory,
    DateTime? updatedAt,
    UserId? updatedByUserId,
  }) {
    return BaseSettings(
      baseId: baseId ?? this.baseId,
      storiesEnabled: storiesEnabled ?? this.storiesEnabled,
      storiesArchiveEnabled: storiesArchiveEnabled ?? this.storiesArchiveEnabled,
      storyTtl: storyTtl ?? this.storyTtl,
      maxMediaPerStory: maxMediaPerStory ?? this.maxMediaPerStory,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUserId: updatedByUserId ?? this.updatedByUserId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BaseSettings &&
        other.baseId == baseId &&
        other.storiesEnabled == storiesEnabled &&
        other.storiesArchiveEnabled == storiesArchiveEnabled &&
        other.storyTtl == storyTtl &&
        other.maxMediaPerStory == maxMediaPerStory &&
        other.updatedAt == updatedAt &&
        other.updatedByUserId == updatedByUserId;
  }

  @override
  int get hashCode => Object.hash(
        baseId,
        storiesEnabled,
        storiesArchiveEnabled,
        storyTtl,
        maxMediaPerStory,
        updatedAt,
        updatedByUserId,
      );
}
