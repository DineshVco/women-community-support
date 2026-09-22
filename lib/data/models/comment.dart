import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String authorId;
  final bool isAnonymous;
  final String displayName;
  final String content;
  final DateTime timestamp;
  final String? parentCommentId;

  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.isAnonymous,
    required this.displayName,
    required this.content,
    required this.timestamp,
    this.parentCommentId,
  });

  factory Comment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    final timestamp = data['timestamp'];

    return Comment(
      id: snapshot.id,
      postId: data['postId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      isAnonymous: data['isAnonymous'] as bool? ?? true,
      displayName: data['displayName'] as String? ?? 'Anonymous',
      content: data['content'] as String? ?? '',
      timestamp: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.now(),
      parentCommentId: data['parentCommentId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'authorId': authorId,
      'isAnonymous': isAnonymous,
      'displayName': displayName,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'parentCommentId': parentCommentId,
    };
  }
}