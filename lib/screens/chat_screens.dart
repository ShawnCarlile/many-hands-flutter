// Public rooms and private conversations.
// Ported from src/pages/Chat.jsx, ChatRoom.jsx, Messages.jsx and Conversation.jsx.
// On a phone, Rooms and Messages share the Chat tab.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../logic/chat_contract.dart';
import '../logic/errors.dart';
import '../models.dart';
import '../services/api.dart' as api;
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          actions: const [MeButton()],
          bottom: const TabBar(tabs: [Tab(text: 'Rooms'), Tab(text: 'Messages')]),
        ),
        body: const TabBarView(children: [_RoomsTab(), _MessagesTab()]),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.avatarId, required this.avatarName, required this.title, required this.subtitle, this.trailing, required this.onTap});
  final String? avatarId;
  final String avatarName, title, subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Avatar(id: avatarId, name: avatarName, size: 48),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}

class _RoomsTab extends StatefulWidget {
  const _RoomsTab();
  @override
  State<_RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends State<_RoomsTab> {
  final stream = api.watchRooms();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    Widget room(Room r, String subtitle) => _ListRow(
          avatarId: r.id,
          avatarName: r.name,
          title: '# ${r.name}',
          subtitle: r.description.isNotEmpty ? r.description : subtitle,
          onTap: () => context.push('/room/${r.id}'),
        );
    return StreamBuilder<List<Room>>(
      stream: stream,
      builder: (context, snap) => ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        const PageHero(title: 'Community chat.', lede: 'Public rooms everyone in the community can read and join. For private talks, use Messages.'),
        room(api.generalRoom, ''),
        if (snap.hasError) Padding(padding: const EdgeInsets.all(16), child: ErrorNote(friendlyError(snap.error))),
        if (!snap.hasData && !snap.hasError) const Padding(padding: EdgeInsets.all(16), child: Muted('Loading rooms…')),
        for (final r in snap.data ?? const <Room>[]) room(r, 'Started by ${data.nameOf(r.createdBy)}'),
        const Padding(padding: EdgeInsets.all(16), child: _NewRoomForm()),
      ]),
    );
  }
}

class _NewRoomForm extends StatefulWidget {
  const _NewRoomForm();
  @override
  State<_NewRoomForm> createState() => _NewRoomFormState();
}

class _NewRoomFormState extends State<_NewRoomForm> with ActionState {
  bool open = false;
  final name = TextEditingController();
  final description = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(onPressed: () => setState(() => open = true), icon: const Icon(Icons.add), label: const Text('Start a new room')),
      );
    }
    final uid = context.read<AuthService>().uid;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced([
      LabeledField(label: 'Room name', controller: name, maxLength: api.maxRoomNameLength, hint: 'e.g. Park cleanup crew', onChanged: (_) => setState(() {})),
      LabeledField(label: "What's it for? (optional)", controller: description, maxLength: api.maxRoomDescriptionLength),
      Row(children: [
        FilledButton(
          onPressed: busy || name.text.trim().isEmpty
              ? null
              : () => run(() async {
                    final id = await api.createRoom(uid, name: name.text, description: description.text);
                    if (!mounted) return;
                    setState(() {
                      open = false;
                      name.clear();
                      description.clear();
                    });
                    GoRouter.of(this.context).push('/room/$id');
                  }),
          child: const Text('Create room'),
        ),
        TextButton(onPressed: () => setState(() => open = false), child: const Text('Cancel')),
      ]),
      ErrorNote(error),
    ]));
  }
}

class _MessagesTab extends StatefulWidget {
  const _MessagesTab();
  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  late final stream = api.watchConversations(context.read<AuthService>().uid);

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    final data = context.watch<DataService>();
    return StreamBuilder<List<Conversation>>(
      stream: stream,
      builder: (context, snap) {
        final list = snap.data;
        return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          const PageHero(title: 'Messages.', lede: 'Private conversations with community members.'),
          if (snap.hasError) Padding(padding: const EdgeInsets.all(16), child: ErrorNote(friendlyError(snap.error))),
          if (list == null && !snap.hasError) const Padding(padding: EdgeInsets.all(16), child: Muted('Loading conversations…')),
          if (list != null && list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyNote('No conversations yet. Open a member profile and choose Message to start one.'),
            ),
          for (final conv in list ?? const <Conversation>[])
            Builder(builder: (context) {
              final other = conv.otherThan(uid);
              return _ListRow(
                avatarId: other,
                avatarName: data.nameOf(other),
                title: data.nameOf(other),
                subtitle: conv.lastMessage.isNotEmpty ? conv.lastMessage : 'Start a conversation',
                trailing: Muted(formatWhen(conv.updatedAt), small: true),
                onTap: () => context.push('/conversation/${Uri.encodeComponent(conv.id)}'),
              );
            }),
        ]);
      },
    );
  }
}

