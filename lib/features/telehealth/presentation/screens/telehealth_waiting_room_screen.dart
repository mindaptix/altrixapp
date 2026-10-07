import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/telehealth_repository.dart';
import '../widgets/chime_media_view.dart';
import 'chime_video_theater_screen.dart';

class TelehealthWaitingRoomScreen extends ConsumerStatefulWidget {
  const TelehealthWaitingRoomScreen({super.key, required this.joinToken});
  final String joinToken;
  @override
  ConsumerState<TelehealthWaitingRoomScreen> createState() =>
      _WaitingRoomState();
}

class _WaitingRoomState extends ConsumerState<TelehealthWaitingRoomScreen> {
  final _media = GlobalKey<ChimeMediaViewState>();
  Map<String, dynamic>? _details;
  String? _error;
  bool _busy = false, _checkedIn = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final details = await ref
          .read(telehealthRepositoryProvider)
          .details(widget.joinToken);
      if (mounted) setState(() => _details = details);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Unable to load this visit. The link may have expired.',
        );
      }
    }
  }

  Future<void> _action(bool join) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(telehealthRepositoryProvider);
      if (join) {
        final data = await repo.join(widget.joinToken);
        await _media.currentState?.stop();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChimeVideoTheaterScreen(
              chimeData: data,
              doctorName:
                  _details?['clinicianName']?.toString() ?? 'Your doctor',
            ),
          ),
        );
        if (mounted) await _media.currentState?.restart();
      } else {
        await repo.here(widget.joinToken);
        if (mounted) setState(() => _checkedIn = true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = join
              ? 'Unable to join. Your doctor may not have started the visit yet. Please retry.'
              : 'Check-in failed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Telehealth waiting room')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_details == null && _error == null)
          const Center(child: CircularProgressIndicator()),
        if (_details != null) ...[
          Text(
            'Welcome, ${_details!['clientName'] ?? 'Patient'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            '${_details!['clinicianName'] ?? 'Your doctor'} · ${_details!['date'] ?? ''} ${_details!['startTime'] ?? ''}',
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ChimeMediaView(key: _media),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Check your camera and speak to test your microphone. The green meter responds to your voice.',
          ),
          const SizedBox(height: 20),
          if (_checkedIn)
            const Text(
              "You're checked in! Your doctor will begin shortly.",
              style: TextStyle(color: Color(0xFF059669)),
            ),
          FilledButton.tonal(
            onPressed: _busy || _checkedIn ? null : () => _action(false),
            child: Text(_checkedIn ? 'Checked in' : "I'm Here / Check In"),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _action(true),
            child: Text(_busy ? 'Please wait…' : 'Join Video Call Now'),
          ),
          if (_details!['chimeReady'] != true)
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Refresh doctor availability'),
            ),
        ],
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_details == null)
            TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ],
    ),
  );
}
