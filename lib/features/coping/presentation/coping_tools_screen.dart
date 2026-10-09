import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_colors.dart';
import '../data/coping_tools.dart';
import '../data/breathing_audio.dart';
import 'cognitive_distortions_screen.dart';

class CopingToolsScreen extends StatefulWidget {
  const CopingToolsScreen({super.key, this.audioFactory});
  final BreathingAudio Function()? audioFactory;
  @override
  State<CopingToolsScreen> createState() => _CopingToolsScreenState();
}

class _CopingToolsScreenState extends State<CopingToolsScreen> {
  String category = 'All';
  final completed = <int>{};
  final drafts = <int, Map<String, String>>{};
  final checks = <int, Set<int>>{};

  Future<void> open(Map<String, dynamic> tool) async {
    final id = tool['id'] as int;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => id == 3
            ? CognitiveDistortionsScreen(
                draft: drafts.putIfAbsent(id, () => {}),
                checked: checks.putIfAbsent(id, () => {}),
              )
            : _ExerciseScreen(
                tool: tool,
                audioFactory: widget.audioFactory,
                draft: drafts.putIfAbsent(id, () => {}),
                checked: checks.putIfAbsent(id, () => {}),
              ),
      ),
    );
    if (done == true && mounted) {
      setState(() => completed.add(id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Well done! Exercise completed.')),
      );
    }
  }

  Future<void> support(Uri uri) async {
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open your phone app. Dial 988 or text HOME to 741741.',
          ),
        ),
      );
    }
  }

  String? feeling;
  static const feelingTools = {
    'Anxious': [12, 14, 3],
    'Overwhelmed': [13, 7, 15],
    'Low mood': [2, 16, 9],
    'Need focus': [13, 17, 5],
  };
  static const feelingIcons = {
    'Anxious': Icons.air_rounded,
    'Overwhelmed': Icons.waves_rounded,
    'Low mood': Icons.cloud_outlined,
    'Need focus': Icons.center_focus_strong_rounded,
  };

  Widget heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF686580), height: 1.4),
        ),
      ],
    ),
  );

  Widget card(Map<String, dynamic> tool, {bool compact = false}) {
    final color = _color(tool);
    final done = completed.contains(tool['id']);
    return Material(
      color: Color.lerp(Colors.white, color, .045),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => open(tool),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: .12)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Icon(
                        _toolIcon(tool['type']),
                        size: 27,
                        color: color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (done)
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.teal.shade700,
                    )
                  else
                    Icon(Icons.arrow_outward_rounded, size: 20, color: color),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                tool['title'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                compact ? tool['subtitle'] : tool['description'],
                style: const TextStyle(color: Color(0xFF686580), height: 1.45),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tool['category'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  Text(
                    '${tool['duration']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF686580),
                    ),
                  ),
                  if (done)
                    const Text(
                      'Practiced',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _toolIcon(String type) => switch (type) {
    'breathing' => Icons.air_rounded,
    'guided' => Icons.spa_outlined,
    'worksheet' => Icons.edit_note_rounded,
    'checklist' => Icons.fact_check_outlined,
    _ => Icons.self_improvement_rounded,
  };

  Widget featured() {
    final tool = copingTools.firstWhere((t) => t['id'] == 13);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6557CF), Color(0xFF8A79E6)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Color(0xFFE5DEFF),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'A MOMENT FOR YOU',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE5DEFF),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.air_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'A little space.\nA slower breath.',
            style: TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Settle into box breathing, one gentle cycle at a time.',
            style: TextStyle(color: Color(0xFFF0EBFF), height: 1.5),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6557CF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onPressed: () => open(tool),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start a breathing break'),
              ),
              const Text(
                '4 min · With sound',
                style: TextStyle(color: Color(0xFFF0EBFF), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = copingTools
        .where((t) => category == 'All' || t['category'] == category)
        .toList();
    final suggestions = feelingTools[feeling] ?? [3, 7, 14];
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FD),
      appBar: AppBar(
        title: const Text('Coping Tools'),
        backgroundColor: const Color(0xFFFAF9FD),
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                const Text(
                  'Find your calm.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Small practices. A little more room to feel like you.',
                  style: TextStyle(color: Color(0xFF686580), height: 1.5),
                ),
                heading(
                  'How are you feeling?',
                  'Choose what fits this moment. There’s no wrong answer.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: feelingTools.keys
                      .map(
                        (f) => ChoiceChip(
                          avatar: Icon(
                            feelingIcons[f],
                            size: 18,
                            color: feeling == f
                                ? AppColors.primary
                                : const Color(0xFF686580),
                          ),
                          label: Text(f),
                          selected: feeling == f,
                          selectedColor: const Color(0xFFEAE4FF),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: feeling == f
                                ? const Color(0xFFC6BAF3)
                                : AppColors.border,
                          ),
                          onSelected: (selected) =>
                              setState(() => feeling = selected ? f : null),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                featured(),
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EF),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.spa_outlined,
                          color: Color(0xFF28745B),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${completed.length} ${completed.length == 1 ? 'tool' : 'tools'} practiced this visit.\nEvery small moment counts.',
                            style: const TextStyle(
                              color: Color(0xFF28745B),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (category == 'All') ...[
                  heading(
                    feeling == null
                        ? 'A gentle place to start'
                        : 'For when you feel ${feeling!.toLowerCase()}',
                    'A few practices you might like to try.',
                  ),
                  // Wrap instead of a fixed-height carousel lets large text grow naturally.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 680 ? 3 : 1;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: suggestions
                            .map(
                              (id) => SizedBox(
                                width:
                                    (constraints.maxWidth -
                                        12 * (columns - 1)) /
                                    columns,
                                child: card(
                                  copingTools.firstWhere((t) => t['id'] == id),
                                  compact: true,
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
                heading(
                  'Your wellness toolkit',
                  'Explore at your own pace. Pick what works for you.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['All', 'CBT', 'DBT', 'Mindfulness']
                      .map(
                        (c) => ChoiceChip(
                          label: Text(c),
                          selected: category == c,
                          selectedColor: AppColors.primaryMuted,
                          onSelected: (_) => setState(() => category = c),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  '${visible.length} exercises',
                  style: const TextStyle(
                    color: Color(0xFF686580),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 560 ? 2 : 1;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: visible
                          .map(
                            (tool) => SizedBox(
                              width:
                                  (constraints.maxWidth - 14 * (columns - 1)) /
                                  columns,
                              child: card(tool),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E9),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFF0DCCB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.support_agent_rounded,
                        color: Color(0xFF9A5732),
                        size: 30,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'You don’t have to face it alone.',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Need immediate support? US crisis support is available 24/7.',
                        style: TextStyle(color: Color(0xFF795F4F), height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () =>
                            support(Uri(scheme: 'tel', path: '988')),
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('Call 988 — Crisis Lifeline'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => support(
                          Uri(
                            scheme: 'sms',
                            path: '741741',
                            queryParameters: {'body': 'HOME'},
                          ),
                        ),
                        icon: const Icon(Icons.message_outlined),
                        label: const Text('Text HOME to 741741'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _color(Map<String, dynamic> data) => Color(
  int.parse((data['color'] as String).replaceFirst('#', 'FF'), radix: 16),
);

class _ExerciseScreen extends StatefulWidget {
  const _ExerciseScreen({
    required this.tool,
    required this.draft,
    required this.checked,
    this.audioFactory,
  });
  final Map<String, dynamic> tool;
  final Map<String, String> draft;
  final Set<int> checked;
  final BreathingAudio Function()? audioFactory;
  @override
  State<_ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<_ExerciseScreen>
    with WidgetsBindingObserver {
  int step = 0, phase = 0, cycles = 0, seconds = 0;
  Timer? timer;
  bool running = false;
  bool soundEnabled = true;
  late final BreathingAudio audio =
      widget.audioFactory?.call() ?? BreathingAudio();

  void playPhase() {
    if (!soundEnabled || !running) return;
    final p = pattern[phase];
    unawaited(audio.play(p['phase'], p['seconds'], seconds));
  }

  final controllers = <String, TextEditingController>{};
  List<dynamic> get pattern => widget.tool['breathPattern'] ?? [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (pattern.isNotEmpty) seconds = pattern.first['seconds'];
    for (final field in widget.tool['worksheetFields'] ?? []) {
      final key = field['key'] as String;
      controllers[key] = TextEditingController(text: widget.draft[key]);
    }
  }

  void pause() {
    timer?.cancel();
    unawaited(audio.stop());
    if (mounted) setState(() => running = false);
  }

  void start() {
    if (running) return;
    setState(() => running = true);
    playPhase();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        seconds--;
        if (seconds == 0) {
          phase = (phase + 1) % pattern.length;
          if (phase == 0) cycles++;
          seconds = pattern[phase]['seconds'];
          playPhase();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) pause();
  }

  @override
  void dispose() {
    timer?.cancel();
    unawaited(audio.dispose());
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void complete() {
    pause();
    Navigator.of(context).pop(true);
  }

  Widget panel(String title, String body) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _color(widget.tool),
            ),
          ),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final steps = tool['steps'] as List<dynamic>?;
    final type = tool['type'];
    return Scaffold(
      backgroundColor: pattern.isNotEmpty
          ? const Color(0xFFF2EFFB)
          : AppColors.background,
      appBar: AppBar(
        title: Text(tool['title']),
        backgroundColor: pattern.isNotEmpty
            ? const Color(0xFFF2EFFB)
            : AppColors.background,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${tool['category']} · ${tool['subtitle']} · ${tool['duration']}',
                style: TextStyle(color: _color(tool)),
              ),
              const SizedBox(height: 12),
              Text(
                tool['description'],
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 20),
              if (steps != null) ...[
                LinearProgressIndicator(
                  value: (step + 1) / steps.length,
                  color: _color(tool),
                ),
                panel('Step ${step + 1} of ${steps.length}', steps[step]),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: step == 0
                          ? null
                          : () => setState(() => step--),
                      child: const Text('Back'),
                    ),
                    FilledButton(
                      onPressed: step == steps.length - 1
                          ? complete
                          : () => setState(() => step++),
                      child: Text(
                        step == steps.length - 1 ? 'Complete' : 'Next Step',
                      ),
                    ),
                  ],
                ),
              ],
              if (type == 'worksheet') ...[
                for (final field in tool['worksheetFields']) ...[
                  Text(
                    field['label'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controllers[field['key']],
                    minLines: field['multiline'] == true ? 3 : 1,
                    maxLines: field['multiline'] == true ? 6 : 1,
                    onChanged: (value) => widget.draft[field['key']] = value,
                    decoration: InputDecoration(
                      hintText: field['placeholder'],
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const Text(
                  'Responses stay available while this coping tools screen is open.',
                ),
              ],
              if (type == 'checklist') ...[
                const Text('Check any that applied to you today:'),
                for (
                  var i = 0;
                  i < (tool['checklistItems'] as List).length;
                  i++
                )
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tool['checklistItems'][i]),
                    value: widget.checked.contains(i),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        widget.checked.add(i);
                      } else {
                        widget.checked.remove(i);
                      }
                    }),
                  ),
                Text('${widget.checked.length} selected'),
              ],
              if (type == 'dbt')
                for (final skill in tool['dbtSkills'])
                  panel(skill['skill'], skill['description']),
              if (pattern.isNotEmpty) ...[
                const Center(
                  child: Text(
                    'One breath at a time.',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Follow the circle. Let the rest wait.',
                    style: TextStyle(color: Color(0xFF686580)),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Breathing sounds'),
                  subtitle: const Text(
                    'Inhale and exhale audio; silent during holds',
                  ),
                  value: soundEnabled,
                  onChanged: (enabled) {
                    setState(() => soundEnabled = enabled);
                    if (enabled) {
                      playPhase();
                    } else {
                      unawaited(audio.stop());
                    }
                  },
                ),
                Center(
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 900),
                    width: running && pattern[phase]['phase'] != 'Breathe Out'
                        ? 230
                        : 180,
                    height: running && pattern[phase]['phase'] != 'Breathe Out'
                        ? 230
                        : 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white,
                          _color(pattern[phase]).withValues(alpha: .18),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _color(pattern[phase]).withValues(alpha: .13),
                          blurRadius: 40,
                          spreadRadius: 16,
                        ),
                      ],
                      border: Border.all(
                        color: _color(pattern[phase]),
                        width: 3,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          pattern[phase]['phase'],
                          style: const TextStyle(fontSize: 22),
                        ),
                        Text(
                          '$seconds',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(child: Text('Cycles: $cycles')),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    for (final p in pattern)
                      Chip(label: Text('${p['phase']} ${p['seconds']}s')),
                  ],
                ),
                FilledButton.icon(
                  onPressed: running ? pause : start,
                  icon: Icon(running ? Icons.pause : Icons.play_arrow),
                  label: Text(running ? 'Pause' : 'Start Breathing'),
                ),
                TextButton(
                  onPressed: () {
                    pause();
                    setState(() {
                      phase = 0;
                      cycles = 0;
                      seconds = pattern.first['seconds'];
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
              if (steps == null)
                FilledButton(
                  onPressed: complete,
                  child: Text(
                    type == 'worksheet'
                        ? 'Complete Worksheet'
                        : type == 'dbt'
                        ? 'I Practiced This'
                        : 'Complete',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