/// Chat bubbles plus a compose box. Shared by rooms and conversations.
class _ChatView extends StatefulWidget {
  const _ChatView({
    required this.messages,
    required this.otherName,
    required this.placeholder,
    required this.onSend,
    required this.emptyText,
    this.header,
    this.showSenders = false,
    this.canDelete,
    this.onDelete,
  });
  final Stream<List<ChatMessage>> messages;
  final String Function(String senderId) otherName;
  final String placeholder, emptyText;
  final Future<void> Function(String text) onSend;
  final Widget? header;
  final bool showSenders;
  final bool Function(ChatMessage m)? canDelete;
  final Future<void> Function(ChatMessage m)? onDelete;
  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> with ActionState {
  final draft = TextEditingController();

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  Future<void> confirmDelete(ChatMessage m, bool mine, String name) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(mine ? 'Delete this message for everyone?' : "Remove $name's message as an admin?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) await run(() => widget.onDelete!(m));
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    final c = context.colors;
    return Column(children: [
      ?widget.header,
      Expanded(
        child: StreamBuilder<List<ChatMessage>>(
          stream: widget.messages,
          builder: (context, snap) {
            if (snap.hasError) return Padding(padding: const EdgeInsets.all(16), child: ErrorNote(friendlyError(snap.error)));
            final list = snap.data;
            if (list == null) return const Center(child: Muted('Loading messages…'));
            if (list.isEmpty) return Center(child: Muted(widget.emptyText));
            // Newest at the bottom; a reversed list keeps the view pinned there as messages arrive.
            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final m = list[list.length - 1 - i];
                final mine = m.senderId == uid;
                final name = widget.otherName(m.senderId);
                final deletable = widget.canDelete?.call(m) ?? false;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: deletable ? () => confirmDelete(m, mine, name) : null,
                    child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (!mine && widget.showSenders)
                        Padding(
                          padding: const EdgeInsets.only(right: 6, bottom: 8),
                          child: InkWell(
                            onTap: () => context.push('/member/${m.senderId}'),
                            child: Avatar(id: m.senderId, name: name, size: 28),
                          ),
                        ),
                      Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: mine ? c.accent : c.surface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (!mine && widget.showSenders) Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(m.text, style: TextStyle(color: mine ? c.onAccent : null)),
                          const SizedBox(height: 4),
                          Text(
                            '${mine ? 'You' : name} · ${formatWhen(m.createdAt)}${deletable ? ' · hold to delete' : ''}',
                            style: TextStyle(fontSize: 11, color: mine ? c.onAccent.withValues(alpha: 0.75) : c.ink2),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
      if (error.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ErrorNote(error)),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: draft,
                minLines: 1,
                maxLines: 5,
                maxLength: maxChatMessageLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: widget.placeholder, counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: busy || draft.text.trim().isEmpty
                  ? null
                  : () => run(() async {
                        await widget.onSend(draft.text);
                        draft.clear();
                        if (mounted) setState(() {});
                      }),
              icon: const Icon(Icons.send),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key, required this.roomId});
  final String roomId;
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with ActionState {
  late final roomStream = api.watchRoom(widget.roomId);
  late final messages = api.watchRoomMessages(widget.roomId);
  bool confirmingClose = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<DataService>();
    return StreamBuilder<Room?>(
      stream: roomStream,
      builder: (context, snap) {
        if (snap.hasError || (snap.connectionState != ConnectionState.waiting && snap.data == null)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Room')),
            body: PageHero(
              title: 'This room isn’t available.',
              lede: snap.hasError ? friendlyError(snap.error) : 'It may have been closed by the person who started it.',
            ),
          );
        }
        final room = snap.data;
        final roomName = room != null ? '# ${room.name}' : 'Room';
        final canClose = room != null && !room.builtIn && (room.createdBy == auth.uid || auth.isAdmin);
        return Scaffold(
          appBar: AppBar(
            title: Text(roomName),
            actions: [
              if (canClose && !confirmingClose)
                TextButton(onPressed: () => setState(() => confirmingClose = true), child: const Text('Close room')),
            ],
          ),
          body: _ChatView(
            messages: messages,
            otherName: data.nameOf,
            showSenders: true,
            placeholder: 'Message $roomName',
            emptyText: 'No messages yet. Say hello.',
            onSend: (text) => api.sendRoomMessage(widget.roomId, auth.uid, text),
            canDelete: (m) => m.senderId == auth.uid || auth.isAdmin,
            onDelete: (m) => api.deleteRoomMessage(widget.roomId, m.id),
            header: room == null
                ? null
                : Container(
                    width: double.infinity,
                    color: context.colors.bgAlt,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (room.description.isNotEmpty) Muted(room.description, small: true),
                      Muted(
                        room.builtIn
                            ? 'Everyone in the community can read this room.'
                            : 'Started by ${room.createdBy == auth.uid ? 'you' : data.nameOf(room.createdBy)}. Everyone in the community can read this room.',
                        small: true,
                      ),
                      if (confirmingClose)
                        ConfirmRow(
                          question: 'Close this room for everyone?',
                          confirmLabel: 'Close room',
                          busy: busy,
                          onConfirm: () => run(() async {
                            await api.deleteRoom(widget.roomId);
                            if (context.mounted) context.pop();
                          }),
                          onCancel: () => setState(() => confirmingClose = false),
                        ),
                      ErrorNote(error),
                    ]),
                  ),
          ),
        );
      },
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});
  final String conversationId;
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late final convStream = api.watchConversation(widget.conversationId);
  late final messages = api.watchConversationMessages(widget.conversationId);

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    final data = context.watch<DataService>();
    return StreamBuilder<Conversation?>(
      stream: convStream,
      builder: (context, snap) {
        if (snap.hasError || (snap.connectionState != ConnectionState.waiting && snap.data == null)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Conversation')),
            body: PageHero(
              title: 'This conversation isn’t available.',
              lede: snap.hasError ? friendlyError(snap.error) : 'It may have been removed or you may not be a participant.',
            ),
          );
        }
        final other = snap.data?.otherThan(uid);
        final otherName = other != null ? data.nameOf(other) : 'Community member';
        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: other == null ? null : () => context.push('/member/$other'),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (other != null) ...[Avatar(id: other, name: otherName, size: 30), const SizedBox(width: 8)],
                Flexible(child: Text(otherName, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
          body: _ChatView(
            messages: messages,
            otherName: (_) => otherName,
            placeholder: 'Message $otherName',
            emptyText: 'No messages yet. Send the first one.',
            onSend: (text) => api.sendChatMessage(widget.conversationId, uid, text),
          ),
        );
      },
    );
  }
}
