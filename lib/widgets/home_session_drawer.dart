import 'package:flutter/material.dart';

import '../models/chat_models.dart';

class HomeSessionDrawer extends StatelessWidget {
  const HomeSessionDrawer({
    super.key,
    required this.sessions,
    required this.currentSessionId,
    required this.historyTitle,
    required this.newSessionTooltip,
    required this.renameLabel,
    required this.deleteLabel,
    required this.formatRelativeTime,
    required this.onCreateSession,
    required this.onRenameSession,
    required this.onDeleteSession,
    required this.onSelectSession,
  });

  final List<ChatSession> sessions;
  final int? currentSessionId;
  final String historyTitle;
  final String newSessionTooltip;
  final String renameLabel;
  final String deleteLabel;
  final String Function(DateTime) formatRelativeTime;
  final Future<void> Function() onCreateSession;
  final Future<void> Function(ChatSession session) onRenameSession;
  final Future<void> Function(ChatSession session) onDeleteSession;
  final Future<void> Function(ChatSession session) onSelectSession;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 30),
                  const SizedBox(width: 10),
                  Text(
                    historyTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add, size: 30),
                    tooltip: newSessionTooltip,
                    onPressed: () async {
                      await onCreateSession();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return ListTile(
                    selected: session.id == currentSessionId,
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(formatRelativeTime(session.updatedAt)),
                    trailing: PopupMenuButton<String>(
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'rename',
                          child: Text(renameLabel),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(deleteLabel),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'rename') {
                          await onRenameSession(session);
                        } else if (value == 'delete') {
                          await onDeleteSession(session);
                        }
                      },
                    ),
                    onTap: () async {
                      await onSelectSession(session);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
