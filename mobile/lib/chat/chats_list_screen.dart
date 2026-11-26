import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';
import '../core/stickers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/chat.dart';
import 'chat_screen.dart';
import 'chat_widgets.dart';

/// All of the user's threads, newest first. Works for parents (threads with teachers) and for teachers
/// (threads with parents). Updates live when a message arrives.
class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  List<ConversationSummary>? _all;
  String? _error;
  bool _showActive = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    // RLS limits what is delivered to this user's own conversations.
    _channel = supabase
        .channel('chats-list-${supabase.auth.currentUser!.id}')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'messages', callback: (_) => _load())
        .subscribe();
  }

  @override
  void dispose() {
    final c = _channel;
    if (c != null) supabase.removeChannel(c);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await supabase.rpc('my_conversations') as List;
      final list = rows.map((r) => ConversationSummary.fromMap(Map<String, dynamic>.from(r as Map))).toList();
      if (mounted) setState(() { _all = list; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final shown = all?.where((c) => c.isActive == _showActive).toList() ?? const <ConversationSummary>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: true, label: Text('Active ${all?.where((c) => c.isActive).length ?? 0}')),
              ButtonSegment(value: false, label: Text('Past ${all?.where((c) => !c.isActive).length ?? 0}')),
            ],
            selected: {_showActive},
            onSelectionChanged: (s) => setState(() => _showActive = s.first),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.coral))
          else if (all == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.teal)))
          else if (shown.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                const Sticker('notebook', size: 72, angle: -6),
                const SizedBox(height: 8),
                Text(_showActive ? 'No active chats yet. Tap Connect on a teacher to start one.' : 'No past chats.', textAlign: TextAlign.center),
              ]),
            )
          else
            for (final c in shown)
              ConversationTile(
                summary: c,
                avatar: Avatar(name: c.otherName, url: c.otherAvatarUrl, radius: 24),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(conversationId: c.id, otherName: c.otherName, otherAvatarUrl: c.otherAvatarUrl),
                  ));
                  if (mounted) _load();
                },
              ),
        ]),
      ),
    );
  }
}
