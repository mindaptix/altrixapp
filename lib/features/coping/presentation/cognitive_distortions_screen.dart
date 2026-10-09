import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class CognitiveDistortionsScreen extends StatefulWidget {
  const CognitiveDistortionsScreen({
    super.key,
    required this.checked,
    required this.draft,
  });
  final Set<int> checked;
  final Map<String, String> draft;

  @override
  State<CognitiveDistortionsScreen> createState() =>
      _CognitiveDistortionsScreenState();
}

class _CognitiveDistortionsScreenState
    extends State<CognitiveDistortionsScreen> {
  bool _noticedOnly = false;
  final _revealed = <int>{};
  late final _thought = TextEditingController(
    text: widget.draft['distortion_thought'],
  );
  late final _reframe = TextEditingController(
    text: widget.draft['distortion_reframe'],
  );

  @override
  void dispose() {
    _thought.dispose();
    _reframe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _patterns.indexed
        .where((entry) => !_noticedOnly || widget.checked.contains(entry.$1))
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      appBar: AppBar(
        title: const Text('Cognitive Distortions'),
        backgroundColor: const Color(0xFFF7F6FC),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _hero(),
              const SizedBox(height: 24),
              const Text(
                'Meet your thinking patterns',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Explore an example, try another perspective, and mark anything that feels familiar today.',
                style: TextStyle(color: Color(0xFF6E6B86), height: 1.5),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All patterns'),
                    selected: !_noticedOnly,
                    onSelected: (_) => setState(() => _noticedOnly = false),
                  ),
                  ChoiceChip(
                    label: Text('Noticed today · ${widget.checked.length}'),
                    selected: _noticedOnly,
                    onSelected: (_) => setState(() => _noticedOnly = true),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        size: 34,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Nothing marked yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Explore All patterns and mark what feels familiar. There is no right number to choose.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 650 ? 2 : 1;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final entry in items)
                        SizedBox(
                          width:
                              (constraints.maxWidth - 16 * (columns - 1)) /
                              columns,
                          child: _patternCard(entry.$1, entry.$2),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              _reflection(),
              const SizedBox(height: 18),
              const Text(
                'These are patterns to explore, not labels for who you are. A different perspective does not have to be positive—just fairer to the facts.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6E6B86),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Finish reflection'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF272044), Color(0xFF51408A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Stack(
      children: [
        const Positioned(
          right: -25,
          top: -28,
          width: 190,
          height: 190,
          child: IgnorePointer(child: CustomPaint(painter: _LensPainter())),
        ),
        Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'THINKING LENS  ·  5–10 MIN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Color(0xFFE1D7FF),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Your thoughts.\nA wider perspective.',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Notice the pattern. Give yourself room to see things differently.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE1D7FF),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final step in [
                    '01  Notice',
                    '02  Reflect',
                    '03  Reframe',
                  ])
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .2),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        step,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _patternCard(int index, _ThinkingPattern pattern) {
    final noticed = widget.checked.contains(index);
    final revealed = _revealed.contains(index);
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: noticed ? pattern.color : const Color(0xFFE7E4F1),
          width: noticed ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: pattern.color.withValues(alpha: .045),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: pattern.color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(pattern.icon, color: pattern.color, size: 26),
              ),
              const Spacer(),
              Text(
                '${index + 1}'.padLeft(2, '0'),
                style: const TextStyle(
                  color: Color(0xFFA7A0B9),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            pattern.title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pattern.description,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6E6B86),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: revealed
                  ? pattern.color.withValues(alpha: .08)
                  : const Color(0xFFF5F4F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        revealed
                            ? Icons.auto_awesome_outlined
                            : Icons.format_quote_rounded,
                        size: 16,
                        color: pattern.color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          revealed
                              ? 'ANOTHER PERSPECTIVE'
                              : 'A THOUGHT MIGHT SOUND LIKE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .7,
                            color: pattern.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    revealed ? pattern.reframe : '“${pattern.example}”',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (revealed) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      pattern.question,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: pattern.color,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: ValueKey('reframe-$index'),
            onPressed: () => setState(() {
              revealed ? _revealed.remove(index) : _revealed.add(index);
            }),
            icon: Icon(
              revealed ? Icons.undo_rounded : Icons.swap_horiz_rounded,
              size: 18,
            ),
            label: Text(
              revealed ? 'Back to example' : 'See another perspective',
            ),
            style: TextButton.styleFrom(
              foregroundColor: pattern.color,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            ),
          ),
          const Divider(),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              key: ValueKey('notice-$index'),
              value: noticed,
              onChanged: (value) => setState(() {
                value == true
                    ? widget.checked.add(index)
                    : widget.checked.remove(index);
              }),
              title: Text(
                noticed ? 'Noticed today' : 'I noticed this today',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: noticed ? pattern.color : const Color(0xFF6E6B86),
                ),
              ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: pattern.color,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reflection() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFFEDE8F8),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.edit_note_rounded, size: 32, color: Color(0xFF6851A3)),
        const SizedBox(height: 12),
        const Text(
          'Try it with your own thought',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Optional. What could a more balanced version sound like?',
          style: TextStyle(color: Color(0xFF6E6B86), height: 1.5),
        ),
        const SizedBox(height: 18),
        TextField(
          key: const ValueKey('personal-thought'),
          controller: _thought,
          onChanged: (value) => widget.draft['distortion_thought'] = value,
          minLines: 2,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'The thought I noticed',
            hintText: 'What went through your mind?',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('personal-reframe'),
          controller: _reframe,
          onChanged: (value) => widget.draft['distortion_reframe'] = value,
          minLines: 2,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'A fairer perspective',
            hintText: 'What facts or possibilities am I missing?',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your reflection stays available while this toolkit is open.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6E6B86), height: 1.5),
        ),
      ],
    ),
  );
}

