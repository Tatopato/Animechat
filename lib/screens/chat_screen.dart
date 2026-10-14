import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/minimal_ui.dart';
import '../constants/app_motion.dart';
import '../services/user_data_service.dart';
import '../services/theme_controller.dart';
import 'public_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  static final ValueNotifier<Map<String, dynamic>?> pendingConversation =
      ValueNotifier<Map<String, dynamic>?>(null);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = UserDataService.instance;
  late final _friends = _service.friendsStream();
  late final _groups = _service.myGroupChatsStream();

  @override
  void initState() {
    super.initState();
    ThemeController.isDarkMode.addListener(_onThemeChanged);
    ChatScreen.pendingConversation.addListener(_openPendingConversation);
    _openPendingConversation();
  }

  void _openPendingConversation() {
    final details = ChatScreen.pendingConversation.value;
    if (details == null || !mounted) return;
    ChatScreen.pendingConversation.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        AppMotion.route(
          builder: (_) => _ConversationScreen(
            chatId: details['chatId'] as String,
            title: details['chatName'] as String? ?? 'Chat',
            isGroup: details['isGroup'] == true,
            members: List<String>.from(details['members'] as List? ?? const []),
            groupPhotoBase64: details['photoBase64'] as String?,
          ),
        ),
      );
    });
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeController.isDarkMode.removeListener(_onThemeChanged);
    ChatScreen.pendingConversation.removeListener(_openPendingConversation);
    super.dispose();
  }

  Future<void> _createGroup() async {
    try {
      final friends = await _service.friendsOnce();
      if (!mounted) return;
      if (friends.isEmpty) {
        miSnack(context, 'Add friends before creating a group.');
        return;
      }
      final draft = await showDialog<_GroupDraft>(
        context: context,
        builder: (_) => _GroupMemberDialog(friends: friends, askName: true),
      );
      if (draft == null || !mounted) return;
      await _service.createGroupChat(
        name: draft.name ?? '',
        friends: [
          for (final friend in friends)
            if (draft.friendUids.contains(friend['uid']))
              {'uid': '${friend['uid']}', 'name': '${friend['name'] ?? 'Friend'}'},
        ],
      );
      if (mounted) miSnack(context, 'Group created.');
    } catch (_) {
      if (mounted) miSnack(context, 'Could not create the group. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Mi.bg,
        body: MiBackdrop(
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(children: [
                  Expanded(child: Text('Chat with friends', style: Mi.title())),
                  IconButton.filledTonal(
                    tooltip: 'Create group chat',
                    onPressed: _createGroup,
                    icon: const Icon(Icons.group_add_rounded),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('Open Profile to add friends or manage requests.', style: Mi.caption()),
                const SizedBox(height: 24),
                const MiSectionHeader(title: 'Friends'),
                const SizedBox(height: 8),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _friends,
                  builder: (context, snap) {
                    final friends = snap.data ?? const <Map<String, dynamic>>[];
                    if (friends.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('Your chats will appear here.', style: Mi.caption()));
                    return Column(children: [
                      for (final friend in friends)
                        Card(
                          color: Mi.surface,
                          child: ListTile(
                            leading: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  AppMotion.route(
                                    builder: (_) => PublicProfileScreen(
                                      uid: (friend['uid'] as String?) ?? '',
                                    ),
                                  ),
                                ),
                                child: FriendAvatar(
                                  uid: (friend['uid'] as String?) ?? '',
                                  name: (friend['name'] as String?) ?? 'Friend',
                                  size: 42,
                                ),
                              ),
                            ),
                            title: Text((friend['name'] as String?) ?? 'Friend', style: Mi.body()),
                            subtitle: Text((friend['uid'] as String?) ?? '', style: Mi.caption()),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              final chatId = friend['chatId'] as String?;
                              if (chatId == null) return;
                              Navigator.push(context, AppMotion.route(builder: (_) => _ConversationScreen(chatId: chatId, title: (friend['name'] as String?) ?? 'Chat')));
                            },
                          ),
                        ),
                    ]);
                  },
                ),
                const SizedBox(height: 22),
                const MiSectionHeader(title: 'Group chats'),
                const SizedBox(height: 8),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _groups,
                  builder: (context, snap) {
                    if (snap.hasError) return const MiDataError();
                    if (!snap.hasData) return const MiLoading();
                    final groups = snap.data!;
                    if (groups.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('Create a group and add your friends here.', style: Mi.caption()),
                      );
                    }
                    return Column(children: [
                      for (final group in groups)
                        Card(
                          color: Mi.surface,
                          child: ListTile(
                            leading: _groupAvatar(group['photoBase64'] as String?),
                            title: Text((group['name'] as String?) ?? 'Group chat', style: Mi.body(weight: FontWeight.w700)),
                            subtitle: Text('${(group['members'] as List? ?? const []).length} members', style: Mi.caption()),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(context, AppMotion.route(builder: (_) => _ConversationScreen(
                              chatId: group['chatId'] as String,
                              title: (group['name'] as String?) ?? 'Group chat',
                              isGroup: true,
                              members: List<String>.from(group['members'] as List? ?? const []),
                              groupPhotoBase64: group['photoBase64'] as String?,
                            ))),
                          ),
                        ),
                    ]);
                  },
                ),
              ],
            ),
          ),
        ),
      );
}

