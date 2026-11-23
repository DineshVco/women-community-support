import 'package:cloud_firestore/cloud_firestore.dart';

/// Someone reported a post, or a reply in it ([commentId] set). `status`
/// is 'open', 'dismissed' or 'removed'.
class Report {
  const Report({
    required this.id,
    required this.postId,
    this.commentId,
    required this.postTitle,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String postId;

  /// The reported reply, for reply reports; null for post reports.
  final String? commentId;

  bool get isReply => commentId != null;
  final String postTitle;
  final String reason;
  final String status;
  final DateTime createdAt;

  bool get isOpen => status == 'open';

  factory Report.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => Report.fromMap(snapshot.id, snapshot.data() ?? <String, dynamic>{});

  factory Report.fromMap(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];

    return Report(
      id: id,
      postId: data['postId'] as String? ?? '',
      commentId: data['commentId'] as String?,
      postTitle: data['postTitle'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }
}

/// The only reasons a report may use. firestore.rules checks the same list.
class ReportReasons {
  ReportReasons._();

  static const List<String> all = [
    'Harassment or hate',
    'Unsafe or harmful advice',
    'Spam or advertising',
    'Private information',
    'Something else',
  ];
}
