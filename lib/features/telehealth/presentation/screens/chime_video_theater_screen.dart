import 'package:flutter/material.dart';

import '../widgets/chime_media_view.dart';

class ChimeVideoTheaterScreen extends StatefulWidget {
  const ChimeVideoTheaterScreen({
    super.key,
    required this.chimeData,
    this.doctorName = 'Your doctor',
  });
  final Map<String, dynamic> chimeData;
  final String doctorName;
  @override
  State<ChimeVideoTheaterScreen> createState() => _TheaterState();
}

class _TheaterState extends State<ChimeVideoTheaterScreen> {
  final _media = GlobalKey<ChimeMediaViewState>();
  bool _connected = false, _leaving = false;
  Future<void> _end() async {
    if (_leaving) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End video call?'),
        content: const Text('You can rejoin from the waiting room.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End call'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      await _media.currentState?.stop();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _command(String value) async {
    await _media.currentState?.command(value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _end();
    },
    child: Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _connected ? Colors.greenAccent : Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_connected ? 'LIVE' : 'CONNECTING'} · ${widget.doctorName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'AWS Chime · us-east-1 · HD Audio',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ChimeMediaView(
                key: _media,
                chimeData: widget.chimeData,
                onChanged: () {
                  if (mounted) setState(() {});
                },
                onConnected: () {
                  if (mounted) setState(() => _connected = true);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Mute / unmute microphone',
                    color: _media.currentState?.muted == true
                        ? Colors.amber
                        : null,
                    onPressed: () => _command('mic'),
                    icon: Icon(
                      _media.currentState?.muted == true
                          ? Icons.mic_off
                          : Icons.mic,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Camera on / off',
                    onPressed: () => _command('camera'),
                    icon: Icon(
                      _media.currentState?.cameraOn == false
                          ? Icons.videocam_off
                          : Icons.videocam,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Switch camera',
                    onPressed: () => _command('switch'),
                    icon: const Icon(Icons.cameraswitch),
                  ),
                  IconButton.filled(
                    tooltip: 'End call',
                    style: IconButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _leaving ? null : _end,
                    icon: const Icon(Icons.call_end),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
