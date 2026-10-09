import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive/responsive.dart';
import '../core/responsive/responsive_widgets.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/sign_in_screen.dart';
import '../features/help/presentation/screens/help_center_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/patient/presentation/screens/forms_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/account_portal_screen.dart';
import '../features/profile/presentation/screens/privacy_security_screen.dart';
import '../features/resources/presentation/screens/resources_screen.dart';
import '../theme/app_colors.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _ScheduleBackground(),
          SafeArea(
            child: ResponsiveCenter(
              child: ListView(
                padding: responsive.pagePadding.copyWith(
                  top: responsive.rz(12),
                  bottom: responsive.rz(32),
                ),
                children: [

                  Text(
                    'Upcoming visits with your care team',
                    style: responsiveTextStyle(
                      context,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: responsive.rz(18)),
                  const _ScheduleStatsRow(),
                  SizedBox(height: responsive.rz(20)),
                  _ScheduleFeaturedCard(
                    onJoin: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Opening Zoom…'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: responsive.rz(24)),
                  Text(
                    'All appointments',
                    style: responsiveTextStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: responsive.rz(14)),
                  const _ScheduleAppointmentCard(
                    month: 'TODAY',
                    day: '·',
                    weekday: 'NOW',
                    title: 'Today, 2:00 PM',
                    provider: 'Maya Patel, LCSW-C',
                    visitType: 'Video visit',
                    duration: '50 min',
                    icon: Icons.videocam_rounded,
                    accentColor: AppColors.primary,
                    isHighlighted: true,
                  ),
                  _ScheduleTimelineConnector(),
                  const _ScheduleAppointmentCard(
                    month: 'MAY',
                    day: '15',
                    weekday: 'THU',
                    title: 'Thu, May 15  ·  10:00 AM',
                    provider: 'Altrixs',
                    visitType: 'In-person',
                    duration: '50 min',
                    icon: Icons.location_on_rounded,
                    accentColor: Color(0xFF3B82F6),
                  ),
                  _ScheduleTimelineConnector(),
                  const _ScheduleAppointmentCard(
                    month: 'MAY',
                    day: '20',
                    weekday: 'TUE',
                    title: 'Tue, May 20  ·  2:00 PM',
                    provider: 'Maya Patel, LCSW-C',
                    visitType: 'Telehealth',
                    duration: '50 min',
                    icon: Icons.videocam_rounded,
                    accentColor: AppColors.primary,
                  ),
                  SizedBox(height: responsive.rz(20)),
                  _ScheduleTipCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleBackground extends StatelessWidget {
  const _ScheduleBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 240,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.09),
              AppColors.primaryWash.withValues(alpha: 0.32),
              AppColors.background.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleStatsRow extends StatelessWidget {
  const _ScheduleStatsRow();

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Row(
      children: [
        Expanded(
          child: _ScheduleStatChip(
            icon: Icons.event_available_rounded,
            label: '3 upcoming',
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: responsive.rz(10)),
        Expanded(
          child: _ScheduleStatChip(
            icon: Icons.videocam_rounded,
            label: '2 virtual',
            color: const Color(0xFF3B82F6),
          ),
        ),
        SizedBox(width: responsive.rz(10)),
        Expanded(
          child: _ScheduleStatChip(
            icon: Icons.location_on_rounded,
            label: '1 in-person',
            color: AppColors.mood5,
          ),
        ),
      ],
    );
  }
}

class _ScheduleStatChip extends StatelessWidget {
  const _ScheduleStatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.rz(10),
        vertical: responsive.rz(12),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(responsive.rz(16)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: responsive.rz(20), color: color),
          SizedBox(height: responsive.rz(6)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: responsiveTextStyle(
              context,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleFeaturedCard extends StatelessWidget {
  const _ScheduleFeaturedCard({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(responsive.rz(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(responsive.rz(24)),
        child: Container(
          padding: EdgeInsets.all(responsive.rz(20)),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF12103A),
                Color(0xFF1C1858),
                Color(0xFF2A2280),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5EC77A).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF5EC77A).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF5EC77A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Happening today',
                          style: responsiveTextStyle(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFD8D6F0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.videocam_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: responsive.rz(22),
                  ),
                ],
              ),
              SizedBox(height: responsive.rz(16)),
              Text(
                'Today, 2:00 PM',
                style: responsiveTextStyle(
                  context,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: responsive.rz(6)),
              Text(
                'Maya Patel, LCSW-C',
                style: responsiveTextStyle(
                  context,
                  fontSize: 15,
                  color: const Color(0xFFD8D6F0),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: responsive.rz(14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Color(0xFFC4C0EA),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Video visit  ·  50 min',
                      style: responsiveTextStyle(
                        context,
                        fontSize: 13,
                        color: const Color(0xFFC4C0EA),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: responsive.rz(18)),
              SizedBox(
                width: double.infinity,
                height: responsive.rz(48),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B83F6), AppColors.primary],
                    ),
                  ),
                  child: FilledButton.icon(
                    onPressed: onJoin,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.videocam_rounded, size: 20),
                    label: const Text(
                      'Join Zoom',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleAppointmentCard extends StatelessWidget {
  const _ScheduleAppointmentCard({
    required this.month,
    required this.day,
    required this.weekday,
    required this.title,
    required this.provider,
    required this.visitType,
    required this.duration,
    required this.icon,
    required this.accentColor,
    this.isHighlighted = false,
  });

  final String month;
  final String day;
  final String weekday;
  final String title;
  final String provider;
  final String visitType;
  final String duration;
  final IconData icon;
  final Color accentColor;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(responsive.rz(20)),
        child: Ink(
          decoration: BoxDecoration(
            color: isHighlighted
                ? accentColor.withValues(alpha: 0.06)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(responsive.rz(20)),
            border: Border.all(
              color: isHighlighted
                  ? accentColor.withValues(alpha: 0.22)
                  : AppColors.border.withValues(alpha: 0.85),
            ),
            boxShadow: [
              if (!isHighlighted)
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(responsive.rz(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: responsive.rz(54),
                  padding: EdgeInsets.symmetric(vertical: responsive.rz(8)),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        month,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: day == '·' ? 18 : 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1,
                        ),
                      ),
                      Text(
                        weekday,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: responsive.rz(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: responsiveTextStyle(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: responsive.rz(4)),
                      Text(
                        provider,
                        style: responsiveTextStyle(
                          context,
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: responsive.rz(10)),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _ScheduleTag(
                            icon: icon,
                            label: visitType,
                            color: accentColor,
                          ),
                          _ScheduleTag(
                            icon: Icons.schedule_rounded,
                            label: duration,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: responsive.rz(22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleTag extends StatelessWidget {
  const _ScheduleTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTimelineConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: context.responsive.rz(40),
        top: 4,
        bottom: 4,
      ),
      child: Container(
        width: 2,
        height: context.responsive.rz(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.35),
              AppColors.border,
            ],
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ScheduleTipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      padding: EdgeInsets.all(responsive.rz(16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryWash.withValues(alpha: 0.8),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(responsive.rz(18)),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: responsive.rz(42),
            height: responsive.rz(42),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary,
              size: responsive.rz(22),
            ),
          ),
          SizedBox(width: responsive.rz(12)),
          Expanded(
            child: Text(
              'Join video visits 5 minutes early to test your camera and microphone.',
              style: responsiveTextStyle(
                context,
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _TabScreenBackground(),
          SafeArea(
            child: ResponsiveCenter(
              child: ListView(
                padding: responsive.pagePadding.copyWith(
                  top: responsive.rz(12),
                  bottom: responsive.rz(32),
                ),
                children: [

                  Text(
                    'Secure messages from your clinic',
                    style: responsiveTextStyle(
                      context,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: responsive.rz(18)),
                  const _MessagesStatsRow(),
                  SizedBox(height: responsive.rz(18)),
                  _MessagesSearchBar(),
                  SizedBox(height: responsive.rz(20)),
                  Text(
                    'Recent conversations',
                    style: responsiveTextStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: responsive.rz(14)),
                  _MessageThreadCard(
                    initials: 'AL',
                    name: 'Altrixs',
                    preview: 'Reminder: complete PHQ-9 before Friday',
                    time: '1h ago',
                    unreadCount: 1,
                    gradient: const [Color(0xFFEDE9FE), Color(0xFFD8D2FF)],
                    accentColor: AppColors.primary,
                    onTap: () => _showMessageToast(context, 'Altrixs'),
                  ),
                  SizedBox(height: responsive.rz(10)),
                  _MessageThreadCard(
                    initials: 'MP',
                    name: 'Maya Patel, LCSW-C',
                    preview: 'Looking forward to our session today.',
                    time: 'Yesterday',
                    unreadCount: 0,
                    gradient: const [Color(0xFFE8F4FF), Color(0xFFCCE8FF)],
                    accentColor: const Color(0xFF3B82F6),
                    onTap: () => _showMessageToast(context, 'Maya Patel'),
                  ),
                  SizedBox(height: responsive.rz(20)),
                  _SecureMessagingBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageToast(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening chat with $name'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class CareScreen extends StatelessWidget {
  const CareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _TabScreenBackground(),
          SafeArea(
            child: ResponsiveCenter(
              child: ListView(
                padding: responsive.pagePadding.copyWith(
                  top: responsive.rz(12),
                  bottom: responsive.rz(32),
                ),
                children: [

                  Text(
                    'Forms and resources from your clinic',
                    style: responsiveTextStyle(
                      context,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: responsive.rz(18)),
                  const _CareStatsRow(),
                  SizedBox(height: responsive.rz(20)),
                  _CareFeaturedCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FormsScreen()),
                      );
                    },
                  ),
                  SizedBox(height: responsive.rz(24)),
                  Text(
                    'Forms & worksheets',
                    style: responsiveTextStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: responsive.rz(12)),
                  _CareItemCard(
                    icon: Icons.description_outlined,
                    title: 'PHQ-9',
                    subtitle: 'Due Friday  ·  5–10 min',
                    badge: 'Due soon',
                    gradient: const [Color(0xFFFFF4E5), Color(0xFFFFE4C7)],
                    iconColor: AppColors.mood2,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FormsScreen()),
                      );
                    },
                  ),
                  _CareItemCard(
                    icon: Icons.menu_book_outlined,
                    title: 'Coping skills worksheet',
                    subtitle: 'Shared by your therapist',
                    gradient: const [Color(0xFFE8FBF0), Color(0xFFC9F0D8)],
                    iconColor: AppColors.mood5,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ResourcesScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: responsive.rz(22)),
                  Text(
                    'Support resources',
                    style: responsiveTextStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: responsive.rz(12)),
                  _CareCrisisCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ResourcesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabScreenBackground extends StatelessWidget {
  const _TabScreenBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 240,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.09),
              AppColors.primaryWash.withValues(alpha: 0.32),
              AppColors.background.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesStatsRow extends StatelessWidget {
  const _MessagesStatsRow();

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Row(
      children: [
        Expanded(
          child: _ScheduleStatChip(
            icon: Icons.mark_chat_unread_rounded,
            label: '1 unread',
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: responsive.rz(10)),
        Expanded(
          child: _ScheduleStatChip(
            icon: Icons.forum_outlined,
            label: '2 chats',
            color: const Color(0xFF3B82F6),
          ),
        ),
        SizedBox(width: responsive.rz(10)),
        Expanded(
          child: _ScheduleStatChip(
            icon: Icons.lock_rounded,
            label: 'Encrypted',
            color: AppColors.mood5,
          ),
        ),
      ],
    );
  }
}

class _MessagesSearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: responsive.rz(14)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(responsive.rz(16)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: AppColors.textTertiary,
            size: responsive.rz(22),
          ),
          SizedBox(width: responsive.rz(10)),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search messages',
                hintStyle: responsiveTextStyle(
                  context,
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: responsive.rz(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageThreadCard extends StatelessWidget {
  const _MessageThreadCard({
    required this.initials,
    required this.name,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.gradient,
    required this.accentColor,
    required this.onTap,
  });

  final String initials;
  final String name;
  final String preview;
  final String time;
  final int unreadCount;
  final List<Color> gradient;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final hasUnread = unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(responsive.rz(20)),
        child: Ink(
          decoration: BoxDecoration(
            color: hasUnread
                ? accentColor.withValues(alpha: 0.05)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(responsive.rz(20)),
            border: Border.all(
              color: hasUnread
                  ? accentColor.withValues(alpha: 0.2)
                  : AppColors.border.withValues(alpha: 0.85),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(responsive.rz(14)),
            child: Row(
              children: [
                Container(
                  width: responsive.rz(50),
                  height: responsive.rz(50),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: responsive.rz(15),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: responsive.rz(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: responsiveTextStyle(
                                context,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            time,
                            style: responsiveTextStyle(
                              context,
                              fontSize: 11.5,
                              color: hasUnread
                                  ? accentColor
                                  : AppColors.textTertiary,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: responsive.rz(5)),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: responsiveTextStyle(
                          context,
                          fontSize: 13,
                          color: hasUnread
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasUnread) ...[
                  SizedBox(width: responsive.rz(8)),
                  Container(
                    width: responsive.rz(22),
                    height: responsive.rz(22),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B83F6), AppColors.primary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsive.rz(11),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecureMessagingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      padding: EdgeInsets.all(responsive.rz(16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryWash.withValues(alpha: 0.85),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(responsive.rz(18)),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: responsive.rz(42),
            height: responsive.rz(42),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: AppColors.primary,
              size: responsive.rz(22),
            ),
          ),
          SizedBox(width: responsive.rz(12)),
          Expanded(
            child: Text(
              'Messages are HIPAA-secure and only visible to you and your care team.',
              style: responsiveTextStyle(
                context,
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareStatsRow extends StatelessWidget {
  const _CareStatsRow();

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Row(
      children: [
        Expanded(
          child: _ScheduleStatChip(
            icon: Icons.assignment_late_outlined,
            label: '1 due',
            color: AppColors.mood2,
          ),
        ),
        SizedBox(width: responsive.rz(10)),
        Expanded(
          child: _ScheduleStatChip(
            icon: Icons.library_books_outlined,
            label: '3 resources',
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: responsive.rz(10)),
        Expanded(
          child: _ScheduleStatChip(
            icon: Icons.favorite_rounded,
            label: 'Crisis help',
            color: AppColors.badge,
          ),
        ),
      ],
    );
  }
}

class _CareFeaturedCard extends StatelessWidget {
  const _CareFeaturedCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(responsive.rz(24)),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(responsive.rz(24)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF12103A),
                Color(0xFF1C1858),
                Color(0xFF2A2280),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(responsive.rz(20)),
            child: Row(
              children: [
                Container(
                  width: responsive.rz(52),
                  height: responsive.rz(52),
                  decoration: BoxDecoration(
                    color: AppColors.mood2.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.mood2.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: AppColors.mood2,
                    size: responsive.rz(26),
                  ),
                ),
                SizedBox(width: responsive.rz(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mood2.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Action needed',
                          style: responsiveTextStyle(
                            context,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mood2,
                          ),
                        ),
                      ),
                      SizedBox(height: responsive.rz(8)),
                      Text(
                        'Complete PHQ-9',
                        style: responsiveTextStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: responsive.rz(4)),
                      Text(
                        'Due Friday  ·  helps your care team support you',
                        style: responsiveTextStyle(
                          context,
                          fontSize: 13,
                          color: const Color(0xFFD8D6F0),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CareItemCard extends StatelessWidget {
  const _CareItemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.iconColor,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final Color iconColor;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Padding(
      padding: EdgeInsets.only(bottom: responsive.rz(10)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(responsive.rz(20)),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(responsive.rz(20)),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.85),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(responsive.rz(14)),
              child: Row(
                children: [
                  Container(
                    width: responsive.rz(48),
                    height: responsive.rz(48),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: responsive.rz(22),
                    ),
                  ),
                  SizedBox(width: responsive.rz(14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: responsiveTextStyle(
                                  context,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badge!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: iconColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: responsive.rz(3)),
                        Text(
                          subtitle,
                          style: responsiveTextStyle(
                            context,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CareCrisisCard extends StatelessWidget {
  const _CareCrisisCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(responsive.rz(20)),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.badge.withValues(alpha: 0.08),
                AppColors.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(responsive.rz(20)),
            border: Border.all(
              color: AppColors.badge.withValues(alpha: 0.22),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(responsive.rz(16)),
            child: Row(
              children: [
                Container(
                  width: responsive.rz(50),
                  height: responsive.rz(50),
                  decoration: BoxDecoration(
                    color: AppColors.badge.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.badge,
                    size: responsive.rz(24),
                  ),
                ),
                SizedBox(width: responsive.rz(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crisis resources',
                        style: responsiveTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: responsive.rz(4)),
                      Text(
                        '24/7 support contacts  ·  always available',
                        style: responsiveTextStyle(
                          context,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.badge.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '24/7',
                    style: TextStyle(
                      color: AppColors.badge,
                      fontSize: responsive.rz(11),
                      fontWeight: FontWeight.w800,
                    ),
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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).refreshProfile());
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.badge, size: 26),
            SizedBox(width: 8),
            Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account? All medical check-ins, appointments, messages, and profile data will be permanently removed. This cannot be undone.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.badge,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ref.read(authProvider.notifier).deleteAccount();
      if (!context.mounted) return;
      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInScreen()),
          (_) => false,
        );
      } else {
        final error = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to delete account'),
            backgroundColor: AppColors.badge,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final user = ref.watch(authProvider).user;
    final displayName = user?.name ?? 'Patient';
    final email = user?.email ?? '';
    final phone = user?.phone ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _ProfileBackground(),
          SafeArea(
            child: ResponsiveCenter(
              child: ListView(
                padding: responsive.pagePadding.copyWith(
                  top: responsive.rz(12),
                  bottom: responsive.rz(32),
                ),
                children: [

                  Text(
                    'Your account & preferences',
                    style: responsiveTextStyle(
                      context,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: responsive.rz(20)),
                  _ProfileHeroCard(
                    displayName: displayName,
                    email: email,
                    phone: phone,
                    initials: _initials(displayName),
                    avatarUrl: user?.avatarUrl ?? '',
                  ),
                  SizedBox(height: responsive.rz(22)),
                  _ProfileSectionTitle(title: 'Account'),
                  SizedBox(height: responsive.rz(12)),
                  _ProfileMenuTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Edit profile',
                    subtitle: 'Update your email or phone',
                    gradient: const [Color(0xFFEDE9FE), Color(0xFFD8D2FF)],
                    iconColor: AppColors.primary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  for (final section in AccountSection.values)
                    _ProfileMenuTile(
                      icon: section.icon,
                      title: section.label,
                      subtitle: switch (section) {
                        AccountSection.insurance => 'Coverage, benefits and insurance card',
                        AccountSection.documents => 'Photo ID and consent forms',
                        AccountSection.billing => 'Balance, payments and statements',
                      },
                      gradient: const [Color(0xFFEDE9FE), Color(0xFFD8D2FF)],
                      iconColor: AppColors.primary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AccountPortalScreen(initialSection: section),
                        ),
                      ),
                    ),
                  _ProfileMenuTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Reminders and care-team alerts',
                    gradient: const [Color(0xFFE8F4FF), Color(0xFFCCE8FF)],
                    iconColor: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  _ProfileMenuTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy & security',
                    subtitle: 'HIPAA-ready. Your data stays secure.',
                    gradient: const [Color(0xFFE8FBF0), Color(0xFFC9F0D8)],
                    iconColor: AppColors.mood5,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacySecurityScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: responsive.rz(22)),
                  _ProfileSectionTitle(title: 'Support'),
                  SizedBox(height: responsive.rz(12)),
                  _ProfileMenuTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help center',
                    subtitle: 'FAQs and contact support',
                    gradient: const [Color(0xFFFFF4E5), Color(0xFFFFE4C7)],
                    iconColor: AppColors.mood2,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HelpCenterScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: responsive.rz(24)),
                  _SignOutButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                        (_) => false,
                      );
                    },
                  ),
                  SizedBox(height: responsive.rz(14)),
                  _DeleteAccountButton(
                    onPressed: () => _confirmDeleteAccount(context),
                  ),
                  SizedBox(height: responsive.rz(16)),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: responsive.rz(16),
                          color: AppColors.primarySoft,
                        ),
                        SizedBox(width: responsive.rz(6)),
                        Text(
                          'Secured with end-to-end encryption',
                          style: responsiveTextStyle(
                            context,
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBackground extends StatelessWidget {
  const _ProfileBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 260,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.10),
              AppColors.primaryWash.withValues(alpha: 0.3),
              AppColors.background.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: responsiveTextStyle(
        context,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.displayName,
    required this.email,
    required this.phone,
    required this.initials,
    this.avatarUrl = '',
  });

  final String displayName;
  final String email;
  final String phone;
  final String initials;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(responsive.rz(26)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(responsive.rz(26)),
        child: ColoredBox(
          color: AppColors.surface,
          child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                responsive.rz(20),
                responsive.rz(22),
                responsive.rz(20),
                responsive.rz(52),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF12103A),
                    Color(0xFF1C1858),
                    Color(0xFF2A2280),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.health_and_safety_rounded,
                          size: responsive.rz(14),
                          color: const Color(0xFFD8D6F0),
                        ),
                        SizedBox(width: responsive.rz(6)),
                        Flexible(
                          child: Text(
                            'Altrixs patient',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: responsiveTextStyle(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFD8D6F0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(0, -responsive.rz(36)),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9B93F8), AppColors.primary],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: responsive.rz(38),
                      backgroundColor: AppColors.primary,
                      child: ClipOval(
                        child: avatarUrl.isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                width: responsive.rz(76),
                                height: responsive.rz(76),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: responsive.rz(26),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: responsive.rz(26),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.rz(12)),
                  Text(
                    displayName,
                    style: responsiveTextStyle(
                      context,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: responsive.rz(4)),
                  Text(
                    'Altrixs  ·  Maryland',
                    style: responsiveTextStyle(
                      context,
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.rz(16),
                0,
                responsive.rz(16),
                responsive.rz(18),
              ),
              child: Column(
                children: [
                  if (email.isNotEmpty)
                    _ProfileInfoChip(
                      icon: Icons.email_outlined,
                      label: email,
                    ),
                  if (email.isNotEmpty && phone.isNotEmpty)
                    SizedBox(height: responsive.rz(10)),
                  if (phone.isNotEmpty)
                    _ProfileInfoChip(
                      icon: Icons.phone_outlined,
                      label: phone,
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
}

class _ProfileInfoChip extends StatelessWidget {
  const _ProfileInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.rz(14),
        vertical: responsive.rz(12),
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryWash.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(responsive.rz(14)),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: responsive.rz(34),
            height: responsive.rz(34),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: responsive.rz(17), color: AppColors.primary),
          ),
          SizedBox(width: responsive.rz(12)),
          Expanded(
            child: Text(
              label,
              style: responsiveTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Padding(
      padding: EdgeInsets.only(bottom: responsive.rz(10)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(responsive.rz(20)),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(responsive.rz(20)),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.85),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(responsive.rz(14)),
              child: Row(
                children: [
                  Container(
                    width: responsive.rz(46),
                    height: responsive.rz(46),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: responsive.rz(22),
                    ),
                  ),
                  SizedBox(width: responsive.rz(14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: responsiveTextStyle(
                            context,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: responsive.rz(3)),
                        Text(
                          subtitle,
                          style: responsiveTextStyle(
                            context,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return SizedBox(
      width: double.infinity,
      height: responsive.rz(52),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.badge,
          side: BorderSide(
            color: AppColors.badge.withValues(alpha: 0.35),
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(responsive.rz(16)),
          ),
          backgroundColor: AppColors.badge.withValues(alpha: 0.06),
        ),
        icon: Icon(Icons.logout_rounded, size: responsive.rz(20)),
        label: Text(
          'Sign out',
          style: TextStyle(
            fontSize: responsive.rz(16),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.badge.withValues(alpha: 0.85),
          padding: EdgeInsets.symmetric(
            horizontal: responsive.rz(16),
            vertical: responsive.rz(8),
          ),
        ),
        icon: Icon(
          Icons.delete_outline_rounded,
          size: responsive.rz(18),
          color: AppColors.badge.withValues(alpha: 0.85),
        ),
        label: Text(
          'Delete account',
          style: TextStyle(
            fontSize: responsive.rz(13.5),
            fontWeight: FontWeight.w600,
            color: AppColors.badge.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
