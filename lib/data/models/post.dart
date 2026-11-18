import 'package:cloud_firestore/cloud_firestore.dart';

/// A discussion post.
///
/// There is deliberately NO author id here. Who wrote a post is stored in a
/// separate, locked collection (`authors/{postId}`) that only the author can
/// read. See firestore.rules.
class Post {
  const Post({
    required this.id,
    required this.alias,
    required this.categoryId,
    required this.title,
    required this.content,
    required this.timestamp,
    this.flagCount = 0,
    this.meTooCount = 0,
    this.commentCount = 0,
    this.status = 'visible',
  });

  final String id;

  /// Random name used only inside this discussion, e.g. "Quiet Fox".
  final String alias;
  final String categoryId;
  final String title;
  final String content;
  final DateTime timestamp;
  final int flagCount;
  final int meTooCount;
  final int commentCount;

  /// 'visible', 'hidden' (auto-hidden after reports) or 'removed'.
  final String status;

  bool get isVisible => status == 'visible';

  factory Post.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return Post.fromMap(snapshot.id, snapshot.data() ?? <String, dynamic>{});
  }

  factory Post.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['timestamp'];

    return Post(
      id: id,
      alias:
          (data['alias'] as String?) ??
          (data['displayName'] as String?) ??
          'Anonymous',
      categoryId: data['categoryId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      // A just-written post has no server time yet; show it as "now".
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      flagCount: (data['flagCount'] as num?)?.toInt() ?? 0,
      meTooCount: (data['meTooCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'visible',
    );
  }
}
