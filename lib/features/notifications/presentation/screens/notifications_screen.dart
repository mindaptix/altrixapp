import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/notifications/notification_router.dart';
import '../../../../core/responsive/responsive_widgets.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/empty_state_card.dart';
import '../../../patient/data/models/patient_models.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../providers/notification_preferences_provider.dart';
import '../providers/notification_read_provider.dart';
import '../providers/push_notification_provider.dart';

/// Main Notifications Screen with Alerts Feed and Preference Settings.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedFilter = 'All';
  final Set<String> _selectedNotificationIds = <String>{};
  Set<String> _visibleNotificationIds = <String>{};
  bool _isDeletingSelection = false;

  bool get _isSelectionMode => _selectedNotificationIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final notificationsAsync = ref.watch(patientNotificationsProvider);
    final readState = ref.watch(notificationReadControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                tooltip: 'Close selection',
                onPressed: _isDeletingSelection ? null : _clearSelection,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text(
          _isSelectionMode
              ? '${_selectedNotificationIds.length} selected'
              : 'Notifications',
        ),
        actions: _isSelectionMode
            ? [
                TextButton(
                  onPressed: _isDeletingSelection ? null : _selectAllVisible,
                  child: const Text('Select all'),
                ),
                IconButton(
                  tooltip: 'Delete selected',
                  onPressed: _isDeletingSelection ? null : _deleteSelected,
                  icon: _isDeletingSelection
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                ),
              ]
            : null,
        bottom: _isSelectionMode
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
                tabs: const [
                  Tab(text: 'Alerts & Activity'),
                  Tab(text: 'Preferences'),
                ],
              ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildAlertsTab(responsive, notificationsAsync, readState),
            _buildPreferencesTab(responsive),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsTab(
    Responsive responsive,
    AsyncValue<PatientNotificationPage> notificationsAsync,
    NotificationReadState readState,
  ) {
    return notificationsAsync.when(
      loading: () => const InlineLoadingCard(label: 'Loading notifications...'),
      error: (error, _) => Padding(
        padding: responsive.pagePadding,
        child: InlineErrorCard(
          message: friendlyErrorMessage(error),
          onRetry: () => ref.invalidate(patientNotificationsProvider),
        ),
      ),
      data: (page) {
        final allItems = page.notifications;

        final filteredItems = allItems.where((item) {
          switch (_selectedFilter) {
            case 'Unread':
              return !_isEffectivelyRead(item, readState);
            case 'Care Team':
              return item.title.toLowerCase().contains('care') ||
                  item.title.toLowerCase().contains('team') ||
                  item.body.toLowerCase().contains('care') ||
                  item.body.toLowerCase().contains('doctor') ||
                  item.body.toLowerCase().contains('mood');
            case 'Appointments':
              return item.title.toLowerCase().contains('appointment') ||
                  item.title.toLowerCase().contains('visit') ||
                  item.body.toLowerCase().contains('appointment') ||
                  item.body.toLowerCase().contains('visit') ||
                  item.body.toLowerCase().contains('schedule');
            default:
              return true;
          }
        }).toList();
        _visibleNotificationIds = filteredItems.map((item) => item.id).toSet();

        final localReadCount = allItems
            .where(
              (item) =>
                  !item.isRead && readState.locallyReadIds.contains(item.id),
            )
            .length;
        final unreadCount = math.max(0, page.unreadCount - localReadCount);

        return ResponsiveCenter(
          child: ListView(
            padding: responsive.pagePadding.copyWith(
              top: responsive.rz(16),
              bottom: responsive.rz(32),
            ),
            children: [
              // Header Summary Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unreadCount > 0
                              ? '$unreadCount unread ${unreadCount == 1 ? 'alert' : 'alerts'}'
                              : 'All caught up',
                          style: responsiveTextStyle(
                            context,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: responsive.rz(2)),
                        Text(
                          'Updates from your clinical care team and visits',
                          style: responsiveTextStyle(
                            context,
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unreadCount > 0)
                    TextButton.icon(
                      onPressed: () async {
                        ref
                            .read(notificationReadControllerProvider.notifier)
                            .markAllLocally(
                              allItems
                                  .where((item) => !item.isRead)
                                  .map((item) => item.id),
                            );
                        try {
                          await ref
                              .read(patientRepositoryProvider)
                              .markAllNotificationsRead();
                          ref.invalidate(patientNotificationsProvider);
                          ref.invalidate(dashboardProvider);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All notifications marked as read'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(friendlyErrorMessage(error)),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.done_all_rounded, size: 17),
                      label: const Text('Mark all read'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: responsive.rz(14)),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Unread', 'Care Team', 'Appointments'].map((
                    filter,
                  ) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: EdgeInsets.only(right: responsive.rz(8)),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedFilter = filter),
                        selectedColor: AppColors.primaryMuted,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: responsive.rz(16)),

              if (filteredItems.isEmpty)
                EmptyStateCard(
                  title: _selectedFilter == 'All'
                      ? 'No alerts right now'
                      : 'No $_selectedFilter notifications',
                  message: 'When your care team sends notes or appointment reminders, they will appear here.',
                  icon: Icons.notifications_off_outlined,
                )
              else
                ...filteredItems.map((item) {
                  final isRead = _isEffectivelyRead(item, readState);
                  final isSelected = _selectedNotificationIds.contains(item.id);
                  return Dismissible(
                    key: ValueKey('notification-${item.id}'),
                    direction: _isSelectionMode
                        ? DismissDirection.none
                        : DismissDirection.endToStart,
                    background: Container(
                      margin: EdgeInsets.only(bottom: responsive.rz(10)),
                      padding: EdgeInsets.only(right: responsive.rz(20)),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(responsive.rz(18)),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                    confirmDismiss: (_) async {
                      try {
                        await ref
                            .read(patientRepositoryProvider)
                            .deleteNotification(item.id);
                        return true;
                      } catch (error) {
                        if (!mounted) return false;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(friendlyErrorMessage(error)),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return false;
                      }
                    },
                    onDismissed: (_) {
                      ref.invalidate(patientNotificationsProvider);
                      ref.invalidate(dashboardProvider);
                    },
                    child: _NotificationItemCard(
                      item: item,
                      isRead: isRead,
                      isSelected: isSelected,
                      selectionMode: _isSelectionMode,
                      onLongPress: () => _toggleSelection(item.id),
                      onTap: () => _isSelectionMode
                          ? _toggleSelection(item.id)
                          : _handleNotificationTap(item),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedNotificationIds.add(id)) {
        _selectedNotificationIds.remove(id);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedNotificationIds.clear);
  }

  void _selectAllVisible() {
    setState(() {
      if (_selectedNotificationIds.containsAll(_visibleNotificationIds)) {
        _selectedNotificationIds.clear();
      } else {
        _selectedNotificationIds.addAll(_visibleNotificationIds);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedNotificationIds.isEmpty || _isDeletingSelection) return;
    final ids = Set<String>.from(_selectedNotificationIds);
    setState(() => _isDeletingSelection = true);

    var failed = 0;
    await Future.wait(
      ids.map((id) async {
        try {
          await ref.read(patientRepositoryProvider).deleteNotification(id);
        } catch (_) {
          failed += 1;
        }
      }),
    );

    if (!mounted) return;
    setState(() {
      _isDeletingSelection = false;
      _selectedNotificationIds.clear();
    });
    ref.invalidate(patientNotificationsProvider);
    ref.invalidate(dashboardProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? '${ids.length} ${ids.length == 1 ? 'notification' : 'notifications'} deleted'
              : 'Deleted ${ids.length - failed}. $failed could not be deleted.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isEffectivelyRead(
    PatientNotificationModel item,
    NotificationReadState readState,
  ) {
    return item.isRead || readState.locallyReadIds.contains(item.id);
  }

  void _handleNotificationTap(PatientNotificationModel item) {
    unawaited(
      ref.read(notificationReadControllerProvider.notifier).markRead(item.id),
    );

    NotificationRouter.handleTap(<String, dynamic>{
      ...item.data,
      'notificationId': item.id,
      'type': item.type,
      'title': item.title,
      'body': item.body,
    });
  }

  Widget _buildPreferencesTab(Responsive responsive) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final notifier = ref.read(notificationPreferencesProvider.notifier);

    return ResponsiveCenter(
      child: ListView(
        padding: responsive.pagePadding.copyWith(
          top: responsive.rz(16),
          bottom: responsive.rz(32),
        ),
        children: [
          // Push Master Card
          Container(
            padding: EdgeInsets.all(responsive.rz(18)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(responsive.rz(22)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E1B4B).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: responsive.rz(48),
                  height: responsive.rz(48),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: responsive.rz(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Push Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: responsive.rz(2)),
                      Text(
                        prefs.pushEnabled
                            ? 'Device push alerts active'
                            : 'Muted on this device',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: prefs.pushEnabled,
                  activeThumbColor: AppColors.primarySoft,
                  activeTrackColor: Colors.white,
                  onChanged: (val) async {
                    if (val) {
                      await ref
                          .read(pushNotificationServiceProvider)
                          .initialize();
                    }
                    await notifier.update(
                      (curr) => curr.copyWith(pushEnabled: val),
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: responsive.rz(22)),

          // Clinical & Care Alerts Section
          _SectionHeader(
            title: 'Clinical & Care Alerts',
            subtitle: 'Direct notifications regarding your treatment plan',
          ),
          SizedBox(height: responsive.rz(10)),
          _SettingsGroupCard(
            children: [
              _PreferenceSwitchTile(
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Appointment Reminders',
                subtitle: '24 hours and 1 hour before scheduled sessions',
                value: prefs.appointmentReminders,
                enabled: prefs.pushEnabled,
                onChanged: (val) => notifier.update(
                  (curr) => curr.copyWith(appointmentReminders: val),
                ),
              ),
              const Divider(height: 1),
              _PreferenceSwitchTile(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: AppColors.primary,
                title: 'Care Team Messages',
                subtitle:
                    'Instant notices when clinicians send secure chat updates',
                value: prefs.careTeamMessages,
                enabled: prefs.pushEnabled,
                onChanged: (val) => notifier.update(
                  (curr) => curr.copyWith(careTeamMessages: val),
                ),
              ),
              const Divider(height: 1),
              _PreferenceSwitchTile(
                icon: Icons.sentiment_satisfied_alt_rounded,
                iconColor: AppColors.mood5,
                title: 'Daily Wellness Check-in',
                subtitle:
                    'Gentle reminder to log mood, stress, and sleep scores',
                value: prefs.dailyCheckInReminders,
                enabled: prefs.pushEnabled,
                onChanged: (val) => notifier.update(
                  (curr) => curr.copyWith(dailyCheckInReminders: val),
                ),
              ),
              const Divider(height: 1),
              _PreferenceSwitchTile(
                icon: Icons.medication_outlined,
                iconColor: AppColors.mood2,
                title: 'Prescriptions & Refills',
                subtitle: 'Medication alerts and refill notifications',
                value: prefs.medicationReminders,
                enabled: prefs.pushEnabled,
                onChanged: (val) => notifier.update(
                  (curr) => curr.copyWith(medicationReminders: val),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.rz(22)),

          // Additional Channels Section
          _SectionHeader(
            title: 'Delivery Channels',
            subtitle: 'Choose where notifications are sent',
          ),
          SizedBox(height: responsive.rz(10)),
          _SettingsGroupCard(
            children: [
              _PreferenceSwitchTile(
                icon: Icons.email_outlined,
                iconColor: const Color(0xFF6366F1),
                title: 'Email Summaries',
                subtitle: 'Weekly progress reports sent to your email',
                value: prefs.emailDigest,
                onChanged: (val) =>
                    notifier.update((curr) => curr.copyWith(emailDigest: val)),
              ),
              const Divider(height: 1),
              _PreferenceSwitchTile(
                icon: Icons.sms_outlined,
                iconColor: const Color(0xFF0EA5E9),
                title: 'Urgent SMS Notices',
                subtitle: 'Emergency schedule changes & immediate visit links',
                value: prefs.smsAlerts,
                onChanged: (val) =>
                    notifier.update((curr) => curr.copyWith(smsAlerts: val)),
              ),
              const Divider(height: 1),
              _PreferenceSwitchTile(
                icon: Icons.campaign_outlined,
                iconColor: AppColors.textSecondary,
                title: 'Clinic Announcements',
                subtitle: 'Practice updates, holiday hours, and health tips',
                value: prefs.clinicAnnouncements,
                onChanged: (val) => notifier.update(
                  (curr) => curr.copyWith(clinicAnnouncements: val),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.rz(22)),

          // Quiet Hours Section
          _SectionHeader(
            title: 'Quiet Hours',
            subtitle: 'Pause non-urgent alerts during sleep hours',
          ),
          SizedBox(height: responsive.rz(10)),
          _SettingsGroupCard(
            children: [
              _PreferenceSwitchTile(
                icon: Icons.bedtime_outlined,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Do Not Disturb (10 PM – 7 AM)',
                subtitle:
                    'All notifications muted except urgent care team calls',
                value: prefs.quietHoursEnabled,
                onChanged: (val) => notifier.update(
                  (curr) => curr.copyWith(quietHoursEnabled: val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationItemCard extends StatelessWidget {
  const _NotificationItemCard({
    required this.item,
    required this.isRead,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final PatientNotificationModel item;
  final bool isRead;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final isAppt =
        item.title.toLowerCase().contains('appointment') ||
        item.body.toLowerCase().contains('visit');
    final isMood =
        item.title.toLowerCase().contains('mood') ||
        item.body.toLowerCase().contains('check-in');

    final icon = isAppt
        ? Icons.calendar_today_rounded
        : isMood
        ? Icons.mood_rounded
        : Icons.notifications_rounded;
    final iconColor = isAppt
        ? const Color(0xFF3B82F6)
        : isMood
        ? AppColors.mood5
        : AppColors.primary;
    final iconBg = isAppt
        ? const Color(0xFFE8F4FF)
        : isMood
        ? const Color(0xFFE8FBF0)
        : AppColors.primaryWash;

    return Padding(
      padding: EdgeInsets.only(bottom: responsive.rz(10)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(responsive.rz(18)),
          child: Ink(
            padding: EdgeInsets.all(responsive.rz(14)),
            decoration: BoxDecoration(
              color: isRead ? AppColors.surface : AppColors.surface,
              borderRadius: BorderRadius.circular(responsive.rz(18)),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : isRead
                    ? AppColors.border
                    : AppColors.primary.withValues(alpha: 0.35),
                width: isSelected || !isRead ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isRead
                      ? AppColors.textPrimary.withValues(alpha: 0.02)
                      : AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    activeColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(width: responsive.rz(4)),
                ],
                Container(
                  width: responsive.rz(42),
                  height: responsive.rz(42),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                SizedBox(width: responsive.rz(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title.isNotEmpty
                                  ? item.title
                                  : 'Care Team Update',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: responsive.rz(4)),
                      Text(
                        item.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      if (item.createdAt.isNotEmpty) ...[
                        SizedBox(height: responsive.rz(6)),
                        Text(
                          item.formattedTime,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _PreferenceSwitchTile extends StatelessWidget {
  const _PreferenceSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.rz(16),
          vertical: responsive.rz(12),
        ),
        child: Row(
          children: [
            Container(
              width: responsive.rz(38),
              height: responsive.rz(38),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            SizedBox(width: responsive.rz(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: responsive.rz(8)),
            Switch.adaptive(
              value: value,
              activeTrackColor: AppColors.primary,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
