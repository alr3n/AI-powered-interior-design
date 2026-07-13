import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/room_model.dart';
import '../../../services/gemini_client.dart';
import '../../projects/data/project_repository.dart';

class ChatMessage {
  const ChatMessage({required this.role, required this.text});
  final String role; // user | model
  final String text;
}

/// Chat state: message list + optional room context (most recent project).
class ChatController extends AutoDisposeNotifier<List<ChatMessage>> {
  bool sending = false;

  @override
  List<ChatMessage> build() => const [
        ChatMessage(
            role: 'model',
            text:
                "Hi! I'm SpaceSense. Ask me anything about your room — paint "
                'quantities, furniture fit, budgets, lighting…'),
      ];

  Future<void> send(String text, {RoomModel? room}) async {
    if (text.trim().isEmpty || sending) return;
    sending = true;
    state = [...state, ChatMessage(role: 'user', text: text.trim())];
    try {
      final history = state
          .map((m) => {'role': m.role, 'text': m.text})
          .toList(growable: false);
      final reply = await ref.read(geminiClientProvider).chat(
            message: text.trim(),
            history: history.sublist(0, history.length - 1),
            room: room,
          );
      state = [...state, ChatMessage(role: 'model', text: reply)];
    } catch (e) {
      state = [...state, ChatMessage(role: 'model', text: e.toString())];
    } finally {
      sending = false;
    }
  }
}

final chatControllerProvider =
    AutoDisposeNotifierProvider<ChatController, List<ChatMessage>>(
        ChatController.new);

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String? _contextProjectId;

  static const _suggestions = [
    'How can I make this room brighter?',
    'Can I fit a queen bed?',
    'How much paint do I need?',
    'How do I maximize storage?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    RoomModel? room;
    final pid = _contextProjectId;
    if (pid != null) {
      room = ref.read(latestRoomProvider(pid)).valueOrNull;
    }
    ref.read(chatControllerProvider.notifier).send(text, room: room);
    _input.clear();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatControllerProvider);
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          if (projects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButton<String>(
                value: _contextProjectId,
                hint: const Text('Room context'),
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No room')),
                  ...projects.map((p) =>
                      DropdownMenuItem(value: p.id, child: Text(p.name))),
                ],
                onChanged: (v) => setState(() => _contextProjectId = v),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                final isUser = m.role == 'user';
                final scheme = Theme.of(context).colorScheme;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                    ),
                    child: SelectableText(m.text),
                  ),
                );
              },
            ),
          ),
          if (messages.length <= 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _suggestions
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                              label: Text(s), onPressed: () => _send(s)),
                        ))
                    .toList(),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                          hintText: 'Ask about your room…'),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _send(_input.text),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
