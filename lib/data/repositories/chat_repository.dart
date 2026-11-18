import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_profile.dart';

/// Looma Connect data. Phase A: her own chat profile.
///
/// Chat profiles live at `chatProfiles/{chatId}`, where chatId is a one-way
/// hash of the uid, never the uid itself. Post aliases are computed from the
/// uid, so showing uids to other members would let them find her posts.
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// sha256('looma-chat:' + uid) in lowercase hex.
  /// firestore.rules (`chatIdOf`) computes exactly the same value.
  static String chatIdFor(String uid) =>
      sha256.convert(utf8.encode('looma-chat:$uid')).toString();

  String _requireUid() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You need to be signed in.');
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _mine() =>
      _db.collection('chatProfiles').doc(chatIdFor(_requireUid()));

  /// Her own chat profile, or null before she sets one up.
  Stream<ChatProfile?> watchMine() {
    return _mine().snapshots().map(
      (s) => s.exists ? ChatProfile.fromMap(s.data()!) : null,
    );
  }

  /// Creates or updates her chat profile. [open] is left as it is.
  Future<void> save({
    required String alias,
    required String avatarId,
    required String bio,
    required List<String> interests,
    required List<String> lookingFor,
  }) async {
    final ref = _mine();
    final fields = {
      'alias': alias.trim(),
      'avatarId': avatarId,
      'bio': bio.trim(),
      'interests': interests,
      'lookingFor': lookingFor,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final existing = await ref.get();
    if (existing.exists) {
      // update(): createdAt and open stay as they are.
      await ref.update(fields);
    } else {
      await ref.set({
        ...fields,
        'open': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// "Open to chat". Turning it on needs a 24 hour old account (rules).
  Future<void> setOpen(bool open) {
    return _mine().update({
      'open': open,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Part of "Delete my account and data".
  Future<void> deleteMine() => _mine().delete();
}
