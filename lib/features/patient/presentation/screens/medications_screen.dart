import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/responsive/responsive_widgets.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/empty_state_card.dart';
import '../../data/models/medication_model.dart';
import '../../data/models/personal_medication.dart';
import '../widgets/personal_medication_tracker.dart';
import '../providers/patient_providers.dart';

class MedicationsScreen extends ConsumerStatefulWidget {
  const MedicationsScreen({super.key});

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends ConsumerState<MedicationsScreen> {
  final Set<String> _submittingKeys = {};

  String _formatDoseTime(String time24) {
    final raw = time24.trim();
    try {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1].padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return '$h12:$minute $period';
      }
    } catch (_) {}
    return raw;
  }

  Future<void> _handleLogIntake({
    required String scheduleId,
    required String doseTime,
    required MedicationDoseStatus status,
  }) async {
    final key = '$scheduleId-$doseTime';
    if (_submittingKeys.contains(key)) return;

    setState(() => _submittingKeys.add(key));
    try {
      await ref
          .read(medicationsProvider.notifier)
          .logIntake(
            scheduleId: scheduleId,
            doseTime: doseTime,
            status: status,
          );
      if (mounted) {
        final label = status == MedicationDoseStatus.taken
            ? 'marked as taken'
            : 'marked as skipped';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dose at ${_formatDoseTime(doseTime)} $label.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update dose: ${friendlyErrorMessage(e)}'),
            backgroundColor: AppColors.badge,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submittingKeys.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final medsAsync = ref.watch(medicationsProvider);
    final personal = ref.watch(personalMedicationsProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Medications & Prescriptions',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Add medication',
        onPressed: () => showAddPersonalMedicationSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add medication'),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          child: medsAsync.when(
            loading: () => const _MedicationsSkeleton(),
            error: (error, _) => ListView(
              padding: responsive.pagePadding.copyWith(
                bottom: responsive.rz(100),
              ),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.medication_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Clinic prescriptions unavailable',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Please try again to load medications from your clinic.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(medicationsProvider),
                          child: const Text('Retry prescriptions'),
                        ),
                      ],
                    ),
                  ),
                ),
                const PersonalMedicationTracker(),
              ],
            ),
            data: (medications) {
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.invalidate(medicationsProvider),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: responsive.pagePadding.copyWith(
                    top: responsive.rz(8),
                    bottom: responsive.rz(100),
                  ),
                  children: [
                    Text(
                      'Track daily doses, mark medications taken, and stay on schedule.',
                      style: responsiveTextStyle(
                        context,
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: responsive.rz(16)),
                    if (medications.any((med) => med.isActive) ||
                        personal.any((med) => med.active)) ...[
                      _MedicationsSummaryBanner(
                        medications: [
                          ...medications.where((med) => med.isActive),
                          ...personal
                              .where((med) => med.active)
                              .map((med) => med.schedule(DateTime.now())),
                        ],
                      ),
                      SizedBox(height: responsive.rz(20)),
                    ],
                    if (medications.isEmpty)
                      const EmptyStateCard(
                        title: 'No Clinic Prescriptions',
                        message: 'You do not have any active medication schedules prescribed at this time.',
                        icon: Icons.medication_outlined,
                      )
                    else ...[
                      Text(
                        'CLINIC PRESCRIPTIONS',
                        style: responsiveTextStyle(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: responsive.rz(12)),
                      ...medications.map(
                        (med) => Padding(
                          padding: EdgeInsets.only(bottom: responsive.rz(16)),
                          child: _MedicationScheduleCard(
                            schedule: med,
                            submittingKeys: _submittingKeys,
                            formatDoseTime: _formatDoseTime,
                            onLogIntake: (doseTime, status) => _handleLogIntake(
                              scheduleId: med.id,
                              doseTime: doseTime,
                              status: status,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const PersonalMedicationTracker(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MedicationsSummaryBanner extends StatelessWidget {
  const _MedicationsSummaryBanner({required this.medications});

  final List<MedicationScheduleModel> medications;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    var totalDoses = 0;
    var takenDoses = 0;
    for (final m in medications) {
      totalDoses += m.doseTimes.length;
      takenDoses += m.takenCount;
    }
    final pendingDoses = medications.fold<int>(
      0,
      (sum, med) => sum + med.pendingCount,
    );
    final skippedDoses = totalDoses - takenDoses - pendingDoses;
    final progress = totalDoses > 0
        ? (takenDoses / totalDoses).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: EdgeInsets.all(responsive.rz(18)),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: AppColors.primarySoft,
                  size: 20,
                ),
              ),
              SizedBox(width: responsive.rz(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Adherence',
                      style: responsiveTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnDark,
                      ),
                    ),
                    Text(
                      '$takenDoses of $totalDoses doses taken today • $skippedDoses skipped',
                      style: responsiveTextStyle(
                        context,
                        fontSize: 13,
                        color: AppColors.textOnDarkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pendingDoses == 0 && totalDoses > 0
                      ? AppColors.mood5.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  pendingDoses == 0 && totalDoses > 0
                      ? (skippedDoses > 0 ? 'Logged' : 'All done!')
                      : '$pendingDoses pending',
                  style: responsiveTextStyle(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pendingDoses == 0 && totalDoses > 0
                        ? AppColors.mood5
                        : AppColors.primarySoft,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.rz(16)),
          Text(
            totalDoses > 0
                ? '${(progress * 100).round()}% of scheduled doses taken'
                : 'No scheduled doses today',
            style: const TextStyle(
              color: AppColors.textOnDarkMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? AppColors.mood5 : AppColors.primarySoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationScheduleCard extends StatelessWidget {
  const _MedicationScheduleCard({
    required this.schedule,
    required this.submittingKeys,
    required this.formatDoseTime,
    required this.onLogIntake,
  });

  final MedicationScheduleModel schedule;
  final Set<String> submittingKeys;
  final String Function(String) formatDoseTime;
  final void Function(String doseTime, MedicationDoseStatus status) onLogIntake;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(responsive.rz(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryWash,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.healing_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                SizedBox(width: responsive.rz(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.medicationName.isNotEmpty
                            ? schedule.medicationName
                            : 'Medication',
                        style: responsiveTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (schedule.dosage.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          schedule.dosage,
                          style: responsiveTextStyle(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (schedule.instructions.isNotEmpty) ...[
              SizedBox(height: responsive.rz(10)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  schedule.instructions,
                  style: responsiveTextStyle(
                    context,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            SizedBox(height: responsive.rz(14)),
            const Divider(height: 1, color: AppColors.border),
            SizedBox(height: responsive.rz(12)),
            Text(
              'TODAY\'S DOSES',
              style: responsiveTextStyle(
                context,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textTertiary,
              ),
            ),
            SizedBox(height: responsive.rz(8)),
            if (!schedule.isActive)
              const Text(
                'Inactive prescription',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else if (schedule.doseTimes.isEmpty)
              Text(
                'No specific dose times scheduled today.',
                style: responsiveTextStyle(
                  context,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              )
            else
              ...schedule.doseTimes.map((doseTime) {
                final status = schedule.statusFor(doseTime);
                final key = '${schedule.id}-$doseTime';
                final isBusy = submittingKeys.contains(key);

                return _DoseTimeRow(
                  doseTime: doseTime,
                  formattedTime: formatDoseTime(doseTime),
                  status: status,
                  isBusy: isBusy,
                  onTake: () =>
                      onLogIntake(doseTime, MedicationDoseStatus.taken),
                  onSkip: () =>
                      onLogIntake(doseTime, MedicationDoseStatus.skipped),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _DoseTimeRow extends StatelessWidget {
  const _DoseTimeRow({
    required this.doseTime,
    required this.formattedTime,
    required this.status,
    required this.isBusy,
    required this.onTake,
    required this.onSkip,
  });

  final String doseTime;
  final String formattedTime;
  final MedicationDoseStatus status;
  final bool isBusy;
  final VoidCallback onTake;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: responsive.rz(6)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.rz(12),
          vertical: responsive.rz(8),
        ),
        decoration: BoxDecoration(
          color: status == MedicationDoseStatus.taken
              ? AppColors.mood5.withValues(alpha: 0.08)
              : (status == MedicationDoseStatus.skipped
                    ? Colors.grey.withValues(alpha: 0.06)
                    : AppColors.background),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: status == MedicationDoseStatus.taken
                ? AppColors.mood5.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              status == MedicationDoseStatus.taken
                  ? Icons.check_circle_rounded
                  : (status == MedicationDoseStatus.skipped
                        ? Icons.cancel_outlined
                        : Icons.schedule_rounded),
              size: 18,
              color: status == MedicationDoseStatus.taken
                  ? AppColors.mood5
                  : (status == MedicationDoseStatus.skipped
                        ? AppColors.textTertiary
                        : AppColors.primary),
            ),
            SizedBox(width: responsive.rz(8)),
            Text(
              formattedTime,
              style: responsiveTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: status == MedicationDoseStatus.skipped
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (isBusy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (status == MedicationDoseStatus.taken)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mood5.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Taken',
                  style: responsiveTextStyle(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mood5,
                  ),
                ),
              )
            else if (status == MedicationDoseStatus.skipped)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Skipped',
                  style: responsiveTextStyle(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else ...[
              // Pending buttons
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: const Text('Skip', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: onTake,
                icon: const Icon(Icons.check, size: 14),
                label: const Text(
                  'Take',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MedicationsSkeleton extends StatefulWidget {
  const _MedicationsSkeleton();

  @override
  State<_MedicationsSkeleton> createState() => _MedicationsSkeletonState();
}

class _MedicationsSkeletonState extends State<_MedicationsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.border,
      borderRadius: BorderRadius.circular(8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Loading medications and prescriptions',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Opacity(
            opacity: reduceMotion ? 1 : 0.45 + _pulse.value * 0.5,
            child: child,
          ),
          child: ListView(
            padding: responsive.pagePadding.copyWith(
              top: responsive.rz(8),
              bottom: responsive.rz(100),
            ),
            children: [
              _bar(double.infinity, 14),
              const SizedBox(height: 8),
              _bar(180, 14),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(160, 18),
                    const SizedBox(height: 20),
                    _bar(double.infinity, 12),
                    const SizedBox(height: 16),
                    _bar(200, 14),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _bar(170, 12),
              const SizedBox(height: 12),
              for (var i = 0; i < 3; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _bar(44, 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _bar(double.infinity, 18),
                                const SizedBox(height: 8),
                                _bar(100, 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _bar(150, 14),
                      const SizedBox(height: 16),
                      _bar(double.infinity, 40),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
