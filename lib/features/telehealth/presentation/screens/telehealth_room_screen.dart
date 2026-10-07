import 'package:flutter/material.dart';

import '../../../patient/data/models/patient_models.dart';
import 'telehealth_waiting_room_screen.dart';

/// Retains the appointment entry point while using the Chime waiting room.
class TelehealthRoomScreen extends StatelessWidget {
  const TelehealthRoomScreen({
    super.key,
    required this.joinToken,
    this.appointment,
  });
  final String joinToken;
  final AppointmentModel? appointment;
  @override
  Widget build(BuildContext context) =>
      TelehealthWaitingRoomScreen(joinToken: joinToken);
}
