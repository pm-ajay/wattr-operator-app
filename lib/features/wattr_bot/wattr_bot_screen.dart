import 'package:flutter/material.dart';

import '../../core/models/chat_message.dart';
import '../../core/models/report_type.dart';

/// A dummy chatbot: the operator taps a report type, Wattr Bot gives a
/// canned acknowledgement. No real report generation happens here.
class WattrBotScreen extends StatefulWidget {
  const WattrBotScreen({super.key, this.pumpLabel});

  /// When opened from a specific pump's detail screen, replies mention this
  /// pump by name. Null when opened from the Dashboard — reports are then
  /// framed as fleet-wide.
  final String? pumpLabel;

  @override
  State<WattrBotScreen> createState() => _WattrBotScreenState();
}

class _WattrBotScreenState extends State<WattrBotScreen> {
  final _scrollController = ScrollController();
  late final List<ChatMessage> _messages = [
    ChatMessage(text: _greeting(), isBot: true),
  ];

  String _greeting() {
    if (widget.pumpLabel != null) {
      return "Hi, I'm Wattr Bot 👋 I can pull a report for ${widget.pumpLabel}. Which one would you like?";
    }
    return "Hi, I'm Wattr Bot 👋 I can pull a report across your pumps. Which one would you like?";
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _requestReport(ReportType type) {
    setState(() {
      _messages.add(ChatMessage(text: type.label, isBot: false));
      final scope = widget.pumpLabel != null ? ' for ${widget.pumpLabel}' : '';
      _messages.add(ChatMessage(text: "We'll share the ${type.label}$scope soon.", isBot: true));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.smart_toy_outlined, size: 18, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            const Text('Wattr Bot'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _MessageBubble(message: _messages[index]),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in ReportType.values)
                    OutlinedButton(
                      onPressed: () => _requestReport(type),
                      child: Text(type.label),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBot = message.isBot;

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isBot ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isBot ? 4 : 16),
            bottomRight: Radius.circular(isBot ? 16 : 4),
          ),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isBot ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
