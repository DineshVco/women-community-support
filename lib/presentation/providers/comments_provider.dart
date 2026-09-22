import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/models/comment.dart';

class CommentsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, List<Comment>> _commentsByPost = {};
  final Map<String, bool> _loadingByPost = {};
  final Map<String, String?> _errorByPost = {};

  List<Comment> commentsForPost(String postId) {
    return _commentsByPost[postId] ?? [];
  }

  bool isLoading(String postId) {
    return _loadingByPost[postId] ?? false;
  }

  String? errorForPost(String postId) {
    return _errorByPost[postId];
  }

  Future<void> loadComments(String postId) async {
    _loadingByPost[postId] = true;
    _errorByPost[postId] = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp')
          .get();

      _commentsByPost[postId] = snapshot.docs
          .map(Comment.fromFirestore)
          .toList();
    } catch (error) {
      _errorByPost[postId] = 'Unable to load comments.';
      debugPrint('Load comments error: $error');
    } finally {
      _loadingByPost[postId] = false;
      notifyListeners();
    }
  }

  Future<void> addComment({
    required String postId,
    required String authorId,
    required bool isAnonymous,
    required String displayName,
    required String content,
    String? parentCommentId,
  }) async {
    final trimmedContent = content.trim();

    if (trimmedContent.isEmpty) return;

    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc();

    final comment = Comment(
      id: commentRef.id,
      postId: postId,
      authorId: authorId,
      isAnonymous: isAnonymous,
      displayName: displayName,
      content: trimmedContent,
      timestamp: DateTime.now(),
      parentCommentId: parentCommentId,
    );

    await commentRef.set(comment.toFirestore());

    _commentsByPost.putIfAbsent(postId, () => []);
    _commentsByPost[postId]!.add(comment);

    notifyListeners();
  }
}