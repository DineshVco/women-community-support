import 'package:cloud_firestore/cloud_firestore.dart';

/// A reply inside a discussion. Like posts, it carries no author id.
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.alias,
    required this.content,
    required this.timestamp,
    this.parentCommentId,
    this.status = 'visible',
    this.flagCount = 0,
  });

  final String id;
  final String postId;
  final String alias;
  final String content;
  final DateTime timestamp;

  /// Set when this is a reply to another comment (one level deep).
  final String? parentCommentId;

  /// 'visible', 'hidden' (3 reports) or 'removed' (by a moderator).
  final String status;
  final int flagCount;

  bool get isVisible => status == 'visible';

  factory Comment.fromFirestore(
    String postId,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return Comment.fromMap(
      snapshot.id,
      postId,
      snapshot.data() ?? <String, dynamic>{},
    );
  }

  factory Comment.fromMap(String id, String postId, Map<String, dynamic> data) {
    final timestamp = data['timestamp'];

    return Comment(
      id: id,
      postId: postId,
      alias:
          (data['alias'] as String?) ??
          (data['displayName'] as String?) ??
          'Anonymous',
      content: data['content'] as String? ?? '',
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      parentCommentId: data['parentCommentId'] as String?,
      status: data['status'] as String? ?? 'visible',
      flagCount: (data['flagCount'] as num?)?.toInt() ?? 0,
    );
  }
}
