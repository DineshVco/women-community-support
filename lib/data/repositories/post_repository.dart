import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/utils/alias.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/report.dart';
import '../models/user_profile.dart';

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

  // ───────────────────────── Account & profile ─────────────────────────

  DocumentReference<Map<String, dynamic>> _me() =>
      _db.collection('users').doc(_requireUid());

  /// The signed-in person's private profile (women-only + age steps).
  Stream<UserProfile> watchProfile() {
    return _me().snapshots().map((s) => UserProfile.fromMap(s.data()));
  }

  /// Step 1: the person confirmed "I am a woman". Also records when she
  /// joined (server time, once), used for the 24 hour wait before
  /// "Open to chat".
  Future<void> confirmWoman() async {
    final existing = await _me().get();
    final hasCreatedAt = existing.data()?.containsKey('createdAt') ?? false;
    await _me().set({
      'isWoman': true,
      if (!hasCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Accounts made before sign-up times were recorded get one now (the
  /// rules allow setting it once, to the current server time only).
  Future<void> ensureCreatedAt() async {
    final existing = await _me().get();
    if (!existing.exists || existing.data()!.containsKey('createdAt')) return;
    await _me().set({
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// "Founding member": set by an admin script for the first 50 accounts
  /// (badges/{uid}); the app can only read it.
  Stream<bool> watchFoundingMember() {
    return _db
        .collection('badges')
        .doc(_requireUid())
        .snapshots()
        .map((s) => s.data()?['foundingMember'] == true)
        .handleError((Object _) {});
  }

  /// How she signs in, for "confirm it is you" before deleting the account.
  SignInMethod get signInMethod {
    final providers =
        _auth.currentUser?.providerData.map((p) => p.providerId).toSet() ??
        const <String>{};
    if (providers.contains('password')) return SignInMethod.password;
    if (providers.contains('google.com')) return SignInMethod.google;
    return SignInMethod.other;
  }

  /// Firebase only deletes an account after a recent sign-in, so she
  /// confirms it is her first. Returns false if she closed the Google window.
  Future<bool> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You need to be signed in.');

    switch (signInMethod) {
      case SignInMethod.password:
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: user.email ?? '',
            password: password ?? '',
          ),
        );
        return true;
      case SignInMethod.google:
        if (kIsWeb) {
          await user.reauthenticateWithPopup(GoogleAuthProvider());
          return true;
        }
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return false;
        final googleAuth = await googleUser.authentication;
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          ),
        );
        return true;
      case SignInMethod.other:
        return true;
    }
  }

  /// Deletes everything she wrote or saved, then her private profile.
  /// Call [reauthenticate] first and [deleteLogin] after.
  ///
  /// Not deleted (they hold no name, email or text of hers): "Me too" taps
  /// and reports she made. Once the login is gone, nothing links them to her.
  Future<void> deleteMyContent() async {
    final uid = _requireUid();
    final refs = <DocumentReference<Map<String, dynamic>>>[];

    // Her discussions (and the private "who wrote this" records).
    final authored =
        await _db.collection('authors').where('authorId', isEqualTo: uid).get();
    for (final doc in authored.docs) {
      refs
        ..add(_post(doc.id))
        ..add(doc.reference);
    }

    // Her replies, in any discussion.
    final replies =
        await _db
            .collectionGroup('commentAuthors')
            .where('authorId', isEqualTo: uid)
            .get();
    for (final doc in replies.docs) {
      final post = doc.reference.parent.parent!;
      refs
        ..add(post.collection('comments').doc(doc.id))
        ..add(doc.reference);
    }

    // Saved posts.
    final saved = await _me().collection('saved').get();
    refs.addAll(saved.docs.map((d) => d.reference));

    // Firestore batches hold up to 500 writes.
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    // Last: the private profile (women-only answer, birth year).
    await _me().delete();
  }

  /// Deletes the login itself, then signs out of Google too.
  Future<void> deleteLogin() async {
    await _auth.currentUser?.delete();
    await signOut();
  }

  /// Step 2: only the YEAR is stored, never the full date.
  Future<void> saveBirthYear(int year) {
    return _me().set({'birthYear': year}, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      // Forget the Google account choice so the next sign-in can pick again.
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  /// For someone who cannot join (not a woman, or under age) right after
  /// creating a login: delete that login so no account is left behind,
  /// then sign out. Nothing was saved in Firestore for them.
  Future<void> discardNewAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException {
      // e.g. "requires-recent-login": signing out is still the right result.
    }
    await signOut();
  }

  // ───────────────────────── Feed & posts ─────────────────────────

  /// Newest posts first. Hidden/removed posts are filtered out here.
  Stream<List<Post>> watchFeed() {
    return _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(feedLimit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
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

  /// The signed-in person's id, or null when signed out.
  String? get myUid => _auth.currentUser?.uid;

  /// The alias the signed-in person has (or will have) in this discussion.
  String myAliasFor(String postId) =>
      AliasGenerator.forThread(uid: _requireUid(), postId: postId);

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
    // merge: keeps isWoman / birthYear in the same document.
    batch.set(_db.collection('users').doc(uid), {
      'lastPostAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final snapshot =
        await _db.collection('authors').where('authorId', isEqualTo: uid).get();
    return snapshot.docs.length;
  }

  /// Her own discussions, newest first (including ones a moderator hid).
  Future<List<Post>> myPosts() async {
    final uid = _requireUid();
    final authored =
        await _db.collection('authors').where('authorId', isEqualTo: uid).get();
    return _postsByIds(authored.docs.map((d) => d.id));
  }

  Future<List<Post>> _postsByIds(Iterable<String> ids) async {
    final snapshots = await Future.wait(ids.map((id) => _post(id).get()));
    final posts =
        snapshots.where((s) => s.exists).map(Post.fromFirestore).toList();
    posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return posts;
  }

  // ───────────────────────── Saved posts ─────────────────────────

  CollectionReference<Map<String, dynamic>> _saved() =>
      _me().collection('saved');

  Stream<bool> watchSaved(String postId) {
    return _saved().doc(postId).snapshots().map((s) => s.exists);
  }

  Future<void> setSaved(String postId, {required bool saved}) {
    final ref = _saved().doc(postId);
    return saved
        ? ref.set({'createdAt': FieldValue.serverTimestamp()})
        : ref.delete();
  }

  /// Saved posts that still exist and are visible, newest first.
  Future<List<Post>> savedPosts() async {
    final saved = await _saved().get();
    final posts = await _postsByIds(saved.docs.map((d) => d.id));
    return posts.where((p) => p.isVisible).toList();
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
          (snapshot) =>
              snapshot.docs
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
      final snapshot =
          await _db.collection('reports').doc('${postId}_$uid').get();
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
    final open =
        await _db
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

enum SignInMethod { password, google, other }
