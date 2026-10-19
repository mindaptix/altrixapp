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
      text: 'Hi! I’m Aria. Ask me about appointments, messages, or video visits. I’m an AI assistant, not your clinician. Messages you send are processed by Groq. Avoid sharing sensitive health information.',
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
        final launcherWidth = math.min(148.0, constraints.maxWidth - 24);
        const launcherHeight = 58.0;
        final maxX = math.max(12.0, constraints.maxWidth - launcherWidth - 12);
        final minY = media.padding.top + 8;
        final maxY = math.max(
          minY,
          constraints.maxHeight -
              math.max(media.viewInsets.bottom, media.padding.bottom) -
              launcherHeight -
              12,
        );
        final position = _position ?? Offset(maxX, math.max(minY, maxY - 74));
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
                      (position.dx + details.delta.dx).clamp(12.0, maxX),
                      (position.dy + details.delta.dy).clamp(minY, maxY),
                    );
                  }),
                  child: Semantics(
                    button: true,
                    label: 'Open Aria. Drag to move.',
                    child: Material(
                      color: const Color(0xFF6D35D5),
                      elevation: 10,
                      shadowColor: const Color(0xFF6D35D5)
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(30),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          setState(() => _open = true);
                          _scrollToEnd();
                        },
                        child: SizedBox(
                          width: launcherWidth,
                          height: launcherHeight,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 13),
                            child: Row(
                              children: [
                                _AriaLauncherIcon(),
                                SizedBox(width: 9),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Aria',
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 7),
                                _AriaStatusBadge(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_open)
              Positioned.fill(
                child: BlockSemantics(
                  child: Material(
                    color: Colors.black45,
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          constraints.maxWidth < 600 ? 0 : 12,
                          constraints.maxWidth < 600 ? 0 : 12,
                          constraints.maxWidth < 600 ? 0 : 12,
                          media.viewInsets.bottom +
                              (constraints.maxWidth < 600 ? 0 : 12),
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Material(
                              color: const Color(0xFFF8FAFC),
                              elevation: 12,
                              borderRadius: BorderRadius.circular(
                                constraints.maxWidth < 600 ? 0 : 24,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  _AriaPanelHeader(
                                    onClose: () {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      setState(() => _open = false);
                                    },
                                  ),
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
                                                  ? const Color(0xFFEDE9FE)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: message.user
                                                    ? const Color(0xFFC4B5FD)
                                                    : const Color(0xFFE2E8F0),
                                              ),
                                              boxShadow: message.user
                                                  ? null
                                                  : const [
                                                      BoxShadow(
                                                        color: Color(
                                                          0x0A0F172A,
                                                        ),
                                                        blurRadius: 8,
                                                        offset: Offset(0, 3),
                                                      ),
                                                    ],
                                            ),
                                            child: Text(
                                              message.text,
                                              style: const TextStyle(
                                                color: Color(0xFF1E293B),
                                                height: 1.45,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  _AriaComposer(
                                    controller: _input,
                                    sending: _sending,
                                    onSend: _send,
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

class _AriaPanelHeader extends StatelessWidget {
  const _AriaPanelHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF172554), Color(0xFF3B0764)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Color(0xFFC4B5FD),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Aria Wellness Companion',
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'AI wellness support • not medical advice',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFFB8B5D1), fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close chat',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Color(0xFFC4B5FD)),
          ),
        ],
      ),
    );
  }
}

class _AriaComposer extends StatelessWidget {
  const _AriaComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function([String? suggestion]) onSend;

  @override
  Widget build(BuildContext context) {
    const prompts = [
      'I am feeling anxious',
      'Guide me through breathing',
      'Help with my appointment',
      'How do I join a video visit?',
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QUICK PROMPTS',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Row(
                children: [
                  for (var index = 0; index < prompts.length; index++) ...[
                    ActionChip(
                      label: Text(prompts[index]),
                      labelStyle: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      visualDensity: VisualDensity.compact,
                      onPressed: sending ? null : () => onSend(prompts[index]),
                    ),
                    if (index != prompts.length - 1) const SizedBox(width: 7),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLength: 1000,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: 'Message Aria…',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send message',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: sending ? null : () => onSend(),
                  icon: sending
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AriaLauncherIcon extends StatelessWidget {
  const _AriaLauncherIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.smart_toy_outlined,
            size: 19,
            color: Colors.white,
          ),
        ),
        Positioned(
          right: -1,
          top: -1,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6D35D5), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _AriaStatusBadge extends StatelessWidget {
  const _AriaStatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: const Text(
        'AI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
