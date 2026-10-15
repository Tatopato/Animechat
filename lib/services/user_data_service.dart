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
  CollectionReference<Map<String, dynamic>> get _savedPosts =>
      _doc.collection('savedPosts');

  // ------------------------------------------------------------- community

  String get currentUid => _user.uid;

  Future<String?> addFriendByUid(String uid) async {
    final target = uid.trim();
    if (target.isEmpty || target == _user.uid) return null;
    final found = await _db.collection('publicUsers').doc(target).get();
    if (!found.exists) return null;
    if (found.data()?['friendRequestsEnabled'] == false) return 'disabled';
    final blockedByMe = await _doc.collection('blockedUsers').doc(target).get();
    if (blockedByMe.exists) return 'blocked';
    final existing = await _doc.collection('friends').doc(target).get();
    if (existing.exists) return 'already';
    final name = (found.data()?['displayName'] as String?)?.trim();
    final sender = UserProfile.fromData((await _doc.get()).data(), _user);
    await _db.collection('users').doc(target).collection('friendRequests')
        .doc(_user.uid).set({'uid': _user.uid, 'name': sender.displayName, 'createdAt': FieldValue.serverTimestamp()});
    await _createNotification(target, {
      'type': 'friend_request',
      'fromUid': _user.uid,
      'fromName': sender.displayName,
    });
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
    await _createNotification(request.uid, {
      'type': 'friend_accepted',
      'fromUid': _user.uid,
      'fromName': me,
    });
  }

  Future<void> rejectFriend(FriendRequest request) => _doc.collection('friendRequests').doc(request.uid).delete();

  Future<void> blockUser(String uid) async {
    if (uid.isEmpty || uid == _user.uid) return;
    await _doc.collection('blockedUsers').doc(uid).set({'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
    await removeFriend(uid);
    await _doc.collection('friendRequests').doc(uid).delete();
  }

  Future<void> unblockUser(String uid) => _doc.collection('blockedUsers').doc(uid).delete();

  Stream<List<Map<String, dynamic>>> blockedUsersStream() => _doc.collection('blockedUsers').snapshots().map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'uid': doc.id}).toList());

  Future<void> reportUser(String uid, String reason) async {
    final text = reason.trim();
    if (uid.isEmpty || uid == _user.uid || text.isEmpty || text.length > 500) return;
    await _db.collection('userReports').add({'reporterUid': _user.uid, 'reportedUid': uid, 'reason': text, 'createdAt': FieldValue.serverTimestamp(), 'status': 'new'});
  }

  Future<void> setFriendRequestsEnabled(bool enabled) async {
    await _db.collection('publicUsers').doc(_user.uid).set({'friendRequestsEnabled': enabled}, SetOptions(merge: true));
    await _doc.set({'friendRequestsEnabled': enabled}, SetOptions(merge: true));
  }

  Future<void> setTasteSharingEnabled(bool enabled) async {
    final favorites = await favoriteAnimeIdsOnce();
    await _doc.set({'tasteSharingEnabled': enabled}, SetOptions(merge: true));
    await _db.collection('publicUsers').doc(_user.uid).set({
      'tasteSharingEnabled': enabled,
      'favoriteAnimeIds': enabled ? favorites.toList() : <String>[],
    }, SetOptions(merge: true));
  }

  Stream<bool> tasteSharingEnabledStream() => _doc.snapshots().map((snapshot) => snapshot.data()?['tasteSharingEnabled'] == true);

  Stream<bool> friendRequestsEnabledStream() => _doc.snapshots().map((snapshot) => snapshot.data()?['friendRequestsEnabled'] != false);

  Stream<List<Map<String, dynamic>>> recommendedFriendsStream() => _db.collection('publicUsers').limit(100).snapshots().map((snapshot) {
    final users = snapshot.docs.where((doc) => doc.id != _user.uid).map((doc) => {...doc.data(), 'uid': doc.id}).toList();
    users.sort((a, b) => (b['displayName'] as String? ?? '').compareTo(a['displayName'] as String? ?? ''));
    return users;
  });

  Future<Set<String>> favoriteAnimeIdsOnce() async => (await _favorites.get()).docs.map((doc) => doc.id).toSet();

  Future<List<Map<String, dynamic>>> friendsWithSharedTaste() async {
    final mine = await favoriteAnimeIdsOnce();
    if (mine.isEmpty) return const [];
    final users = await recommendedFriendsStream().first;
    final friends = await friendsOnce();
    final existing = friends.map((friend) => friend['uid']).toSet();
    final blockedSnapshot = await _doc.collection('blockedUsers').get();
    final blocked = blockedSnapshot.docs.map((doc) => doc.id).toSet();
    final ranked = <Map<String, dynamic>>[];
    for (final user in users) {
      if (existing.contains(user['uid']) || blocked.contains(user['uid']) || user['friendRequestsEnabled'] == false) continue;
      final taste = Set<String>.from(user['favoriteAnimeIds'] as List? ?? const []);
      final overlap = mine.intersection(taste).length;
      if (overlap > 0) ranked.add({...user, 'sharedAnimeCount': overlap});
    }
    ranked.sort((a, b) => (b['sharedAnimeCount'] as int).compareTo(a['sharedAnimeCount'] as int));
    return ranked.take(20).toList();
  }

  Stream<List<Map<String, dynamic>>> friendsStream() => _doc.collection('friends').snapshots().map((s) => s.docs.map((d) => {...d.data(), 'uid': d.id}).toList());

  Stream<List<Map<String, dynamic>>> myGroupChatsStream() => _doc
      .collection('chats')
      .snapshots()
      .map((snapshot) {
        final groups = snapshot.docs.map((doc) => {...doc.data(), 'chatId': doc.id}).toList();
        DateTime updatedAt(Map<String, dynamic> group) {
          final value = group['updatedAt'];
          return value is Timestamp ? value.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        }
        groups.sort((a, b) => updatedAt(b).compareTo(updatedAt(a)));
        return groups;
      });

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
      'photoBase64': null,
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

  Future<void> updateGroupProfile({
    required String chatId,
    required String name,
    String? photoBase64,
  }) async {
    final title = name.trim();
    if (title.isEmpty || title.length > 60) {
      throw const FormatException('group-name-invalid');
    }
    if ((photoBase64?.length ?? 0) > 140000) {
      throw const FormatException('group-photo-too-large');
    }
    final chatRef = _db.collection('chats').doc(chatId);
    final chat = await chatRef.get();
    final members = List<String>.from(chat.data()?['members'] as List? ?? const []);
    if (!chat.exists || !members.contains(_user.uid)) throw StateError('Group chat not found.');
    await chatRef.update({
      'name': title,
      'photoBase64': photoBase64,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final batch = _db.batch();
    for (final uid in members) {
      batch.set(_db.collection('users').doc(uid).collection('chats').doc(chatId), {
        'chatId': chatId,
        'name': title,
        'isGroup': true,
        'members': members,
        'photoBase64': photoBase64,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> groupMembersOnce(String chatId) async {
    final snapshot = await _db.collection('chats').doc(chatId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null || data['isGroup'] != true) {
      throw StateError('Group chat not found.');
    }
    final members = List<String>.from(data['members'] as List? ?? const []);
    if (!members.contains(_user.uid)) {
      throw StateError('You are not a member of this group.');
    }
    final names = Map<String, dynamic>.from(data['memberNames'] as Map? ?? const {});
    final ownerUid = data['createdBy'] as String?;
    return members
        .map((uid) => {
              'uid': uid,
              'name': (names[uid] as String?)?.trim().isNotEmpty == true
                  ? (names[uid] as String).trim()
                  : 'Anime Fan',
              'isOwner': uid == ownerUid,
            })
        .toList();
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
        return {...data, 'id': d.id, 'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(), 'watchPartyAt': (data['watchPartyAt'] as Timestamp?)?.toDate()};
      }).toList());

  Future<void> sendMessage(
    String chatId,
    String text, {
    String? attachmentBase64,
    String? attachmentName,
    String? attachmentType,
    Map<String, dynamic>? extra,
  }) async {
    final message = text.trim();
    if (message.isEmpty && attachmentBase64 == null) return;
    if ((attachmentBase64?.length ?? 0) > 800000) {
      throw const FormatException('attachment-too-large');
    }
    final ref = _db.collection('chats').doc(chatId);
    final preview = message.isNotEmpty ? message : 'Sent ${attachmentName ?? 'an attachment'}';
    final chat = await ref.get();
    final chatData = chat.data() ?? const <String, dynamic>{};
    final members = List<String>.from(chatData['members'] as List? ?? const []);
    final profile = UserProfile.fromData((await _doc.get()).data(), _user);
    final senderName = (Map<String, dynamic>.from(
              chatData['memberNames'] as Map? ?? const {},
            )[_user.uid] as String?) ??
        profile.displayName;
    final messageRef = await ref.collection('messages').add({
      'uid': _user.uid,
      'senderName': senderName,
      'senderAvatar': profile.avatar,
      'senderPhotoUrl': profile.photoUrl,
      'senderPhotoBase64': profile.photoBase64,
      'text': message,
      'attachmentBase64': attachmentBase64,
      'attachmentName': attachmentName,
      'attachmentType': attachmentType,
      'createdAt': FieldValue.serverTimestamp(),
      ...?extra,
    });
    await ref.set({'updatedAt': FieldValue.serverTimestamp(), 'lastMessage': preview}, SetOptions(merge: true));
    if (chatData['isGroup'] == true) {
      final batch = _db.batch();
      for (final uid in members) {
        batch.set(_db.collection('users').doc(uid).collection('chats').doc(chatId), {
          'chatId': chatId,
          'name': (chatData['name'] as String?) ?? 'Group chat',
          'isGroup': true,
          'members': members,
          'photoBase64': chatData['photoBase64'],
          'lastMessage': preview,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
    await Future.wait(members.where((uid) => uid != _user.uid).map((uid) =>
        _createNotification(uid, {
          'type': 'message',
          'chatId': chatId,
          'messageId': messageRef.id,
          'chatName': (chatData['name'] as String?) ?? senderName,
          'isGroup': chatData['isGroup'] == true,
          'members': members,
          'fromUid': _user.uid,
          'fromName': senderName,
          'text': preview.length > 120 ? '${preview.substring(0, 120)}…' : preview,
        })));
  }

  Future<void> createChatPoll(String chatId, String question, List<String> options) async {
    final title = question.trim();
    final choices = options.map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
    if (title.isEmpty || title.length > 180 || choices.length < 2 || choices.length > 6 || choices.any((value) => value.length > 60)) {
      throw const FormatException('invalid-poll');
    }
    await sendMessage(chatId, title, extra: {
      'kind': 'poll',
      'pollOptions': choices,
    });
  }

  Future<void> postWeeklyChatPrompt(String chatId) async {
    const prompts = [
      'Weekly anime question: Which character had the best character development lately?',
      'Weekly anime question: What opening or ending are you not skipping right now?',
      'Weekly anime question: Which anime world would you visit for one day?',
      'Weekly anime question: What scene are you still thinking about?',
      'Weekly anime question: Which series deserves another season?',
      'Weekly anime question: Who is your favorite supporting character?',
      'Weekly anime question: What should the group watch together next?',
    ];
    final prompt = prompts[DateTime.now().weekday - 1];
    await sendMessage(chatId, prompt, extra: {'kind': 'weeklyPrompt'});
  }

  Future<void> createWatchParty(String chatId, String title, DateTime startsAt) async {
    final name = title.trim();
    if (name.isEmpty || name.length > 100 || startsAt.isBefore(DateTime.now())) throw const FormatException('invalid-watch-party');
    await sendMessage(chatId, name, extra: {'kind': 'watchParty', 'watchPartyAt': Timestamp.fromDate(startsAt)});
  }

  Future<void> voteChatPoll(String chatId, String messageId, int optionIndex) async {
    await _db.collection('chats').doc(chatId).collection('messages').doc(messageId)
        .collection('pollVotes').doc(_user.uid).set({
          'uid': _user.uid,
          'optionIndex': optionIndex,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Stream<List<Map<String, dynamic>>> chatPollVotesStream(String chatId, String messageId) =>
      _db.collection('chats').doc(chatId).collection('messages').doc(messageId)
          .collection('pollVotes').snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());

  Future<void> toggleMessageReaction(String chatId, String messageId, String emoji) async {
    final ref = _db.collection('chats').doc(chatId).collection('messages').doc(messageId)
        .collection('reactions').doc('${emoji}_${_user.uid}');
    final existing = await ref.get();
    if (existing.exists) {
      await ref.delete();
    } else {
      await ref.set({'uid': _user.uid, 'emoji': emoji, 'createdAt': FieldValue.serverTimestamp()});
    }
  }

  Stream<List<Map<String, dynamic>>> messageReactionsStream(String chatId, String messageId) =>
      _db.collection('chats').doc(chatId).collection('messages').doc(messageId)
          .collection('reactions').snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());

  Future<void> addComment(UserPost post, String text) async {
    final comment = text.trim();
    if (comment.isEmpty) return;
    final profile = UserProfile.fromData((await _doc.get()).data(), _user);
    final commentRef = await _posts.doc(post.id).collection('comments').add({
      'uid': _user.uid,
      'name': profile.displayName,
      'avatar': profile.avatar,
      'photoUrl': profile.photoUrl,
      'photoBase64': profile.photoBase64,
      'text': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (post.uid != _user.uid) {
      await _createNotification(post.uid, {
        'type': 'comment',
        'postId': post.id,
        'commentId': commentRef.id,
        'fromUid': _user.uid,
        'fromName': profile.displayName,
        'text': comment,
      });
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
      final post = await _posts.doc(postId).get();
      final ownerUid = post.data()?['uid'] as String?;
      if (ownerUid != null && ownerUid != _user.uid) {
        final profile = UserProfile.fromData((await _doc.get()).data(), _user);
        await _createNotification(ownerUid, {
          'type': 'like',
          'postId': postId,
          'fromUid': _user.uid,
          'fromName': profile.displayName,
        });
      }
    } else {
      await ref.delete();
    }
  }

  Stream<bool> postSavedStream(String postId) =>
      _savedPosts.doc(postId).snapshots().map((snapshot) => snapshot.exists);

  Future<void> setPostSaved(String postId, bool saved) {
    final ref = _savedPosts.doc(postId);
    if (saved) {
      return ref.set({'postId': postId, 'savedAt': FieldValue.serverTimestamp()});
    }
    return ref.delete();
  }

  /// Saved post documents stay private under the signed-in user's profile.
  Stream<List<UserPost>> savedPostsStream() async* {
    final query = _savedPosts.orderBy('savedAt', descending: true);
    Future<List<UserPost>> loadSavedPosts(
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) async {
        final posts = await Future.wait(snapshot.docs.map((saved) async {
          final postId = saved.id;
          final post = await _posts.doc(postId).get();
          if (!post.exists) return null;
          return UserPost.fromDoc(post);
        }));
        return posts.whereType<UserPost>().toList();
    }

    yield await loadSavedPosts(await query.get());
    await for (final snapshot in query.snapshots()) {
      yield await loadSavedPosts(snapshot);
    }
  }

  Future<void> _createNotification(
    String recipientUid,
    Map<String, dynamic> details,
  ) async {
    try {
      await _db
          .collection('users')
          .doc(recipientUid)
          .collection('notifications')
          .add({
        ...details,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {
      // A notification failure must not undo or misreport the user's action.
    }
  }

  Stream<List<Map<String, dynamic>>> notificationsStream() => _doc.collection('notifications').orderBy('createdAt', descending: true).limit(50).snapshots().map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  Future<void> markNotificationRead(String id) =>
      _doc.collection('notifications').doc(id).update({'read': true});

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

  Stream<Set<String>> favoriteIdsStream() => _favorites
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet())
      .asBroadcastStream();

  Future<void> setFavorite(String animeId, bool value) async {
    final ref = _favorites.doc(animeId);
    if (value) { await ref.set({'addedAt': FieldValue.serverTimestamp()}); }
    else { await ref.delete(); }
    final profile = await _doc.get();
    if (profile.data()?['tasteSharingEnabled'] == true) {
      await _db.collection('publicUsers').doc(_user.uid).set({'favoriteAnimeIds': value ? FieldValue.arrayUnion([animeId]) : FieldValue.arrayRemove([animeId])}, SetOptions(merge: true));
    }
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
  Stream<List<UserPost>> myPostsStream() =>
      _posts.where('uid', isEqualTo: _user.uid).snapshots().map((snapshot) {
        final posts = snapshot.docs.map(UserPost.fromDoc).toList();
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return posts;
      }).asBroadcastStream();

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