Widget _groupAvatar(String? photoBase64) {
  Uint8List? photo;
  if (photoBase64 != null && photoBase64.isNotEmpty) {
    try {
      photo = base64Decode(photoBase64);
    } catch (_) {
      photo = null;
    }
  }
  return CircleAvatar(
    backgroundColor: Mi.tint,
    backgroundImage: photo == null ? null : MemoryImage(photo),
    child: photo == null ? const Icon(Icons.groups_rounded, color: Mi.violet) : null,
  );
}

class _GroupDraft {
  const _GroupDraft({this.name, required this.friendUids});
  final String? name;
  final List<String> friendUids;
}

class _GroupProfileDraft {
  const _GroupProfileDraft({required this.name, required this.photoBase64});
  final String name;
  final String? photoBase64;
}

class _GroupMembersSheet extends StatelessWidget {
  const _GroupMembersSheet({required this.groupName, required this.members});

  final String groupName;
  final List<Map<String, dynamic>> members;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Members', style: Mi.title(size: 20)),
                  const SizedBox(height: 3),
                  Text('$groupName · ${members.length} members', style: Mi.caption()),
                ]),
              ),
              Divider(height: 1, color: Mi.line),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                  itemCount: members.length,
                  separatorBuilder: (_, _) => Divider(height: 1, indent: 60, color: Mi.line),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final uid = member['uid'] as String? ?? '';
                    final name = member['name'] as String? ?? 'Anime Fan';
                    final isOwner = member['isOwner'] == true;
                    final isMe = uid == UserDataService.instance.currentUid;
                    final badges = <String>[
                      if (isMe) 'You',
                      if (isOwner) 'Group admin',
                    ];
                    return ListTile(
                      leading: FriendAvatar(uid: uid, name: name, size: 42),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.body(weight: FontWeight.w700)),
                      subtitle: Text(badges.isEmpty ? uid : badges.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.caption()),
                      trailing: Icon(Icons.chevron_right_rounded, color: Mi.sub),
                      onTap: uid.isEmpty ? null : () => Navigator.of(context).push(AppMotion.route(builder: (_) => PublicProfileScreen(uid: uid))),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

class _GroupProfileDialog extends StatefulWidget {
  const _GroupProfileDialog({required this.name, this.photoBase64});

  final String name;
  final String? photoBase64;

  @override
  State<_GroupProfileDialog> createState() => _GroupProfileDialogState();
}

