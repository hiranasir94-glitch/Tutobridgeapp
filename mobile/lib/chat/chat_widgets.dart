import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/chat.dart';

/// One message. Mine sit on the right in lime; theirs on the left in white.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * .78;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW.clamp(0, 520)),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
        decoration: BoxDecoration(
          color: mine ? AppColors.lime : Colors.white,
          border: mine ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(message.body, style: TextStyle(color: AppColors.ink, fontSize: 15, height: 1.3)),
          ),
          const SizedBox(height: 3),
          Text(shortTime(message.createdAt), style: TextStyle(color: mine ? AppColors.ink : AppColors.muted, fontSize: 10.5)),
        ]),
      ),
    );
  }
}

/// Text box with a send button. Calls [onSend] with trimmed text; the button is off while the box is empty.
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({super.key, required this.onSend, this.enabled = true});
  final Future<void> Function(String text) onSend;
  final bool enabled;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final _c = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _c.clear();
    try {
      await widget.onSend(text);
    } catch (_) {
      _c.text = text; // keep what they typed so nothing is lost on a failed send
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _c,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Write a message...', counterText: '', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.lime, foregroundColor: AppColors.ink, minimumSize: const Size(48, 48)),
              tooltip: 'Send',
              onPressed: (widget.enabled && !_sending && _c.text.trim().isNotEmpty) ? _send : null,
              icon: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.ink))
                  : const Icon(Icons.send_rounded),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A row in the Chats list.
class ConversationTile extends StatelessWidget {
  const ConversationTile({super.key, required this.summary, required this.onTap, required this.avatar});
  final ConversationSummary summary;
  final VoidCallback onTap;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.line, width: 1.5)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: avatar,
        title: Text(summary.otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(summary.lastPreview ?? 'No messages yet. Say salam!', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(shortTime(summary.lastMessageAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ),
    );
  }
}