class _LensPainter extends CustomPainter {
  const _LensPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .55, size.height * .45);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (final radius in [.23, .34, .45]) {
      canvas.drawCircle(
        center,
        size.width * radius,
        paint..color = Colors.white.withValues(alpha: .13),
      );
    }
    canvas.drawCircle(
      center + const Offset(-22, 18),
      30,
      Paint()..color = const Color(0xFFA38BD7).withValues(alpha: .12),
    );
    canvas.drawCircle(
      center + const Offset(20, -15),
      3,
      Paint()..color = const Color(0xFFD9C8FF),
    );
  }

  @override
  bool shouldRepaint(covariant _LensPainter oldDelegate) => false;
}

class _ThinkingPattern {
  const _ThinkingPattern(
    this.title,
    this.description,
    this.example,
    this.reframe,
    this.question,
    this.icon,
    this.color,
  );
  final String title, description, example, reframe, question;
  final IconData icon;
  final Color color;
}

// Order matches the original checklist so existing session selections carry over.
const _patterns = [
  _ThinkingPattern(
    'All-or-Nothing Thinking',
    'Seeing only two extremes, with no room in between.',
    'If it is not perfect, I have failed.',
    'Something can be imperfect and still be worthwhile. One result does not define the whole effort.',
    'What would the middle ground look like?',
    Icons.contrast_rounded,
    Color(0xFF7656B5),
  ),
  _ThinkingPattern(
    'Catastrophizing',
    'Jumping from uncertainty to the worst possible outcome.',
    'This mistake will ruin everything.',
    'I do not know the outcome yet. I can consider several possibilities and one manageable next step.',
    'What else could happen besides the worst case?',
    Icons.thunderstorm_outlined,
    Color(0xFF5975A6),
  ),
  _ThinkingPattern(
    'Mind Reading',
    'Treating a guess about someone’s thoughts as a fact.',
    'They did not reply. They must be upset with me.',
    'A delayed reply could mean many things. I can ask instead of assuming.',
    'What do I know, and what am I guessing?',
    Icons.theater_comedy_outlined,
    Color(0xFFAF628D),
  ),
  _ThinkingPattern(
    'Fortune Telling',
    'Predicting a negative future as if it is already certain.',
    'I know the interview will go badly.',
    'The interview has not happened yet. I can prepare without deciding the ending in advance.',
    'Am I predicting, or describing something that happened?',
    Icons.explore_outlined,
    Color(0xFF557FA1),
  ),
  _ThinkingPattern(
    'Mental Filter',
    'Zooming in on the negative and losing the wider picture.',
    'One person criticized my work, so it was terrible.',
    'That criticism is one part of the feedback. I can also consider what went well.',
    'What parts of the picture have I left out?',
    Icons.filter_alt_outlined,
    Color(0xFF4D9186),
  ),
  _ThinkingPattern(
    'Disqualifying the Positive',
    'Dismissing good moments or achievements as not counting.',
    'The compliment does not count. They were just being nice.',
    'I can let the compliment count without needing to prove that everything is perfect.',
    'Would I dismiss the same achievement in a friend?',
    Icons.wb_sunny_outlined,
    Color(0xFFA17C35),
  ),
  _ThinkingPattern(
    'Should Statements',
    'Putting rigid rules on yourself or other people.',
    'I should always be able to cope without help.',
    'I would like to cope well, and I can still need support. A preference does not have to become a rule.',
    'Could I replace “should” with “I would prefer”?',
    Icons.rule_rounded,
    Color(0xFF8765B0),
  ),
  _ThinkingPattern(
    'Labeling',
    'Turning one action or experience into a label for your whole self.',
    'I made a mistake. I am a failure.',
    'I made a mistake in this situation. That describes an event, not everything about me.',
    'Can I describe what happened without labeling myself?',
    Icons.sell_outlined,
    Color(0xFFAF7060),
  ),
  _ThinkingPattern(
    'Magnification',
    'Making a problem feel larger than the full context supports.',
    'That awkward moment was a complete disaster.',
    'The moment felt uncomfortable. I can look at its actual impact before deciding how big it was.',
    'How might this look with a little more distance?',
    Icons.zoom_in_rounded,
    Color(0xFF687DA6),
  ),
  _ThinkingPattern(
    'Emotional Reasoning',
    'Using a feeling as the only evidence that something is true.',
    'I feel inadequate, so I must be incapable.',
    'The feeling is real. It is still only one part of the information about what I can do.',
    'What evidence would I notice if I felt differently?',
    Icons.favorite_border_rounded,
    Color(0xFFAD6380),
  ),
  _ThinkingPattern(
    'Personalization',
    'Taking all the responsibility for things outside your control.',
    'My friend is quiet today. I must have done something wrong.',
    'Their mood may involve things I know nothing about. I can check in without taking all the blame.',
    'Which parts were actually within my control?',
    Icons.backpack_outlined,
    Color(0xFF568C78),
  ),
  _ThinkingPattern(
    'Overgeneralization',
    'Turning one event into an “always” or “never” story.',
    'This plan did not work. Nothing ever works out for me.',
    'This particular plan did not work today. Other experiences may tell a different story.',
    'Is there an exception to this “always” or “never”?',
    Icons.all_inclusive_rounded,
    Color(0xFF9B7C48),
  ),
];
