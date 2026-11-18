import 'package:cloud_firestore/cloud_firestore.dart';

/// Someone reported a post. `status` is 'open', 'dismissed' or 'removed'.
class Report {
  const Report({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String postTitle;
  final String reason;
  final String status;
  final DateTime createdAt;

  bool get isOpen => status == 'open';

  factory Report.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final createdAt = data['createdAt'];

    return Report(
      id: snapshot.id,
      postId: data['postId'] as String? ?? '',
      postTitle: data['postTitle'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
      createdAt:
          createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
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
