import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/responsive/responsive_widgets.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/empty_state_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../patient/data/models/patient_models.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../providers/push_notification_provider.dart';
import '../providers/notification_activity_provider.dart';

/// Persisted notification preferences model.
class NotificationPreferences {
  const NotificationPreferences({
    this.pushEnabled = true,
    this.appointmentReminders = true,
    this.careTeamMessages = true,
    this.dailyCheckInReminders = true,
    this.medicationReminders = true,
    this.clinicAnnouncements = false,
    this.emailDigest = true,
    this.smsAlerts = true,
    this.quietHoursEnabled = false,
  });

  final bool pushEnabled;
  final bool appointmentReminders;
  final bool careTeamMessages;
  final bool dailyCheckInReminders;
  final bool medicationReminders;
  final bool clinicAnnouncements;
  final bool emailDigest;
  final bool smsAlerts;
  final bool quietHoursEnabled;

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? appointmentReminders,
    bool? careTeamMessages,
    bool? dailyCheckInReminders,
    bool? medicationReminders,
    bool? clinicAnnouncements,
    bool? emailDigest,
    bool? smsAlerts,
    bool? quietHoursEnabled,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      appointmentReminders: appointmentReminders ?? this.appointmentReminders,
      careTeamMessages: careTeamMessages ?? this.careTeamMessages,
      dailyCheckInReminders: dailyCheckInReminders ?? this.dailyCheckInReminders,
      medicationReminders: medicationReminders ?? this.medicationReminders,
      clinicAnnouncements: clinicAnnouncements ?? this.clinicAnnouncements,
      emailDigest: emailDigest ?? this.emailDigest,
      smsAlerts: smsAlerts ?? this.smsAlerts,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    );
  }

  static const _keyPush = 'notif_pref_push';
  static const _keyAppt = 'notif_pref_appt';
  static const _keyCare = 'notif_pref_care';
  static const _keyCheckIn = 'notif_pref_checkin';
  static const _keyMeds = 'notif_pref_meds';
  static const _keyClinic = 'notif_pref_clinic';
  static const _keyEmail = 'notif_pref_email';
  static const _keySms = 'notif_pref_sms';
  static const _keyQuiet = 'notif_pref_quiet';

  static NotificationPreferences fromPrefs(SharedPreferences prefs) {
    return NotificationPreferences(
      pushEnabled: prefs.getBool(_keyPush) ?? true,
      appointmentReminders: prefs.getBool(_keyAppt) ?? true,
      careTeamMessages: prefs.getBool(_keyCare) ?? true,
      dailyCheckInReminders: prefs.getBool(_keyCheckIn) ?? true,
      medicationReminders: prefs.getBool(_keyMeds) ?? true,
      clinicAnnouncements: prefs.getBool(_keyClinic) ?? false,
      emailDigest: prefs.getBool(_keyEmail) ?? true,
      smsAlerts: prefs.getBool(_keySms) ?? true,
      quietHoursEnabled: prefs.getBool(_keyQuiet) ?? false,
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setBool(_keyPush, pushEnabled);
    await prefs.setBool(_keyAppt, appointmentReminders);
    await prefs.setBool(_keyCare, careTeamMessages);
    await prefs.setBool(_keyCheckIn, dailyCheckInReminders);
    await prefs.setBool(_keyMeds, medicationReminders);
    await prefs.setBool(_keyClinic, clinicAnnouncements);
    await prefs.setBool(_keyEmail, emailDigest);
    await prefs.setBool(_keySms, smsAlerts);
    await prefs.setBool(_keyQuiet, quietHoursEnabled);
  }
}

final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
  NotificationPreferencesNotifier.new,
);

class NotificationPreferencesNotifier extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return NotificationPreferences.fromPrefs(prefs);
  }

  Future<void> update(NotificationPreferences Function(NotificationPreferences current) fn) async {
    final updated = fn(state);
    state = updated;
    final prefs = ref.read(sharedPreferencesProvider);
    await updated.save(prefs);
  }
}

