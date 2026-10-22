import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/telehealth_repository.dart';
import '../widgets/chime_media_view.dart';
import 'chime_video_theater_screen.dart';

class TelehealthWaitingRoomScreen extends ConsumerStatefulWidget {
  const TelehealthWaitingRoomScreen({
    super.key,
    required this.joinToken,
    this.videoCallBuilder,
  });
  final String joinToken;

  @visibleForTesting
  final Widget Function(Map<String, dynamic> chimeData, String doctorName)?
  videoCallBuilder;
  @override
  ConsumerState<TelehealthWaitingRoomScreen> createState() =>
      _WaitingRoomState();
}

class _WaitingRoomState extends ConsumerState<TelehealthWaitingRoomScreen> {
  final _media = GlobalKey<ChimeMediaViewState>();
  Map<String, dynamic>? _details;
  String? _error;
  bool _busy = false, _checkedIn = false;
  String? _visibleSnackBarMessage;
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
    } on TelehealthSessionEndedException {
      if (context.mounted) {
        setState(() => _error = 'Telehealth video has ended.');
        _showErrorSnackBar('Telehealth video has ended.');
      }
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
        if (!mounted || !context.mounted) return;
        final doctorName =
            _details?['clinicianName']?.toString() ?? 'Your doctor';
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                widget.videoCallBuilder?.call(data, doctorName) ??
                ChimeVideoTheaterScreen(
                  chimeData: data,
                  doctorName: doctorName,
                ),
          ),
        );
        if (mounted) await _media.currentState?.restart();
      } else {
        await repo.here(widget.joinToken);
        if (mounted) setState(() => _checkedIn = true);
      }
    } catch (error) {
      if (context.mounted) {
        if (join) {
          _showErrorSnackBar(_joinErrorMessage(error));
        } else {
          setState(() => _error = 'Check-in failed. Please try again.');
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _joinErrorMessage(Object error) {
    if (error is TelehealthSessionEndedException) {
      return 'Session ended. You can no longer join this call.';
    }
    if (error is TelehealthNetworkException ||
        (error is DioException && _isConnectionFailure(error))) {
      return 'Please check your internet connection.';
    }
    if (error is FormatException &&
        error.message == 'The visit is not ready. Please try again.') {
      return 'The visit is not ready. Please try again.';
    }
    return 'Unable to join the call. Please try again.';
  }

  bool _isConnectionFailure(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      _ => false,
    };
  }

  void _showErrorSnackBar(String message) {
    if (!context.mounted || _visibleSnackBarMessage == message) return;
    _visibleSnackBarMessage = message;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
    controller.closed.whenComplete(() {
      if (_visibleSnackBarMessage == message) {
        _visibleSnackBarMessage = null;
      }
    });
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
