import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive/responsive.dart';
import '../core/responsive/responsive_widgets.dart';
import '../features/patient/data/models/patient_models.dart';
import '../features/patient/presentation/providers/patient_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/appointment_actions.dart';
import '../features/patient/presentation/screens/appointment_editor_screen.dart';
import '../features/patient/presentation/widgets/appointment_management_actions.dart';
import '../widgets/empty_state_card.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = context.responsive;
    final appointmentsAsync = ref.watch(appointmentsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const _ScheduleBackground(),
            SafeArea(
              child: ResponsiveCenter(
                child: appointmentsAsync.when(
                  loading: () => ListView(
                    padding: responsive.pagePadding.copyWith(
                      top: responsive.rz(12),
                      bottom: responsive.rz(32),
                    ),
                    children: const [
                      _ScheduleHeader(totalAppointments: 0),
                      SizedBox(height: 24),
                      InlineLoadingCard(label: 'Loading your appointments...'),
                    ],
                  ),
                  error: (error, _) => ListView(
                    padding: responsive.pagePadding.copyWith(
                      top: responsive.rz(12),
                      bottom: responsive.rz(32),
                    ),
                    children: [
                      const _ScheduleHeader(totalAppointments: 0),
                      SizedBox(height: responsive.rz(18)),
                      InlineErrorCard(
                        message: friendlyErrorMessage(error),
                        onRetry: () => ref.invalidate(appointmentsProvider),
                      ),
                    ],
                  ),
                  data: (appointments) => RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(appointmentsProvider);
                      try {
                        await ref.read(appointmentsProvider.future);
                      } catch (_) {
                        // The provider renders the refresh error with a retry action.
                      }
                    },
                    child: ListView(
                      padding: responsive.pagePadding.copyWith(
                        top: responsive.rz(12),
                        bottom: responsive.rz(32),
                      ),
                      children: [
                        _ScheduleHeader(totalAppointments: appointments.length),
                        SizedBox(height: responsive.rz(20)),
                        if (appointments.isNotEmpty) ...[
                          _ScheduleSummaryCard(appointments: appointments),
                          SizedBox(height: responsive.rz(24)),
                          _SectionTitle(
                            title: 'Scheduled visits',
                            subtitle:
                                'Manage your visits or join your video session',
                          ),
                          SizedBox(height: responsive.rz(14)),
                          for (var i = 0; i < appointments.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: responsive.rz(14),
                              ),
                              child: _AppointmentCard(
                                appointment: appointments[i],
                                isNext: i == 0,
                              ),
                            ),
                        ] else
                          const EmptyStateCard(
                            title: 'No appointments yet',
                            message: 'When you book a visit, it will appear here with date, provider, and join details.',
                            icon: Icons.event_busy_outlined,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleBackground extends StatelessWidget {
  const _ScheduleBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 300,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primaryWash.withValues(alpha: 0.38),
                  AppColors.background.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -40,
          right: -30,
          child: _GlowOrb(
            size: 140,
            color: AppColors.primary.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          top: 80,
          left: -50,
          child: _GlowOrb(
            size: 110,
            color: AppColors.primarySoft.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({required this.totalAppointments});

  final int totalAppointments;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your schedule',
                style: responsiveTextStyle(
                  context,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.6,
                  height: 1.05,
                ),
              ),
              SizedBox(height: responsive.rz(6)),
              Text(
                'All your appointments',
                style: responsiveTextStyle(
                  context,
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.rz(12),
            vertical: responsive.rz(8),
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: responsive.rz(16),
                color: AppColors.primary,
              ),
              SizedBox(width: responsive.rz(6)),
              Text(
                '$totalAppointments',
                style: responsiveTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        SizedBox(height: responsive.rz(16)),
        FilledButton.icon(
          onPressed: () => openAppointmentEditor(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Book appointment'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: responsiveTextStyle(
            context,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: responsive.rz(4)),
        Text(
          subtitle,
          style: responsiveTextStyle(
            context,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ScheduleSummaryCard extends StatelessWidget {
  const _ScheduleSummaryCard({required this.appointments});

  final List<AppointmentModel> appointments;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final virtual = appointments.where((item) => item.isVirtual).length;
    final inPerson = appointments.length - virtual;

    return Container(
      padding: EdgeInsets.all(responsive.rz(18)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(responsive.rz(24)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12103A), Color(0xFF1C1858), Color(0xFF221A6A)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.rz(10)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: responsive.rz(22),
                ),
              ),
              SizedBox(width: responsive.rz(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${appointments.length} upcoming visit${appointments.length == 1 ? '' : 's'}',
                      style: responsiveTextStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: responsive.rz(2)),
                    Text(
                      'Stay on track with your care plan',
                      style: responsiveTextStyle(
                        context,
                        fontSize: 13,
                        color: const Color(0xFFD8D6F0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.rz(18)),
          Row(
            children: [
              Expanded(
                child: _SummaryStatTile(
                  icon: Icons.videocam_rounded,
                  label: 'Virtual',
                  value: '$virtual',
                  color: const Color(0xFF8B83F6),
                ),
              ),
              SizedBox(width: responsive.rz(10)),
              Expanded(
                child: _SummaryStatTile(
                  icon: Icons.location_on_rounded,
                  label: 'In person',
                  value: '$inPerson',
                  color: AppColors.mood5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStatTile extends StatelessWidget {
  const _SummaryStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.rz(12),
        vertical: responsive.rz(12),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: responsive.rz(34),
            height: responsive.rz(34),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: responsive.rz(18)),
          ),
          SizedBox(width: responsive.rz(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: responsiveTextStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: responsiveTextStyle(
                    context,
                    fontSize: 11,
                    color: const Color(0xFFC4C0EA),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, this.isNext = false});

  final AppointmentModel appointment;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final dateParts = _AppointmentDateParts.from(appointment);
    final accentColor = appointment.isVirtual
        ? AppColors.primary
        : AppColors.mood5;
    final statusStyle = appointment.isDeclinedByDoctor
        ? const _StatusStyle(
            label: 'Declined by Doctor',
            background: Color(0xFFFFE4E6),
            foreground: Color(0xFFBE123C),
          )
        : _statusStyle(appointment.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(responsive.rz(22)),
        child: Ink(
          decoration: BoxDecoration(
            color: isNext
                ? accentColor.withValues(alpha: 0.05)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(responsive.rz(22)),
            border: Border.all(
              color: isNext
                  ? accentColor.withValues(alpha: 0.28)
                  : AppColors.border.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(responsive.rz(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNext)
                  Padding(
                    padding: EdgeInsets.only(bottom: responsive.rz(12)),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.rz(10),
                        vertical: responsive.rz(5),
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: responsive.rz(14),
                            color: accentColor,
                          ),
                          SizedBox(width: responsive.rz(4)),
                          Text(
                            'Next up',
                            style: responsiveTextStyle(
                              context,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DateBadge(dateParts: dateParts, accentColor: accentColor),
                    SizedBox(width: responsive.rz(14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.title,
                            style: responsiveTextStyle(
                              context,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: responsive.rz(8)),
                          _StatusBadge(style: statusStyle),
                          SizedBox(height: responsive.rz(8)),
                          _InfoRow(
                            icon: Icons.person_outline_rounded,
                            text: appointment.providerName.isNotEmpty
                                ? appointment.providerName
                                : 'Your care team',
                          ),
                          SizedBox(height: responsive.rz(6)),
                          _InfoRow(
                            icon: appointment.isVirtual
                                ? Icons.videocam_rounded
                                : Icons.location_on_outlined,
                            text: appointment.subtitleLine,
                          ),
                          if (appointment.timeLabel.isNotEmpty) ...[
                            SizedBox(height: responsive.rz(6)),
                            _InfoRow(
                              icon: Icons.schedule_rounded,
                              text: _timeLine(appointment),
                            ),
                          ],
                          if (appointment.location.isNotEmpty) ...[
                            SizedBox(height: responsive.rz(6)),
                            _InfoRow(
                              icon: Icons.place_outlined,
                              text: appointment.location,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (appointment.isDeclinedByDoctor) ...[
                  SizedBox(height: responsive.rz(12)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(responsive.rz(12)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFCCD5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reason from your doctor',
                          style: TextStyle(
                            color: Color(0xFF9F1239),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: responsive.rz(5)),
                        Text(
                          appointment.declineReason,
                          style: responsiveTextStyle(
                            context,
                            fontSize: 12,
                            color: const Color(0xFF881337),
                          ),
                        ),
                        SizedBox(height: responsive.rz(10)),
                        OutlinedButton.icon(
                          onPressed: () => openAppointmentEditor(context),
                          icon: const Icon(Icons.event_repeat_rounded, size: 18),
                          label: const Text('Rebook Slot'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFBE123C),
                            side: const BorderSide(color: Color(0xFFFDA4AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (appointment.note.isNotEmpty &&
                    !appointment.isDeclinedByDoctor) ...[
                  SizedBox(height: responsive.rz(12)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(responsive.rz(12)),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      appointment.note,
                      style: responsiveTextStyle(
                        context,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (appointment.isVirtual &&
                    appointment.hasJoinLink &&
                    appointment.canJoinMeeting()) ...[
                  SizedBox(height: responsive.rz(14)),
                  SizedBox(
                    width: double.infinity,
                    height: responsive.rz(46),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B83F6), AppColors.primary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: () =>
                            openAppointmentJoin(context, appointment),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.videocam_rounded, size: 18),
                        label: const Text(
                          'Join visit',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ] else if (!appointment.isVirtual &&
                    appointment.location.isNotEmpty) ...[
                  SizedBox(height: responsive.rz(14)),
                  OutlinedButton.icon(
                    onPressed: () =>
                        openAppointmentDirections(context, appointment),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, responsive.rz(44)),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primarySoft),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.near_me_rounded, size: 18),
                    label: const Text(
                      'Get directions',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                AppointmentManagementActions(appointment: appointment),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.dateParts, required this.accentColor});

  final _AppointmentDateParts dateParts;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      width: responsive.rz(58),
      padding: EdgeInsets.symmetric(vertical: responsive.rz(10)),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            dateParts.month,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            dateParts.day,
            style: responsiveTextStyle(
              context,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          Text(
            dateParts.weekday,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.iconMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.style});

  final _StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: style.foreground,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _AppointmentDateParts {
  const _AppointmentDateParts({
    required this.month,
    required this.day,
    required this.weekday,
  });

  final String month;
  final String day;
  final String weekday;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  static const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  factory _AppointmentDateParts.from(AppointmentModel appointment) {
    final date = appointment.sortDateTime;
    if (date != null) {
      return _AppointmentDateParts(
        month: _months[date.month - 1],
        day: '${date.day}',
        weekday: _weekdays[date.weekday - 1],
      );
    }

    final dateLabel = appointment.dateLabel.trim();
    if (dateLabel.isNotEmpty) {
      return _AppointmentDateParts(
        month: '---',
        day: dateLabel.length > 3 ? dateLabel.substring(0, 3) : dateLabel,
        weekday: '---',
      );
    }

    return const _AppointmentDateParts(month: '---', day: '·', weekday: '---');
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

_StatusStyle _statusStyle(String status) {
  final normalized = status.trim().toLowerCase();
  switch (normalized) {
    case 'confirmed':
      return _StatusStyle(
        label: 'Confirmed',
        background: AppColors.mood5.withValues(alpha: 0.14),
        foreground: AppColors.mood5,
      );
    case 'cancelled':
    case 'canceled':
      return _StatusStyle(
        label: 'Cancelled',
        background: AppColors.badge.withValues(alpha: 0.12),
        foreground: AppColors.badge,
      );
    case 'completed':
      return _StatusStyle(
        label: 'Completed',
        background: AppColors.border,
        foreground: AppColors.textSecondary,
      );
    case 'pending':
      return _StatusStyle(
        label: 'Pending confirmation',
        background: AppColors.primaryMuted,
        foreground: AppColors.primary,
      );
    case 'reschedule_requested':
      return _StatusStyle(
        label: 'Reschedule requested',
        background: AppColors.primaryMuted,
        foreground: AppColors.primary,
      );
    case 'scheduled':
      return _StatusStyle(
        label: 'Scheduled',
        background: AppColors.primaryMuted,
        foreground: AppColors.primary,
      );
    default:
      final label = status.isEmpty
          ? 'Scheduled'
          : status[0].toUpperCase() + status.substring(1).toLowerCase();
      return _StatusStyle(
        label: label,
        background: AppColors.primaryMuted,
        foreground: AppColors.primary,
      );
  }
}

String _timeLine(AppointmentModel appointment) {
  if (appointment.timeLabel.isEmpty) return '';
  if (appointment.endTimeLabel.isEmpty) {
    return appointment.timeLabel;
  }
  return '${appointment.timeLabel} – ${appointment.endTimeLabel}';
}