/// Main Notifications Screen with Alerts Feed and Preference Settings.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedFilter = 'All';


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
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
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
            _buildAlertsTab(responsive, dashboardAsync),
            _buildPreferencesTab(responsive),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsTab(
    Responsive responsive,
    AsyncValue<DashboardModel> dashboardAsync,
  ) {
    final readItemKeys = ref.watch(readNotificationKeysProvider);
    return dashboardAsync.when(
      loading: () => const InlineLoadingCard(label: 'Loading notifications...'),
      error: (error, _) => Padding(
        padding: responsive.pagePadding,
        child: InlineErrorCard(
          message: friendlyErrorMessage(error),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
      ),
      data: (dashboard) {
        final notifications = dashboard.notifications;
        final reminders = dashboard.reminders;
        final allItems = <DashboardItem>[...notifications, ...reminders];

        final filteredItems = allItems.where((item) {
          final isLocallyRead = readItemKeys.contains(notificationItemKey(item));
          final isEffectiveUnread = item.isUnread && !isLocallyRead;

          switch (_selectedFilter) {
            case 'Unread':
              return isEffectiveUnread;
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

        final unreadCount = allItems.where((item) {
          return item.isUnread && !readItemKeys.contains(notificationItemKey(item));
        }).length;

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
                      onPressed: () {
                        ref.read(readNotificationKeysProvider.notifier).markAllRead(allItems);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All notifications marked as read'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.done_all_rounded, size: 17),
                      label: const Text('Mark all read'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                ],
              ),
              SizedBox(height: responsive.rz(14)),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Unread', 'Care Team', 'Appointments'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: EdgeInsets.only(right: responsive.rz(8)),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                        selectedColor: AppColors.primaryMuted,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
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
                  final isRead = !item.isUnread || readItemKeys.contains(notificationItemKey(item));
                  return _NotificationItemCard(
                    item: item,
                    isRead: isRead,
                    onTap: () {
                      if (!isRead) {
                        ref.read(readNotificationKeysProvider.notifier).markRead(item);
                      }
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
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
                      await ref.read(pushNotificationServiceProvider).initialize();
                    }
                    await notifier.update((curr) => curr.copyWith(pushEnabled: val));
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
                subtitle: 'Instant notices when clinicians send secure chat updates',
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
                subtitle: 'Gentle reminder to log mood, stress, and sleep scores',
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
                onChanged: (val) => notifier.update(
                  (curr) => curr.copyWith(emailDigest: val),
                ),
              ),
              const Divider(height: 1),
              _PreferenceSwitchTile(
                icon: Icons.sms_outlined,
                iconColor: const Color(0xFF0EA5E9),
                title: 'Urgent SMS Notices',
                subtitle: 'Emergency schedule changes & immediate visit links',
                value: prefs.smsAlerts,
                onChanged: (val) => notifier.update(
                  (curr) => curr.copyWith(smsAlerts: val),
                ),
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
                subtitle: 'All notifications muted except urgent care team calls',
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
    required this.onTap,
  });

  final DashboardItem item;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final isAppt = item.title.toLowerCase().contains('appointment') ||
        item.body.toLowerCase().contains('visit');
    final isMood = item.title.toLowerCase().contains('mood') ||
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
          borderRadius: BorderRadius.circular(responsive.rz(18)),
          child: Ink(
            padding: EdgeInsets.all(responsive.rz(14)),
            decoration: BoxDecoration(
              color: isRead ? AppColors.surface : AppColors.surface,
              borderRadius: BorderRadius.circular(responsive.rz(18)),
              border: Border.all(
                color: isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.35),
                width: isRead ? 1 : 1.5,
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
                              item.title.isNotEmpty ? item.title : 'Care Team Update',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
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
                      if (item.time.isNotEmpty) ...[
                        SizedBox(height: responsive.rz(6)),
                        Text(
                          item.time,
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
