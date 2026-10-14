import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../data/anime_catalog.dart';

/// Everything below is stored under `users/{uid}` where `uid` is the account
/// that is currently signed in, so every account has its own separate data:
///
///   users/{uid}                 profile (name, bio, avatar, recent searches)
///   users/{uid}/favorites/{id}  favorited anime (doc id = anime id)
///
/// Posts are public and shared by everyone, so they live in a top-level
/// collection (readable by all signed-in users, real time):
///
///   posts/{id}                  caption, uid, author info, imageBase64, ...
///
/// Images are shrunk on the device and stored inside the post document as
/// base64 text, so Firebase Storage (paid plan) is not needed.
class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.email,
    required this.bio,
    required this.avatar,
    required this.photoUrl,
    this.photoBase64,
    this.bannerBase64,
    required this.recentSearches,
  });

  final String displayName;
  final String email;
  final String bio;

  /// Asset path chosen by the user, or null.
  final String? avatar;

  /// Photo from the sign-in provider (Google/Facebook/GitHub), or null.
  final String? photoUrl;

  /// Photo the user uploaded from their device (small, base64), or null.
  final String? photoBase64;
  /// Compressed profile cover image shared through the public profile document.
  final String? bannerBase64;
  final List<String> recentSearches;

  factory UserProfile.fromData(Map<String, dynamic>? data, User user) {
    final saved = (data?['displayName'] as String?)?.trim() ?? '';
    final authName = user.displayName?.trim() ?? '';
    final emailName = (user.email ?? '').split('@').first;

    return UserProfile(
      displayName: saved.isNotEmpty
          ? saved
          : authName.isNotEmpty
              ? authName
              : emailName.isNotEmpty
                  ? emailName
                  : 'Anime Fan',
      email: user.email ?? '',
      bio: (data?['bio'] as String?) ?? '',
      avatar: data?['avatar'] as String?,
      photoUrl: user.photoURL,
      photoBase64: data?['photoBase64'] as String?,
      bannerBase64: data?['bannerBase64'] as String?,
      recentSearches:
          List<String>.from((data?['recentSearches'] as List?) ?? const []),
    );
  }
}

class UserPost {
  const UserPost({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.authorAvatar,
    required this.authorPhotoUrl,
    required this.authorPhotoBase64,
    required this.caption,
    required this.animeId,
    this.animeTitle,
    this.animeImageUrl,
    required this.imageBase64,
    required this.createdAt,
  });

  final String id;

  /// Account that wrote the post.
  final String uid;
  final String authorName;
  final String? authorAvatar;
  final String? authorPhotoUrl;
  final String? authorPhotoBase64;
  final String caption;
  final String? animeId;
  final String? animeTitle;
  final String? animeImageUrl;

  /// Photo from the device, shrunk and encoded as base64 text.
  final String? imageBase64;
  final DateTime createdAt;

  bool get isMine => FirebaseAuth.instance.currentUser?.uid == uid;

  /// Lets the shared [UserAvatar] widget draw the author.
  UserProfile get author => UserProfile(
        displayName: authorName,
        email: '',
        bio: '',
        avatar: authorAvatar,
        photoUrl: authorPhotoUrl,
        photoBase64: authorPhotoBase64,
        recentSearches: const [],
      );

