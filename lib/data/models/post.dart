import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final bool isAnonymous;
  final String displayName;
  final String categoryId;
  final String title;
  final String content;
  final DateTime timestamp;
  final int flagCount;

  const Post({
    required this.id,
    required this.authorId,
    required this.isAnonymous,
    required this.displayName,
    required this.categoryId,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.flagCount,
  });

  factory Post.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    final timestamp = data['timestamp'];

    return Post(
      id: snapshot.id,
      authorId: data['authorId'] as String? ?? '',
      isAnonymous: data['isAnonymous'] as bool? ?? true,
      displayName: data['displayName'] as String? ?? 'Anonymous',
      categoryId: data['categoryId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      timestamp: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.now(),
      flagCount: data['flagCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'isAnonymous': isAnonymous,
      'displayName': displayName,
      'categoryId': categoryId,
      'title': title,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'flagCount': flagCount,
    };
  }
}