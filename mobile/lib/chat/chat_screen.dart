import 'dart:async';

import 'package:flutter/material.dart';

import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/chat.dart';
import 'chat_widgets.dart';

/// 1-on-1 chat. Messages arrive live through a Supabase realtime stream, which applies the table's RLS, so only
/// the two people in the conversation ever receive them.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId, required this.otherName, this.otherAvatarUrl});
  final String conversationId;
  final String otherName;
  final String? otherAvatarUrl;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final Stream<List<ChatMessage>> _stream = supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', widget.conversationId)
      .order('created_at', ascending: false) // newest first, shown from the bottom by the reversed list
      .map((rows) => rows.map((r) => ChatMessage.fromMap(Map<String, dynamic>.from(r))).toList());

  String get _me => supabase.auth.currentUser!.id;

  Future<void> _send(String text) async {
    try {
      await supabase.from('messages').insert({'conversation_id': widget.conversationId, 'sender_id': _me, 'body': text});
    } catch (e) {
      if (mounted) showSnack(context, 'Message not sent. ${errorText(e)}', error: true);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Avatar(name: widget.otherName, url: widget.otherAvatarUrl, radius: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.otherName, overflow: TextOverflow.ellipsis)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorText(snap.error!), textAlign: TextAlign.center)));
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.ink));
              final msgs = snap.data!;
              if (msgs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.waving_hand_rounded, size: 44, color: AppColors.ink),
                      const SizedBox(height: 12),
                      Text('Say salam to ${widget.otherName.split(' ').first}', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      const Text('Tell them the grade, subject and area you need.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                    ]),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                itemCount: msgs.length,
                itemBuilder: (context, i) => MessageBubble(message: msgs[i], mine: msgs[i].senderId == _me),
              );
            },
          ),
        ),
        MessageInputBar(onSend: _send),
      ]),
    );
  }
}