  factory UserPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserPost(
      id: doc.id,
      uid: (data['uid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? 'Anime Fan',
      authorAvatar: data['authorAvatar'] as String?,
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      authorPhotoBase64: data['authorPhotoBase64'] as String?,
      caption: (data['caption'] as String?) ?? '',
      animeId: data['animeId'] as String?,
      animeTitle: data['animeTitle'] as String?,
      animeImageUrl: data['animeImageUrl'] as String?,
      imageBase64: data['imageBase64'] as String?,
      // Null while the server timestamp is still being written.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FriendRequest {
  const FriendRequest({required this.uid, required this.name});
  final String uid;
  final String name;
}

class UserDataService {
  UserDataService._();
  static final UserDataService instance = UserDataService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User get _user {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    return user;
  }

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(_user.uid);
  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');
  CollectionReference<Map<String, dynamic>> get _favorites =>
      _doc.collection('favorites');

  // ------------------------------------------------------------- community

  String get currentUid => _user.uid;

  Future<String?> addFriendByUid(String uid) async {
    final target = uid.trim();
    if (target.isEmpty || target == _user.uid) return null;
    final found = await _db.collection('publicUsers').doc(target).get();
    if (!found.exists) return null;
    final existing = await _doc.collection('friends').doc(target).get();
    if (existing.exists) return 'already';
    final name = (found.data()?['displayName'] as String?)?.trim();
    await _db.collection('users').doc(target).collection('friendRequests')
        .doc(_user.uid).set({'uid': _user.uid, 'name': UserProfile.fromData(null, _user).displayName, 'createdAt': FieldValue.serverTimestamp()});
    return 'sent:${name?.isNotEmpty == true ? name : 'Anime Fan'}';
  }

  Stream<List<FriendRequest>> friendRequestsStream() => _doc.collection('friendRequests')
      .snapshots().map((s) => s.docs.map((d) => FriendRequest(uid: d.id, name: (d.data()['name'] as String?) ?? 'Anime Fan')).toList());

  Future<void> acceptFriend(FriendRequest request) async {
    final me = UserProfile.fromData((await _doc.get()).data(), _user).displayName;
    final otherRef = _db.collection('users').doc(request.uid);
    final batch = _db.batch();
    batch.set(_doc.collection('friends').doc(request.uid), {'uid': request.uid, 'name': request.name, 'createdAt': FieldValue.serverTimestamp()});
    batch.set(otherRef.collection('friends').doc(_user.uid), {'uid': _user.uid, 'name': me, 'createdAt': FieldValue.serverTimestamp()});
    batch.delete(_doc.collection('friendRequests').doc(request.uid));
    await batch.commit();
    // Store a shared conversation key on both friend entries for deterministic lookup.
    final ids = [_user.uid, request.uid]..sort();
    final chatId = ids.join('_');
    await _doc.collection('friends').doc(request.uid).set({'chatId': chatId}, SetOptions(merge: true));
    await otherRef.collection('friends').doc(_user.uid).set({'chatId': chatId}, SetOptions(merge: true));
    await _db.collection('chats').doc(chatId).set({'members': ids, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> rejectFriend(FriendRequest request) => _doc.collection('friendRequests').doc(request.uid).delete();

  Stream<List<Map<String, dynamic>>> friendsStream() => _doc.collection('friends').snapshots().map((s) => s.docs.map((d) => {...d.data(), 'uid': d.id}).toList());

  Stream<List<Map<String, dynamic>>> myGroupChatsStream() => _doc
      .collection('chats')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'chatId': d.id}).toList());

  Future<List<Map<String, dynamic>>> friendsOnce() async {
    final snapshot = await _doc.collection('friends').get();
    return snapshot.docs.map((d) => {...d.data(), 'uid': d.id}).toList();
  }

  Future<void> removeFriend(String friendUid) async {
    if (friendUid == _user.uid) return;
    final batch = _db.batch();
    batch.delete(_doc.collection('friends').doc(friendUid));
    batch.delete(_db.collection('users').doc(friendUid).collection('friends').doc(_user.uid));
    await batch.commit();
  }

  Future<void> createGroupChat({
    required String name,
    required List<Map<String, String>> friends,
  }) async {
    final title = name.trim();
    if (title.isEmpty || title.length > 60) {
      throw const FormatException('group-name-invalid');
    }
    if (friends.isEmpty || friends.length > 30) {
      throw const FormatException('group-members-invalid');
    }
    final profile = UserProfile.fromData((await _doc.get()).data(), _user);
    final memberNames = <String, String>{_user.uid: profile.displayName};
    for (final friend in friends) {
      final uid = friend['uid'];
      if (uid == null || uid == _user.uid) continue;
      // Only users already in the owner's accepted-friends list can be added.
      final accepted = await _doc.collection('friends').doc(uid).get();
      if (accepted.exists) memberNames[uid] = friend['name'] ?? 'Friend';
    }
    if (memberNames.length < 2) throw const FormatException('group-needs-friends');
    final chatRef = _db.collection('chats').doc();
    final members = memberNames.keys.toList();
    await chatRef.set({
      'name': title,
      'isGroup': true,
      'createdBy': _user.uid,
      'members': members,
      'memberNames': memberNames,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final uid in members) {
      await _db.collection('users').doc(uid).collection('chats').doc(chatRef.id).set({
        'chatId': chatRef.id,
        'name': title,
        'isGroup': true,
        'members': members,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<List<String>> addGroupMembers(String chatId, List<String> friendUids) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final chatSnap = await chatRef.get();
    final data = chatSnap.data();
    if (!chatSnap.exists || data == null || data['isGroup'] != true) {
      throw StateError('Group chat not found.');
    }
    final members = List<String>.from(data['members'] as List? ?? const []);
    if (!members.contains(_user.uid)) throw StateError('You are not a member of this group.');
    final names = Map<String, dynamic>.from(data['memberNames'] as Map? ?? const {});
    final added = <String>[];
    for (final uid in friendUids.toSet()) {
      if (uid == _user.uid || members.contains(uid)) continue;
      final accepted = await _doc.collection('friends').doc(uid).get();
      if (!accepted.exists) continue;
      if (members.length >= 32) throw const FormatException('group-too-large');
      members.add(uid);
      names[uid] = (accepted.data()?['name'] as String?) ?? 'Friend';
      added.add(uid);
    }
    if (added.isEmpty) return members;
    await chatRef.update({'members': members, 'memberNames': names, 'updatedAt': FieldValue.serverTimestamp()});
    for (final uid in members) {
      await _db.collection('users').doc(uid).collection('chats').doc(chatId).set({
        'chatId': chatId,
        'name': (data['name'] as String?) ?? 'Group chat',
        'isGroup': true,
        'members': members,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return members;
  }

  Stream<List<Map<String, dynamic>>> chatMessagesStream(String chatId) =>
      _db.collection('chats').doc(chatId).collection('messages').orderBy('createdAt').snapshots().map((s) => s.docs.map((d) {
        final data = d.data();
        return {...data, 'id': d.id, 'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()};
      }).toList());

  Future<void> sendMessage(
    String chatId,
    String text, {
    String? attachmentBase64,
    String? attachmentName,
    String? attachmentType,
  }) async {
    final message = text.trim();
    if (message.isEmpty && attachmentBase64 == null) return;
    if ((attachmentBase64?.length ?? 0) > 800000) {
      throw const FormatException('attachment-too-large');
    }
    final ref = _db.collection('chats').doc(chatId);
    final preview = message.isNotEmpty ? message : 'Sent ${attachmentName ?? 'an attachment'}';
    await ref.collection('messages').add({
      'uid': _user.uid,
      'text': message,
      'attachmentBase64': attachmentBase64,
      'attachmentName': attachmentName,
      'attachmentType': attachmentType,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await ref.set({'updatedAt': FieldValue.serverTimestamp(), 'lastMessage': preview}, SetOptions(merge: true));
  }

  Future<void> addComment(UserPost post, String text) async {
    final comment = text.trim();
    if (comment.isEmpty) return;
    final profile = UserProfile.fromData((await _doc.get()).data(), _user);
    await _posts.doc(post.id).collection('comments').add({
      'uid': _user.uid,
      'name': profile.displayName,
      'avatar': profile.avatar,
      'photoUrl': profile.photoUrl,
      'photoBase64': profile.photoBase64,
      'text': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (post.uid != _user.uid) {
      await _db.collection('users').doc(post.uid).collection('notifications').add({'type': 'comment', 'postId': post.id, 'fromUid': _user.uid, 'fromName': profile.displayName, 'text': comment, 'createdAt': FieldValue.serverTimestamp(), 'read': false});
    }
  }

  Stream<List<Map<String, dynamic>>> commentsStream(String postId) =>
      _posts.doc(postId).collection('comments').orderBy('createdAt').snapshots().map((s) => s.docs.map((d) {
        final data = d.data();
        return {...data, 'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()};
      }).toList());

  Stream<int> postLikeCountStream(String postId) => _posts
      .doc(postId).collection('likes').snapshots().map((snap) => snap.size);

  Stream<bool> postLikedStream(String postId) => _posts
      .doc(postId).collection('likes').doc(_user.uid).snapshots().map((snap) => snap.exists);

  Future<void> setPostLiked(String postId, bool liked) async {
    final ref = _posts.doc(postId).collection('likes').doc(_user.uid);
    if (liked) {
      await ref.set({'uid': _user.uid, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
  }

  Stream<List<Map<String, dynamic>>> notificationsStream() => _doc.collection('notifications').orderBy('createdAt', descending: true).limit(50).snapshots().map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  Future<void> markNotificationRead(String id) => _doc.collection('notifications').doc(id).set({'read': true}, SetOptions(merge: true));

  // ---------------------------------------------------------------- profile

  /// Creates the profile document the first time an account signs in.
  Future<void> ensureProfile() async {
    final user = _user;
    final snap = await _doc.get();
    final profile = UserProfile.fromData(snap.data(), user);
    final displayName = profile.displayName;
    if (!snap.exists) {
      await _doc.set({
        'displayName': displayName,
        'email': user.email,
        'bio': '',
        'avatar': null,
        'photoBase64': null,
        'bannerBase64': null,
        'recentSearches': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await _db.collection('publicUsers').doc(user.uid).set({
      'displayName': displayName,
      'bio': profile.bio,
      'avatar': profile.avatar,
      'photoUrl': profile.photoUrl,
      'photoBase64': profile.photoBase64,
      'bannerBase64': profile.bannerBase64,
    }, SetOptions(merge: true));
  }

  Stream<UserProfile> profileStream() {
    final user = _user;
    return _doc
        .snapshots()
        .map((snap) => UserProfile.fromData(snap.data(), user));
  }

  Stream<UserProfile?> publicProfileStream(String uid) => _db
      .collection('publicUsers').doc(uid).snapshots().map((snap) {
        final data = snap.data();
        if (!snap.exists || data == null) return null;
        return UserProfile(
          displayName: (data['displayName'] as String?) ?? 'Anime Fan',
          email: '',
          bio: (data['bio'] as String?) ?? '',
          avatar: data['avatar'] as String?,
          photoUrl: data['photoUrl'] as String?,
          photoBase64: data['photoBase64'] as String?,
          bannerBase64: data['bannerBase64'] as String?,
          recentSearches: const [],
        );
      });

  Future<void> updateProfile({
    required String displayName,
    required String bio,
    required String? avatar,
    String? photoBase64,
    String? bannerBase64,
  }) async {
    final user = _user;
    final name = displayName.trim();
    await _doc.set({
      'displayName': name,
      'bio': bio.trim(),
      'avatar': avatar,
      // null removes a previously uploaded photo.
      'photoBase64': photoBase64,
      'bannerBase64': bannerBase64,
    }, SetOptions(merge: true));
    await _db.collection('publicUsers').doc(user.uid).set({
      'displayName': name,
      'bio': bio.trim(),
      'avatar': avatar,
      'photoUrl': user.photoURL,
      'photoBase64': photoBase64,
      'bannerBase64': bannerBase64,
    }, SetOptions(merge: true));
    if (name.isNotEmpty) {
      await user.updateDisplayName(name);
    }
  }

  // -------------------------------------------------------------- favorites

  Stream<Set<String>> favoriteIdsStream() {
    return _favorites
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  Future<void> setFavorite(String animeId, bool value) {
    final ref = _favorites.doc(animeId);
    if (value) {
      return ref.set({'addedAt': FieldValue.serverTimestamp()});
    }
    return ref.delete();
  }

  // ------------------------------------------------------------------ posts

  /// Public feed: everyone's posts, newest first, updated in real time.
  Stream<List<UserPost>> feedStream({int limit = 30}) {
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(UserPost.fromDoc).toList());
  }

  /// Only this account's posts (used for the post counter on Profile).
  /// Sorted on the device so no composite index is needed.
  Stream<List<UserPost>> myPostsStream() {
    return _posts
        .where('uid', isEqualTo: _user.uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(UserPost.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Max size of the encoded photo. A Firestore document is limited to
  /// 1 MiB, so keep a safe margin for the text fields.
  static const int _maxImageBytes = 600 * 1024;

  Future<String> _encodeImage(XFile image) async {
    final bytes = await image.readAsBytes(); // works on mobile and web
    if (bytes.length > _maxImageBytes) {
      throw const FormatException('image-too-large');
    }
    return base64Encode(bytes);
  }

  /// Max size of an uploaded profile photo (it is copied into every post).
  static const int _maxAvatarBytes = 100 * 1024;

  /// Encodes a profile photo picked from the device. The picker already
  /// shrinks it; throws [FormatException] when it is still too big.
  Future<String> encodeAvatar(XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.length > _maxAvatarBytes) {
      throw const FormatException('image-too-large');
    }
    return base64Encode(bytes);
  }

  Future<String> encodeBanner(XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.length > 300 * 1024) {
      throw const FormatException('image-too-large');
    }
    return base64Encode(bytes);
  }

  Future<void> addPost({
    required String caption,
    String? animeId,
    XFile? image,
  }) async {
    final user = _user;
    final profileSnap = await _doc.get();
    final profile = UserProfile.fromData(profileSnap.data(), user);

    final imageBase64 = image == null ? null : await _encodeImage(image);
    final taggedAnime = animeById(animeId);

    await _posts.add({
      'uid': user.uid,
      'authorName': profile.displayName,
      'authorAvatar': profile.avatar,
      'authorPhotoUrl': profile.photoUrl,
      'authorPhotoBase64': profile.photoBase64,
      'caption': caption.trim(),
      'animeId': animeId,
      'animeTitle': taggedAnime?.title,
      'animeImageUrl': taggedAnime?.imageUrl,
      'imageBase64': imageBase64,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePost(UserPost post, {required String caption, required String? animeId}) async {
    if (!post.isMine) throw StateError('Only the post owner can edit this post.');
    final taggedAnime = animeById(animeId);
    await _posts.doc(post.id).update({
      'caption': caption.trim(),
      'animeId': animeId,
      'animeTitle': taggedAnime?.title,
      'animeImageUrl': taggedAnime?.imageUrl,
    });
  }

  Future<void> deletePost(UserPost post) async {
    if (!post.isMine) throw StateError('Only the post owner can delete this post.');
    await _posts.doc(post.id).delete();
  }

  // ---------------------------------------------------------- recent search

  Future<void> addRecentSearch(String query) async {
    final term = query.trim();
    if (term.isEmpty) return;
    final snap = await _doc.get();
    final list =
        List<String>.from((snap.data()?['recentSearches'] as List?) ?? const []);
    list.removeWhere((e) => e.toLowerCase() == term.toLowerCase());
    list.insert(0, term);
    await _doc.set(
      {'recentSearches': list.take(8).toList()},
      SetOptions(merge: true),
    );
  }

  Future<void> clearRecentSearches() {
    return _doc.set(
      {'recentSearches': <String>[]},
      SetOptions(merge: true),
    );
  }
}