class _GroupProfileDialogState extends State<_GroupProfileDialog> {
  late final _name = TextEditingController(text: widget.name);
  late String? _photoBase64 = widget.photoBase64;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256, imageQuality: 68);
      if (image == null) return;
      final encoded = await UserDataService.instance.encodeAvatar(image);
      if (mounted) setState(() => _photoBase64 = encoded);
    } on FormatException {
      if (mounted) miSnack(context, 'That group photo is too large. Choose another image.');
    } catch (_) {
      if (mounted) miSnack(context, 'Could not open the photo picker.');
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (_photoBase64 != null) {
      try {
        image = MemoryImage(base64Decode(_photoBase64!));
      } catch (_) {
        image = null;
      }
    }
    return AlertDialog(
      backgroundColor: Mi.surface,
      title: Text('Edit group profile', style: Mi.title(size: 19)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 42, backgroundColor: Mi.tint, backgroundImage: image, child: image == null ? const Icon(Icons.groups_rounded, color: Mi.violet, size: 34) : null),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton.icon(onPressed: _pickPhoto, icon: const Icon(Icons.photo_outlined), label: const Text('Change photo')),
              if (_photoBase64 != null) IconButton(tooltip: 'Remove photo', onPressed: () => setState(() => _photoBase64 = null), icon: const Icon(Icons.delete_outline_rounded, color: Mi.danger)),
            ]),
            TextField(controller: _name, maxLength: 60, autofocus: true, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Group name', border: OutlineInputBorder())),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : () => Navigator.pop(context, _GroupProfileDraft(name: _name.text.trim(), photoBase64: _photoBase64)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _GroupMemberDialog extends StatefulWidget {
  const _GroupMemberDialog({required this.friends, required this.askName});
  final List<Map<String, dynamic>> friends;
  final bool askName;

  @override
  State<_GroupMemberDialog> createState() => _GroupMemberDialogState();
}

class _GroupMemberDialogState extends State<_GroupMemberDialog> {
  final _name = TextEditingController();
  final Set<String> _selected = {};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (widget.askName && name.isEmpty) return;
    if (_selected.isEmpty) return;
    Navigator.of(context).pop(_GroupDraft(
      name: widget.askName ? name : null,
      friendUids: _selected.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Mi.surface,
        title: Text(widget.askName ? 'Create group chat' : 'Add friends', style: Mi.title(size: 19)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.askName) ...[
              TextField(controller: _name, maxLength: 60, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Group name', border: OutlineInputBorder())),
              const SizedBox(height: 8),
            ],
            Align(alignment: Alignment.centerLeft, child: Text('Choose friends', style: Mi.caption())),
            const SizedBox(height: 6),
            SizedBox(
              height: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.friends.length,
                itemBuilder: (context, index) {
                  final friend = widget.friends[index];
                  final uid = friend['uid'] as String? ?? '';
                  return CheckboxListTile(
                    value: _selected.contains(uid),
                    title: Text((friend['name'] as String?) ?? 'Friend', style: Mi.body()),
                    subtitle: Text(uid, maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.caption()),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        if (_selected.length < 30) _selected.add(uid);
                      } else {
                        _selected.remove(uid);
                      }
                    }),
                  );
                },
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: _selected.isEmpty || (widget.askName && _name.text.trim().isEmpty) ? null : _submit,
            child: Text(widget.askName ? 'Create' : 'Add'),
          ),
        ],
      );
}

class _ChatTheme {
  const _ChatTheme({required this.name, required this.background, required this.surface, required this.myBubble, required this.friendBubble, required this.accent});
  final String name;
  final Color background;
  final Color surface;
  final Gradient myBubble;
  final Color friendBubble;
  final Color accent;
}

const _chatThemes = [
  _ChatTheme(name: 'Blossom', background: Color(0xFFFFF2F8), surface: Color(0xFFFFFAFC), myBubble: LinearGradient(colors: [Color(0xFFFF77AA), Color(0xFF9D75FF)]), friendBubble: Colors.white, accent: Color(0xFFFF5C9D)),
  _ChatTheme(name: 'Ocean', background: Color(0xFFEAF7FF), surface: Color(0xFFF8FCFF), myBubble: LinearGradient(colors: [Color(0xFF39B8D6), Color(0xFF5576E8)]), friendBubble: Colors.white, accent: Color(0xFF318EC8)),
  _ChatTheme(name: 'Night sky', background: Color(0xFF22243A), surface: Color(0xFF30334F), myBubble: LinearGradient(colors: [Color(0xFF7058D8), Color(0xFFB15BBA)]), friendBubble: Color(0xFF383B59), accent: Color(0xFFB59AFF)),
];

