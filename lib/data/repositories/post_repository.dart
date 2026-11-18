import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/alias.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/report.dart';

/// All Firestore access lives here, so screens never talk to the database
/// directly and the privacy rules are enforced in one place.
///
/// Anonymity design:
///  * `posts/{id}` and `posts/{id}/comments/{id}` hold NO author id.
///  * `authors/{postId}` and `posts/{id}/commentAuthors/{commentId}` hold the
///    author id, and security rules let ONLY that author read them.
class PostRepository {
  PostRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const int feedLimit = 50;

  String _requireUid() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You need to be signed in.');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _post(String id) =>
      _db.collection('posts').doc(id);

  // ───────────────────────── Feed & posts ─────────────────────────

  /// Newest posts first. Hidden/removed posts are filtered out here.
  Stream<List<Post>> watchFeed() {
    return _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(feedLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Post.fromFirestore)
              .where((post) => post.isVisible)
              .toList(),
        );
  }

  Stream<Post?> watchPost(String postId) {
    return _post(postId).snapshots().map(
          (snapshot) => snapshot.exists ? Post.fromFirestore(snapshot) : null,
        );
  }

  /// Creates a post and returns the alias the author will use in that thread.
  Future<String> createPost({
    required String categoryId,
    required String title,
    required String content,
  }) async {
    final uid = _requireUid();
    final postRef = _db.collection('posts').doc();
    final alias = AliasGenerator.forThread(uid: uid, postId: postRef.id);

    final batch = _db.batch();
    batch.set(postRef, {
      'alias': alias,
      'categoryId': categoryId,
      'title': title,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'flagCount': 0,
      'meTooCount': 0,
      'commentCount': 0,
      'status': 'visible',
    });
    batch.set(_db.collection('authors').doc(postRef.id), {
      'authorId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Used by the security rules to allow one post per minute.
    batch.set(_db.collection('users').doc(uid), {
      'lastPostAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return alias;
  }

  /// True only for the author (the rules hide `authors` from everyone else).
  Future<bool> isMyPost(String postId) async {
    try {
      final snapshot = await _db.collection('authors').doc(postId).get();
      return snapshot.exists;
    } on FirebaseException {
      return false;
    }
  }

  Future<int> myPostCount() async {
    final uid = _requireUid();
    final snapshot = await _db
        .collection('authors')
        .where('authorId', isEqualTo: uid)
        .get();
    return snapshot.docs.length;
  }

  Future<void> deletePost(String postId) async {
    final batch = _db.batch();
    batch.delete(_post(postId));
    batch.delete(_db.collection('authors').doc(postId));
    await batch.commit();
  }

  // ───────────────────────── Comments ─────────────────────────

  Stream<List<Comment>> watchComments(String postId) {
    return _post(postId)
        .collection('comments')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Comment.fromFirestore(postId, doc))
              .toList(),
        );
  }

  Future<void> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    final uid = _requireUid();
    final alias = AliasGenerator.forThread(uid: uid, postId: postId);
    final commentRef = _post(postId).collection('comments').doc();

    final batch = _db.batch();
    batch.set(commentRef, {
      'alias': alias,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'parentCommentId': parentCommentId,
    });
    batch.set(_post(postId).collection('commentAuthors').doc(commentRef.id), {
      'authorId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_post(postId), {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  // ───────────────────────── "Me too" ─────────────────────────

  Stream<bool> watchMeToo(String postId) {
    final uid = _requireUid();
    return _post(postId)
        .collection('reactions')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<void> setMeToo(String postId, {required bool on}) async {
    final uid = _requireUid();
    final reactionRef = _post(postId).collection('reactions').doc(uid);

    final batch = _db.batch();
    if (on) {
      batch.set(reactionRef, {'createdAt': FieldValue.serverTimestamp()});
    } else {
      batch.delete(reactionRef);
    }
    batch.update(_post(postId), {
      'meTooCount': FieldValue.increment(on ? 1 : -1),
    });
    await batch.commit();
  }

  // ───────────────────────── Reports ─────────────────────────

  Future<bool> hasReported(String postId) async {
    final uid = _requireUid();
    try {
      final snapshot = await _db.collection('reports').doc('${postId}_$uid').get();
      return snapshot.exists;
    } on FirebaseException {
      return false;
    }
  }

  /// One report per person per post (the document id enforces it).
  /// The third report from different people hides the post automatically.
  Future<void> reportPost({required Post post, required String reason}) async {
    final uid = _requireUid();
    final newCount = post.flagCount + 1;
    final shouldHide = newCount >= 3 && post.status == 'visible';

    final batch = _db.batch();
    batch.set(_db.collection('reports').doc('${post.id}_$uid'), {
      'postId': post.id,
      'postTitle': post.title,
      'reason': reason,
      'reporterId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
    batch.update(_post(post.id), {
      'flagCount': FieldValue.increment(1),
      'status': shouldHide ? 'hidden' : post.status,
    });
    await batch.commit();
  }

  /// Reports I made, so I can see what happened to them.
  Stream<List<Report>> watchMyReports() {
    final uid = _requireUid();
    return _db
        .collection('reports')
        .where('reporterId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final reports = snapshot.docs.map(Report.fromFirestore).toList();
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports;
    });
  }

  // ───────────────────────── Moderation ─────────────────────────

  /// Moderators are added by hand in the Firebase console
  /// (document `moderators/{uid}`), never from the app.
  Future<bool> isModerator() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final snapshot = await _db.collection('moderators').doc(user.uid).get();
      return snapshot.exists;
    } on FirebaseException {
      return false;
    }
  }

  Stream<List<Report>> watchOpenReports() {
    return _db
        .collection('reports')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) {
      final reports = snapshot.docs.map(Report.fromFirestore).toList();
      reports.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return reports;
    });
  }

  /// Closes every open report on a post. Either keeps the post (and clears
  /// its flags) or removes it from the app.
  Future<void> resolvePostReports({
    required String postId,
    required bool removePost,
  }) async {
    final open = await _db
        .collection('reports')
        .where('postId', isEqualTo: postId)
        .where('status', isEqualTo: 'open')
        .get();

    final batch = _db.batch();
    for (final doc in open.docs) {
      batch.update(doc.reference, {
        'status': removePost ? 'removed' : 'dismissed',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(
      _post(postId),
      removePost
          ? {'status': 'removed'}
          : {'status': 'visible', 'flagCount': 0},
    );
    await batch.commit();
  }
}
