import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../data/chatbot_client.dart';

/// Chat scoped to the four main tabs; pushed routes cover this widget.
class FloatingChatbot extends ConsumerStatefulWidget {
  const FloatingChatbot({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FloatingChatbot> createState() => _FloatingChatbotState();
}

class _FloatingChatbotState extends ConsumerState<FloatingChatbot> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <({String text, bool user})>[
    (
      text: 'Hi! I’m Altrixs Help. Ask me about appointments, messages, or video visits. I’m an AI assistant, not your clinician. Messages you send are processed by Groq. Avoid sharing sensitive health information.',
      user: false,
    ),
  ];
  bool _open = false;
  Offset? _position;

  bool _sending = false;

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add((text: text, user: true));
      _sending = true;
    });
    _input.clear();
    _scrollToEnd();
    try {
      final history = _messages.skip(1).toList();
      final response = await ref
          .read(chatbotDioProvider)
          .post<Map<String, dynamic>>(
            '/api/patient/chatbot',
            data: {
              'messages': history
                  .skip(math.max(0, history.length - 12))
                  .map(
                    (m) => {
                      'role': m.user ? 'user' : 'assistant',
                      'content': m.text.length > 1000
                          ? m.text.substring(0, 1000)
                          : m.text,
                    },
                  )
                  .toList(),
            },
          );
      final reply = response.data?['data']?['reply'];
      if (reply is! String || reply.trim().isEmpty) {
        throw const FormatException();
      }
      if (mounted) setState(() => _messages.add((text: reply, user: false)));
    } catch (error) {
      if (!mounted) return;
      var message = 'Unable to reach the assistant. Please try again.';
      if (error is DioException) {
        final status = error.response?.statusCode;
        if (status == 401) message = 'Please sign in to use the AI assistant.';
        if (status == 503) message = 'The AI assistant is not available yet. Please contact your clinic or try again later.';
        if (status == 429) {
          message = 'Too many requests. Please wait before trying again.';
        }
      }
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(message)));
      _input.text = text;
      setState(() => _messages.removeLast());
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxX = math.max(0.0, constraints.maxWidth - 72);
        final minY = media.padding.top + 8;
        final maxY = math.max(
          minY,
          constraints.maxHeight -
              math.max(media.viewInsets.bottom, media.padding.bottom) -
              72,
        );
        final position = _position ?? Offset(maxX, math.max(minY, maxY - 90));
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (!_open)
              Positioned(
                left: position.dx.clamp(0.0, maxX),
                top: position.dy.clamp(minY, maxY),
                child: GestureDetector(
                  onPanUpdate: (details) => setState(() {
                    _position = Offset(
                      (position.dx + details.delta.dx).clamp(0.0, maxX),
                      (position.dy + details.delta.dy).clamp(minY, maxY),
                    );
                  }),
                  child: FloatingActionButton(
                    heroTag: null,
                    tooltip: 'Open Altrixs help chat. Drag to move.',
                    onPressed: () {
                      setState(() => _open = true);
                      _scrollToEnd();
                    },
                    child: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ),
              ),
            if (_open)
              Positioned.fill(
                child: BlockSemantics(
                  child: Material(
                    color: Colors.black38,
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          12,
                          12,
                          media.viewInsets.bottom + 12,
                        ),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: SizedBox(
                            width: 400,
                            height: 540,
                            child: Material(
                              color: Theme.of(context).colorScheme.surface,
                              elevation: 12,
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: const Icon(
                                      Icons.support_agent_rounded,
                                    ),
                                    title: const Text('Altrixs Help'),
                                    subtitle: const Text(
                                      'AI assistant • not medical advice',
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'Close chat',
                                      onPressed: () {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        setState(() => _open = false);
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: ListView.builder(
                                      controller: _scroll,
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _messages.length,
                                      itemBuilder: (context, index) {
                                        final message = _messages[index];
                                        return Align(
                                          alignment: message.user
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            constraints: const BoxConstraints(
                                              maxWidth: 310,
                                            ),
                                            decoration: BoxDecoration(
                                              color: message.user
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .primaryContainer
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Text(message.text),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        for (final topic in [
                                          'Appointments',
                                          'Join video visit',
                                          'Microphone help',
                                          'Contact clinic',
                                        ])
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: ActionChip(
                                              label: Text(topic),
                                              onPressed: _sending
                                                  ? null
                                                  : () => _send(topic),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _input,
                                            maxLength: 1000,
                                            textInputAction:
                                                TextInputAction.send,
                                            onSubmitted: (_) => _send(),
                                            decoration: const InputDecoration(
                                              hintText: 'Ask about the app…',
                                              counterText: '',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filled(
                                          tooltip: 'Send message',
                                          onPressed: _sending
                                              ? null
                                              : () => _send(),
                                          icon: _sending
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.send_rounded),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