class _ConversationScreen extends StatefulWidget {
  const _ConversationScreen({required this.chatId, required this.title, this.isGroup = false, this.members = const [], this.groupPhotoBase64});
  final String chatId;
  final String title;
  final bool isGroup;
  final List<String> members;
  final String? groupPhotoBase64;
  @override
  State<_ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<_ConversationScreen> {
  final _text = TextEditingController();
  final _imagePicker = ImagePicker();
  final _service = UserDataService.instance;
  late final _messages = _service.chatMessagesStream(widget.chatId);
  int _themeIndex = ThemeController.isDarkMode.value ? 2 : 0;
  bool _customTheme = false;
  bool _sending = false;
  late List<String> _members = List<String>.from(widget.members);
  late String _chatName = widget.title;
  late String? _groupPhotoBase64 = widget.groupPhotoBase64;
  final Map<String, Future<UserProfile?>> _legacyProfiles = {};
  _ChatTheme get _theme => _chatThemes[_themeIndex];
  ImageProvider? get _groupPhotoImage {
    final encoded = _groupPhotoBase64;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    ThemeController.isDarkMode.addListener(_onGlobalThemeChanged);
  }

  void _onGlobalThemeChanged() {
    if (!mounted || _customTheme) return;
    setState(() => _themeIndex = ThemeController.isDarkMode.value ? 2 : 0);
  }

  Future<void> _addGroupMembers() async {
    try {
      final friends = await _service.friendsOnce();
      if (!mounted) return;
      final available = friends.where((friend) => !_members.contains(friend['uid'])).toList();
      if (available.isEmpty) {
        miSnack(context, 'All your friends are already in this group.');
        return;
      }
      final draft = await showDialog<_GroupDraft>(
        context: context,
        builder: (_) => _GroupMemberDialog(friends: available, askName: false),
      );
      if (draft == null || !mounted) return;
      final members = await _service.addGroupMembers(widget.chatId, draft.friendUids);
      if (mounted) {
        setState(() => _members = members);
        miSnack(context, 'Friends added to the group.');
      }
    } catch (_) {
      if (mounted) miSnack(context, 'Could not add friends to this group.');
    }
  }

  Future<void> _editGroupProfile() async {
    final draft = await showDialog<_GroupProfileDraft>(
      context: context,
      builder: (_) => _GroupProfileDialog(name: _chatName, photoBase64: _groupPhotoBase64),
    );
    if (draft == null || !mounted) return;
    try {
      await _service.updateGroupProfile(
        chatId: widget.chatId,
        name: draft.name,
        photoBase64: draft.photoBase64,
      );
      if (!mounted) return;
      setState(() {
        _chatName = draft.name;
        _groupPhotoBase64 = draft.photoBase64;
      });
      miSnack(context, 'Group profile updated.');
    } on FormatException catch (error) {
      if (mounted) miSnack(context, error.message == 'group-photo-too-large' ? 'Choose a smaller group photo.' : 'Enter a group name.');
    } catch (_) {
      if (mounted) miSnack(context, 'Could not update the group profile. Check Firebase Rules and try again.');
    }
  }

  Future<void> _showGroupMembers() async {
    try {
      final members = await _service.groupMembersOnce(widget.chatId);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Mi.surface,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _GroupMembersSheet(groupName: _chatName, members: members),
      );
    } catch (_) {
      if (mounted) miSnack(context, 'Could not load group members.');
    }
  }

  @override
  void dispose() {
    ThemeController.isDarkMode.removeListener(_onGlobalThemeChanged);
    _text.dispose();
    super.dispose();
  }

