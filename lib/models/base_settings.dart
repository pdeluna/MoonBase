import 'dart:convert';

class BaseSettings {
  const BaseSettings({
    required this.baseId,
    this.allowMemberInvites = false,
    this.allowMemberPosts = true,
    this.allowMemberStories = true,
    this.allowMemberChat = true,
    this.requireApprovalForPosts = false,
    this.requireApprovalForStories = false,
    this.maxMediaPerPost = 10,
    this.maxMediaPerStory = 1,
    this.storyTtl = const Duration(hours: 24),
    this.enableLiveStreaming = true,
    this.enableReactions = true,
    this.allowedMediaTypes = const ['image', 'video', 'link'],
    required this.updatedAt,
    required this.updatedByUserId,
  });

  factory BaseSettings.fromJson(String source) => BaseSettings.fromMap(json.decode(source) as Map<String, dynamic>);

  factory BaseSettings.fromMap(Map<String, dynamic> map) => BaseSettings(
    baseId: map['baseId'] as String,
    allowMemberInvites: (map['allowMemberInvites'] ?? false) as bool,
    allowMemberPosts: (map['allowMemberPosts'] ?? true) as bool,
    allowMemberStories: (map['allowMemberStories'] ?? true) as bool,
    allowMemberChat: (map['allowMemberChat'] ?? true) as bool,
    requireApprovalForPosts: (map['requireApprovalForPosts'] ?? false) as bool,
    requireApprovalForStories: (map['requireApprovalForStories'] ?? false) as bool,
    maxMediaPerPost: (map['maxMediaPerPost'] ?? 10) as int,
    maxMediaPerStory: (map['maxMediaPerStory'] ?? 1) as int,
    storyTtl: Duration(milliseconds: (map['storyTtlMs'] ?? 86400000) as int),
    enableLiveStreaming: (map['enableLiveStreaming'] ?? true) as bool,
    enableReactions: (map['enableReactions'] ?? true) as bool,
    allowedMediaTypes: List<String>.from((map['allowedMediaTypes'] ?? const ['image', 'video', 'link']) as Iterable<dynamic>),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
    updatedByUserId: map['updatedByUserId'] as String,
  );

  final String baseId;
  final bool allowMemberInvites; // can members invite others
  final bool allowMemberPosts; // can members create posts
  final bool allowMemberStories; // can members create stories
  final bool allowMemberChat; // can members send chat messages
  final bool requireApprovalForPosts; // posts need admin approval
  final bool requireApprovalForStories; // stories need admin approval
  final int maxMediaPerPost; // max media items per post
  final int maxMediaPerStory; // max media items per story (usually 1)
  final Duration storyTtl; // default story time-to-live
  final bool enableLiveStreaming; // allow live sessions
  final bool enableReactions; // allow reactions on posts/messages
  final List<String> allowedMediaTypes; // allowed media types
  final DateTime updatedAt;
  final String updatedByUserId;


  BaseSettings copyWith({
    String? baseId,
    bool? allowMemberInvites,
    bool? allowMemberPosts,
    bool? allowMemberStories,
    bool? allowMemberChat,
    bool? requireApprovalForPosts,
    bool? requireApprovalForStories,
    int? maxMediaPerPost,
    int? maxMediaPerStory,
    Duration? storyTtl,
    bool? enableLiveStreaming,
    bool? enableReactions,
    List<String>? allowedMediaTypes,
    DateTime? updatedAt,
    String? updatedByUserId,
  }) {
    return BaseSettings(
      baseId: baseId ?? this.baseId,
      allowMemberInvites: allowMemberInvites ?? this.allowMemberInvites,
      allowMemberPosts: allowMemberPosts ?? this.allowMemberPosts,
      allowMemberStories: allowMemberStories ?? this.allowMemberStories,
      allowMemberChat: allowMemberChat ?? this.allowMemberChat,
      requireApprovalForPosts: requireApprovalForPosts ?? this.requireApprovalForPosts,
      requireApprovalForStories: requireApprovalForStories ?? this.requireApprovalForStories,
      maxMediaPerPost: maxMediaPerPost ?? this.maxMediaPerPost,
      maxMediaPerStory: maxMediaPerStory ?? this.maxMediaPerStory,
      storyTtl: storyTtl ?? this.storyTtl,
      enableLiveStreaming: enableLiveStreaming ?? this.enableLiveStreaming,
      enableReactions: enableReactions ?? this.enableReactions,
      allowedMediaTypes: allowedMediaTypes ?? this.allowedMediaTypes,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUserId: updatedByUserId ?? this.updatedByUserId,
    );
  }

  Map<String, dynamic> toMap() => {
    'baseId': baseId,
    'allowMemberInvites': allowMemberInvites,
    'allowMemberPosts': allowMemberPosts,
    'allowMemberStories': allowMemberStories,
    'allowMemberChat': allowMemberChat,
    'requireApprovalForPosts': requireApprovalForPosts,
    'requireApprovalForStories': requireApprovalForStories,
    'maxMediaPerPost': maxMediaPerPost,
    'maxMediaPerStory': maxMediaPerStory,
    'storyTtlMs': storyTtl.inMilliseconds,
    'enableLiveStreaming': enableLiveStreaming,
    'enableReactions': enableReactions,
    'allowedMediaTypes': allowedMediaTypes,
    'updatedAt': updatedAt.toIso8601String(),
    'updatedByUserId': updatedByUserId,
  };

  String toJson() => json.encode(toMap());

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is BaseSettings &&
    runtimeType == other.runtimeType &&
    baseId == other.baseId;

  @override
  int get hashCode => baseId.hashCode;
}