  void _chooseTheme() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Mi.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Chat theme', style: Mi.title(size: 20))),
          for (var i = 0; i < _chatThemes.length; i++)
            ListTile(
              leading: CircleAvatar(backgroundColor: _chatThemes[i].accent, child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18)),
              title: Text(_chatThemes[i].name, style: Mi.body()),
              trailing: i == _themeIndex ? Icon(Icons.check_circle, color: _chatThemes[i].accent) : null,
              onTap: () { setState(() { _themeIndex = i; _customTheme = true; }); Navigator.pop(sheetContext); },
            ),
        ]),
      ),
    );
  }

  Future<void> _sendText() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    _text.clear();
    await _send(text: text);
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 65);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await _sendAttachment(bytes, 'Photo', 'image/jpeg');
    } catch (_) {
      if (mounted) miSnack(context, 'Could not attach that photo.');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw const FormatException('Could not read file bytes.');
      if (bytes.length > 480 * 1024) {
        if (mounted) miSnack(context, 'Attachments must be under 480 KB.');
        return;
      }
      final extension = file.name.split('.').last.toLowerCase();
      final type = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };
      await _sendAttachment(bytes, file.name, type);
    } catch (_) {
      if (mounted) miSnack(context, 'Could not attach that file.');
    }
  }

  Future<void> _sendAttachment(Uint8List bytes, String name, String type) async {
    if (bytes.length > 480 * 1024) {
      miSnack(context, 'Attachments must be under 480 KB.');
      return;
    }
    await _send(attachmentBase64: base64Encode(bytes), attachmentName: name, attachmentType: type);
  }

  Future<void> _send({String text = '', String? attachmentBase64, String? attachmentName, String? attachmentType}) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(widget.chatId, text, attachmentBase64: attachmentBase64, attachmentName: attachmentName, attachmentType: attachmentType);
    } catch (_) {
      if (mounted) miSnack(context, 'Could not send message. Check the attachment size and try again.');
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = _themeIndex == 2;
    final groupPhoto = _groupPhotoImage;
    return Scaffold(
      backgroundColor: _theme.background,
      appBar: AppBar(
        backgroundColor: _theme.surface,
        foregroundColor: dark ? Colors.white : Mi.text,
        title: Row(children: [
          Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, gradient: _theme.myBubble), child: CircleAvatar(backgroundColor: Colors.white, backgroundImage: groupPhoto, child: groupPhoto == null ? Icon(widget.isGroup ? Icons.groups_rounded : Icons.person_rounded, color: Mi.violet) : null)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_chatName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Mi.body(color: dark ? Colors.white : Mi.text, weight: FontWeight.w700)), Text(widget.isGroup ? 'Group · ${_members.length} members' : 'Private chat', style: Mi.caption())])),
        ]),
        actions: [
          if (widget.isGroup) IconButton(tooltip: 'Edit group profile', onPressed: _editGroupProfile, icon: Icon(Icons.edit_rounded, color: _theme.accent)),
          if (widget.isGroup) IconButton(tooltip: 'View group members', onPressed: _showGroupMembers, icon: Icon(Icons.groups_2_outlined, color: _theme.accent)),
          if (widget.isGroup) IconButton(tooltip: 'Add friends', onPressed: _addGroupMembers, icon: Icon(Icons.person_add_alt_1_rounded, color: _theme.accent)),
          IconButton(tooltip: 'Choose theme', onPressed: _chooseTheme, icon: Icon(Icons.palette_outlined, color: _theme.accent)),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_theme.background, _theme.surface, _theme.background])),
        child: Column(children: [
          Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _messages,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Could not load messages.', style: Mi.body(color: dark ? Colors.white70 : Mi.sub)));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final messages = snap.data!;
              if (messages.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.waving_hand_rounded, size: 34, color: _theme.accent), const SizedBox(height: 8), Text('Say hello to $_chatName!', style: Mi.body(color: dark ? Colors.white70 : Mi.sub))]));
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 20, 14, 18),
                itemCount: messages.length,
                itemBuilder: (context, index) => _messageBubble(messages[index], dark),
              );
            },
          )),
          SafeArea(top: false, child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(color: _theme.surface, boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 12, offset: Offset(0, -3))]),
            child: Row(children: [
              IconButton(tooltip: 'Attach a file', onPressed: _sending ? null : _pickFile, icon: Icon(Icons.attach_file_rounded, color: _theme.accent)),
              IconButton(tooltip: 'Attach a photo', onPressed: _sending ? null : _pickImage, icon: Icon(Icons.image_outlined, color: _theme.accent)),
              Expanded(child: TextField(controller: _text, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendText(), style: Mi.body(color: dark ? Colors.white : Mi.text), decoration: InputDecoration(hintText: 'Write a message...', filled: true, fillColor: _theme.background, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)))),
              const SizedBox(width: 5),
              IconButton.filled(onPressed: _sending ? null : _sendText, style: IconButton.styleFrom(backgroundColor: _theme.accent, foregroundColor: Colors.white), icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded)),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> message, bool dark) {
    final mine = message['uid'] == _service.currentUid;
    final senderUid = message['uid'] as String? ?? '';
    final storedName = (message['senderName'] as String?)?.trim().isNotEmpty == true
        ? (message['senderName'] as String).trim()
        : (message['fromName'] as String?)?.trim().isNotEmpty == true
            ? (message['fromName'] as String).trim()
            : widget.isGroup ? 'Friend' : widget.title;
    final senderProfile = UserProfile(
      displayName: storedName,
      email: '',
      bio: '',
      avatar: message['senderAvatar'] as String?,
      photoUrl: message['senderPhotoUrl'] as String?,
      photoBase64: message['senderPhotoBase64'] as String?,
      recentSearches: const [],
    );
    final text = (message['text'] as String?) ?? '';
    final data = message['attachmentBase64'] as String?;
    final name = (message['attachmentName'] as String?) ?? 'Attachment';
    final type = (message['attachmentType'] as String?) ?? '';
    final sentAt = message['createdAt'] as DateTime?;
    final time = sentAt == null ? '' : '${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}';
    final bubble = Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (mine ? .78 : .68)),
        margin: EdgeInsets.only(bottom: mine ? 10 : 0),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: mine ? null : _theme.friendBubble, gradient: mine ? _theme.myBubble : null, borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 5), bottomRight: Radius.circular(mine ? 5 : 18)), boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (data != null && type.startsWith('image/')) ...[
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(data), width: 220, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined))),
            if (name != 'Photo') const SizedBox(height: 5),
          ] else if (data != null) ...[
            InkWell(onTap: () => _saveAttachment(name, base64Decode(data)), borderRadius: BorderRadius.circular(10), child: Container(width: 220, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha: .2) : dark ? Colors.white.withValues(alpha: .1) : Mi.tint, borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(Icons.insert_drive_file_outlined, color: mine || dark ? Colors.white : _theme.accent), const SizedBox(width: 8), Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Mi.body(color: mine || dark ? Colors.white : Mi.text, size: 12))), Icon(Icons.download_rounded, color: mine || dark ? Colors.white : _theme.accent, size: 18)]))),
            if (text.isNotEmpty) const SizedBox(height: 6),
          ],
          if (text.isNotEmpty) Text(text, style: Mi.body(color: mine || dark ? Colors.white : Mi.text)),
          if (time.isNotEmpty) Align(alignment: Alignment.bottomRight, child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(time, style: Mi.caption().copyWith(color: mine || dark ? Colors.white70 : Mi.sub, fontSize: 10)))),
        ]),
      );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: mine
          ? bubble
          : Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                FutureBuilder<UserProfile?>(
                  future: senderUid.isEmpty || message['senderName'] != null
                      ? null
                      : (_legacyProfiles[senderUid] ??= _service.publicProfileStream(senderUid).first),
                  builder: (context, snapshot) {
                    final profile = snapshot.data ?? senderProfile;
                    final senderName = profile.displayName;
                    return Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                      MouseRegion(
                        cursor: senderUid.isEmpty ? SystemMouseCursors.basic : SystemMouseCursors.click,
                        child: GestureDetector(
                        onTap: senderUid.isEmpty ? null : () => Navigator.of(context).push(
                          AppMotion.route(builder: (_) => PublicProfileScreen(uid: senderUid)),
                        ),
                        child: Padding(padding: const EdgeInsets.only(right: 8, bottom: 10), child: UserAvatar(profile: profile, size: 32)),
                        ),
                      ),
                      Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: Text(senderName, style: Mi.caption().copyWith(color: dark ? Colors.white70 : Mi.sub, fontWeight: FontWeight.w700))),
                        bubble,
                      ])),
                    ]);
                  },
                ),
              ]),
            ),
    );
  }

  Future<void> _saveAttachment(String name, Uint8List bytes) async {
    try {
      final saved = await FilePicker.saveFile(fileName: name, bytes: bytes);
      if (saved != null && mounted) miSnack(context, 'File saved.');
    } catch (_) {
      if (mounted) miSnack(context, 'Could not save this file on your device.');
    }
  }
}
