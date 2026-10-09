import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive/responsive.dart';
import '../core/responsive/responsive_widgets.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/notifications/presentation/providers/notification_activity_provider.dart';
import '../features/patient/data/utils/appointment_utils.dart';
import '../features/patient/data/models/patient_models.dart';
import '../features/patient/presentation/providers/patient_providers.dart';
import '../features/patient/presentation/screens/medications_screen.dart';
import '../features/resources/presentation/screens/resources_screen.dart';
import '../theme/app_colors.dart';
import '../features/coping/presentation/coping_tools_screen.dart';
import '../widgets/appointment_actions.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/app_buttons.dart';
import '../core/utils/usa_timezone_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onNavigateToTab});

  final ValueChanged<int>? onNavigateToTab;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(dashboardProvider);
  }

  String get _greeting {
    final tz = ref.watch(usaTimezoneProvider);
    final hour = UsaTimezoneService.nowInUs(timezone: tz).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _submitCheckIn({
    required int mood,
    required int stress,
    required int sleep,
    required String journal,
  }) async {
    try {
      await ref
          .read(patientRepositoryProvider)
          .createCheckIn(
            mood: mood,
            stress: stress,
            sleep: sleep,
            journal: journal,
          );
      if (!mounted) return;
      _toast('Check-in saved');
      ref.invalidate(progressProvider);
      ref.invalidate(dashboardProvider);
    } catch (error) {
      if (!mounted) return;
      _toast(friendlyErrorMessage(error));
      rethrow;
    }
  }

  void _openCheckInSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TodaysWellnessSheet(
        initialMood: 8,
        initialStress: 3,
        initialSleep: 7,
        initialJournal: '',
        onSubmit: _submitCheckIn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final user = ref.watch(authProvider).user;
    final userName = user?.name.trim() ?? '';
    final avatarUrl = user?.avatarUrl ?? '';
    final dashboardAsync = ref.watch(dashboardProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider);
    final progressAsync = ref.watch(progressProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const _HomeBackground(),
            SafeArea(
              bottom: false,
              child: ResponsiveCenter(
                child: ListView(
                  padding: responsive.pagePadding.copyWith(
                    top: responsive.rz(12),
                    bottom: responsive.rz(32),
                  ),
                  children: [
                    _Header(
                      greeting: _greeting,
                      userName: userName,
                      initials: _initials(userName),
                      avatarUrl: avatarUrl,
                      onAvatarTap: widget.onNavigateToTab != null
                          ? () => widget.onNavigateToTab!(3)
                          : null,
                      unreadNotifications:
                          ref.watch(unreadNotificationCountProvider),
                    ),
                    SizedBox(height: responsive.rz(22)),
                    appointmentsAsync.when(
                      loading: () => const _NextSessionSkeletonCard(),
                      error: (error, _) => InlineErrorCard(
                        message: friendlyErrorMessage(error),
                        onRetry: () => ref.invalidate(appointmentsProvider),
                      ),
                      data: (appointments) {
                        final next = nextAppointment(appointments);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (next != null)
                              _NextSessionCard(
                                appointment: next,
                                onJoin: () =>
                                    openAppointmentJoin(context, next),
                                onDirections: () =>
                                    openAppointmentDirections(context, next),
                              )
                            else
                              const _EmptyNextSessionCard(),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: responsive.rz(26)),
                    _SectionHeader(
                      title: 'Quick actions',
                      subtitle: 'Everything you need, one tap away',
                    ),
                    SizedBox(height: responsive.rz(14)),
                    _QuickActions(
                      onCoping: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CopingToolsScreen(),
                        ),
                      ),
                      onCheckIn: _openCheckInSheet,
                      onMessages: () => widget.onNavigateToTab?.call(2),
                      onMedications: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MedicationsScreen(),
                          ),
                        );
                      },
                      onResources: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ResourcesScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: responsive.rz(22)),
                    _CheckInCard(onCheckIn: _openCheckInSheet),
                    SizedBox(height: responsive.rz(16)),
                    _DashboardSummaryCard(
                      dashboardAsync: dashboardAsync,
                      onOpenMessages: () => widget.onNavigateToTab?.call(2),
                    ),
                    SizedBox(height: responsive.rz(16)),
                    // _UpcomingCard(
                    //   appointments: appointmentsAsync.maybeWhen(
                    //     data: homeUpcomingAppointments,
                    //     orElse: () => const <AppointmentModel>[],
                    //   ),
                    //   onViewAll: () => widget.onNavigateToTab?.call(1),
                    // ),
                    SizedBox(height: responsive.rz(16)),
                    _ProgressCard(progressAsync: progressAsync),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 280,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.10),
              AppColors.primaryWash.withValues(alpha: 0.35),
              AppColors.background.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

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
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: responsive.rz(3)),
          Text(
            subtitle!,
            style: responsiveTextStyle(
              context,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.userName,
    required this.initials,
    this.avatarUrl = '',
    this.onAvatarTap,
    this.unreadNotifications = 0,
  });

  final String greeting;
  final String userName;
  final String initials;
  final String avatarUrl;
  final VoidCallback? onAvatarTap;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final greetingText = userName.isEmpty ? greeting : '$greeting, $userName';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _TodayDateChip()),
            SizedBox(width: responsive.rz(10)),
            _NotificationButton(unreadCount: unreadNotifications),
          ],
        ),
        SizedBox(height: responsive.rz(18)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greetingText,
                    style: responsiveTextStyle(
                      context,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.7,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: responsive.rz(8)),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: responsive.rz(15),
                        color: AppColors.primarySoft,
                      ),
                      SizedBox(width: responsive.rz(4)),
                      Flexible(
                        child: Text(
                          'Altrixs  ·  Maryland',
                          style: responsiveTextStyle(
                            context,
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: responsive.rz(12)),
            _ProfileAvatar(
              initials: initials,
              avatarUrl: avatarUrl,
              onTap: onAvatarTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayDateChip extends StatelessWidget {
  const _TodayDateChip();

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final now = DateTime.now();
    final weekday = _weekdays[now.weekday - 1];
    final month = _months[now.month - 1];
    final day = now.day;
    final year = now.year;
    final isEvening = now.hour >= 17 || now.hour < 6;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.rz(12),
        vertical: responsive.rz(10),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface.withValues(alpha: 0.95),
            AppColors.primaryWash.withValues(alpha: 0.65),
          ],
        ),
        borderRadius: BorderRadius.circular(responsive.rz(18)),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: responsive.rz(46),
            height: responsive.rz(46),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9B93F8), AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(responsive.rz(14)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsive.rz(18),
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  month.substring(0, 3).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: responsive.rz(11),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: responsive.rz(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekday,
                  style: responsiveTextStyle(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: responsive.rz(2)),
                Text(
                  '$month $day, $year',
                  style: responsiveTextStyle(
                    context,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isEvening ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
            size: responsive.rz(18),
            color: isEvening
                ? const Color(0xFF8B83F6)
                : const Color(0xFFF0A05A),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    this.avatarUrl = '',
    this.onTap,
  });

  final String initials;
  final String avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final size = responsive.rz(52);

    final avatar = Container(
      width: size + 6,
      height: size + 6,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9B93F8), AppColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: AppColors.primary,
        child: ClipOval(
          child: avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: responsive.rz(16),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: responsive.rz(16),
                    ),
                  ),
                ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({this.unreadCount = 0});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final size = responsive.rz(52);
    final hasUnread = unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
        borderRadius: BorderRadius.circular(responsive.rz(18)),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface.withValues(alpha: 0.95),
                AppColors.primaryWash.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(responsive.rz(18)),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: responsive.rz(36),
                height: responsive.rz(36),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9B93F8), AppColors.primary],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  hasUnread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: responsive.rz(20),
                ),
              ),
              if (hasUnread) ...[
                Positioned(
                  right: responsive.rz(9),
                  top: responsive.rz(8),
                  child: Container(
                    width: responsive.rz(10),
                    height: responsive.rz(10),
                    decoration: BoxDecoration(
                      color: AppColors.badge.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: responsive.rz(-2),
                  top: responsive.rz(-2),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: unreadCount > 9
                          ? responsive.rz(5)
                          : responsive.rz(0),
                    ),
                    constraints: BoxConstraints(
                      minWidth: responsive.rz(23),
                      minHeight: responsive.rz(23),
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), AppColors.badge],
                      ),
                      shape: unreadCount > 9
                          ? BoxShape.rectangle
                          : BoxShape.circle,
                      borderRadius: unreadCount > 9
                          ? BorderRadius.circular(10)
                          : null,
                      border: Border.all(color: AppColors.surface, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.badge.withValues(alpha: 0.45),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    key: const ValueKey('home-notification-badge'),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsive.rz(11),
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNextSessionCard extends StatelessWidget {
  const _EmptyNextSessionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No upcoming session scheduled.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _NextSessionSkeletonCard extends StatefulWidget {
  const _NextSessionSkeletonCard({super.key});

  @override
  State<_NextSessionSkeletonCard> createState() =>
      _NextSessionSkeletonCardState();
}

class _NextSessionSkeletonCardState extends State<_NextSessionSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.35,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    required double borderRadius,
    required double opacity,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final op = _animation.value;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(responsive.rz(28)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF12103A), Color(0xFF1C1858), Color(0xFF221A6A)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            responsive.rz(22),
            responsive.rz(20),
            responsive.rz(18),
            responsive.rz(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top "Next session" pill skeleton
              _buildShimmerBox(
                width: responsive.rz(110.0),
                height: responsive.rz(24.0),
                borderRadius: 20,
                opacity: op * 0.45,
              ),
              SizedBox(height: responsive.rz(16.0)),

              // Title / DateTime skeleton line
              _buildShimmerBox(
                width: responsive.rz(220.0),
                height: responsive.rz(24.0),
                borderRadius: 8,
                opacity: op * 0.65,
              ),
              SizedBox(height: responsive.rz(8.0)),

              // Provider line skeleton
              _buildShimmerBox(
                width: responsive.rz(150.0),
                height: responsive.rz(16.0),
                borderRadius: 6,
                opacity: op * 0.4,
              ),
              SizedBox(height: responsive.rz(14.0)),

              // Duration badge skeleton
              _buildShimmerBox(
                width: responsive.rz(130.0),
                height: responsive.rz(26.0),
                borderRadius: 12,
                opacity: op * 0.35,
              ),
              SizedBox(height: responsive.rz(20.0)),

              // Join Zoom button skeleton
              _buildShimmerBox(
                width: double.infinity,
                height: responsive.rz(50.0),
                borderRadius: 28,
                opacity: op * 0.8,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({
    required this.appointment,
    required this.onJoin,
    required this.onDirections,
  });

  final AppointmentModel appointment;
  final VoidCallback onJoin;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(responsive.rz(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(responsive.rz(28)),
        child: Stack(
          children: [
            const Positioned(
              right: -30,
              top: -30,
              child: _GlowOrb(size: 120, opacity: 0.18),
            ),
            const Positioned(
              left: -20,
              bottom: -40,
              child: _GlowOrb(size: 100, opacity: 0.12),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                responsive.rz(22),
                responsive.rz(20),
                responsive.rz(18),
                responsive.rz(14),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF12103A),
                    Color(0xFF1C1858),
                    Color(0xFF221A6A),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final showGraphic = constraints.maxWidth > 340;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.22,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primarySoft.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _LiveDot(),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Next session',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFD8D6F0),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: responsive.rz(14)),
                                Text(
                                  appointment.displayWhen.isNotEmpty
                                      ? appointment.displayWhen
                                      : appointment.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: responsiveTextStyle(
                                    context,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                    height: 1.1,
                                  ),
                                ),
                                SizedBox(height: responsive.rz(6)),
                                Text(
                                  appointment.providerName.isNotEmpty
                                      ? appointment.providerName
                                      : 'Your care team',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: responsiveTextStyle(
                                    context,
                                    fontSize: 15,
                                    color: const Color(0xFFD8D6F0),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: responsive.rz(12)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.videocam_rounded,
                                        size: 16,
                                        color: Color(0xFFC4C0EA),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          appointment.isVirtual
                                              ? (appointment.duration.isNotEmpty
                                                    ? 'Video duration: ${appointment.duration}'
                                                    : 'Video duration: 50 min')
                                              : '${appointment.visitType}  ·  ${appointment.duration}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: responsiveTextStyle(
                                            context,
                                            fontSize: 13,
                                            color: const Color(0xFFC4C0EA),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (showGraphic) const _CalendarGraphic(),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: responsive.rz(18)),
                  if (appointment.isVirtual && appointment.hasJoinLink)
                    SizedBox(
                      width: double.infinity,
                      height: responsive.rz(50),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B83F6), AppColors.primary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: FilledButton.icon(
                          onPressed: onJoin,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            textStyle: TextStyle(
                              fontSize: responsive.rz(16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: const Icon(Icons.videocam_rounded, size: 21),
                          label: const Text('Join Zoom'),
                        ),
                      ),
                    ),
                  if (!appointment.isVirtual && appointment.location.isNotEmpty)
                    Center(
                      child: TextButton.icon(
                        onPressed: onDirections,
                        icon: const Icon(
                          Icons.near_me_rounded,
                          size: 16,
                          color: Color(0xFFB7B3E8),
                        ),
                        label: const Text(
                          'Get directions',
                          style: TextStyle(
                            color: Color(0xFFB7B3E8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFF5EC77A),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySoft.withValues(alpha: opacity),
      ),
    );
  }
}

class _CalendarGraphic extends StatelessWidget {
  const _CalendarGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 80,
      child: CustomPaint(painter: _CalendarClockPainter()),
    );
  }
}

class _CalendarClockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF8B83F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cal = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 10, 58, 50),
      const Radius.circular(10),
    );
    canvas.drawRRect(cal, stroke);
    canvas.drawLine(const Offset(8, 26), const Offset(66, 26), stroke);
    canvas.drawLine(const Offset(22, 8), const Offset(22, 16), stroke);
    canvas.drawLine(const Offset(52, 8), const Offset(52, 16), stroke);

    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        canvas.drawCircle(
          Offset(20.0 + col * 14, 36.0 + row * 12),
          2.2,
          stroke..style = PaintingStyle.fill,
        );
      }
    }
    stroke.style = PaintingStyle.stroke;

    final clockCenter = Offset(size.width - 18, size.height - 18);
    canvas.drawCircle(
      clockCenter,
      16,
      Paint()..color = const Color(0xFF161445),
    );
    canvas.drawCircle(clockCenter, 16, stroke);
    canvas.drawLine(clockCenter, clockCenter + const Offset(0, -8), stroke);
    canvas.drawLine(clockCenter, clockCenter + const Offset(8, 4), stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onCheckIn,
    required this.onMessages,
    required this.onMedications,
    required this.onResources,
    required this.onCoping,
  });

  final VoidCallback onCheckIn;
  final VoidCallback onMessages;
  final VoidCallback onMedications;
  final VoidCallback onResources;
  final VoidCallback onCoping;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final actions = [
      (
        Icons.favorite_outline_rounded,
        'Check in',
        const [Color(0xFFFFE8EC), Color(0xFFFFC9D4)],
        AppColors.badge,
        onCheckIn,
      ),
      (
        Icons.chat_bubble_outline_rounded,
        'Messages',
        const [Color(0xFFEDE9FE), Color(0xFFD8D2FF)],
        AppColors.primary,
        onMessages,
      ),
      (
        Icons.medication_outlined,
        'Meds',
        const [Color(0xFFE8F4FF), Color(0xFFCCE8FF)],
        const Color(0xFF3B82F6),
        onMedications,
      ),
      (
        Icons.spa_outlined,
        'Coping tools',
        const [Color(0xFFEDE9FE), Color(0xFFD8D2FF)],
        AppColors.primary,
        onCoping,
      ),
      (
        Icons.menu_book_outlined,
        'Resources',
        const [Color(0xFFE8FBF0), Color(0xFFC9F0D8)],
        AppColors.mood5,
        onResources,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = responsive.rz(10);
        final itemWidth = ((constraints.maxWidth - gap * 3) / 4).clamp(
          68.0,
          100.0,
        );

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              _QuickAction(
                width: itemWidth,
                icon: actions[i].$1,
                label: actions[i].$2,
                gradient: actions[i].$3,
                iconColor: actions[i].$4,
                onTap: actions[i].$5,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.width,
    required this.icon,
    required this.label,
    required this.gradient,
    required this.iconColor,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final circleSize = responsive.rz(58).clamp(50.0, 72.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: responsive.rz(24)),
              ),
              SizedBox(height: responsive.rz(9)),
              Text(
                label,
                textAlign: TextAlign.center,
                style: responsiveTextStyle(
                  context,
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.onCheckIn});

  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: responsive.rz(40),
                height: responsive.rz(40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryMuted, AppColors.primaryWash],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.self_improvement_rounded,
                  color: AppColors.primary,
                  size: responsive.rz(22),
                ),
              ),
              SizedBox(width: responsive.rz(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Wellness",
                      style: responsiveTextStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Daily wellness check-in',
                      style: responsiveTextStyle(
                        context,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.rz(16)),
          Row(
            children: [
              _CheckInPreviewPill(
                emoji: '😊',
                label: 'Mood',
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
              ),
              SizedBox(width: responsive.rz(8)),
              _CheckInPreviewPill(
                emoji: '😌',
                label: 'Stress',
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
              ),
              SizedBox(width: responsive.rz(8)),
              _CheckInPreviewPill(
                emoji: '😴',
                label: 'Sleep',
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFDBEAFE),
              ),
              SizedBox(width: responsive.rz(8)),
              _CheckInPreviewPill(
                emoji: '📝',
                label: 'Journal',
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFD1FAE5),
              ),
            ],
          ),
          SizedBox(height: responsive.rz(16)),
          SoftButton(label: 'Check in now', onPressed: onCheckIn),
        ],
      ),
    );
  }
}

class _CheckInPreviewPill extends StatelessWidget {
  const _CheckInPreviewPill({
    required this.emoji,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final String emoji;
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: responsive.rz(8)),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(emoji, style: TextStyle(fontSize: responsive.rz(16))),
            SizedBox(height: responsive.rz(2)),
            Text(
              label,
              style: TextStyle(
                fontSize: responsive.rz(11),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaysWellnessSheet extends StatefulWidget {
  const _TodaysWellnessSheet({
    required this.initialMood,
    required this.initialStress,
    required this.initialSleep,
    this.initialJournal = '',
    required this.onSubmit,
  });

  final int initialMood;
  final int initialStress;
  final int initialSleep;
  final String initialJournal;
  final Future<void> Function({
    required int mood,
    required int stress,
    required int sleep,
    required String journal,
  })
  onSubmit;

  @override
  State<_TodaysWellnessSheet> createState() => _TodaysWellnessSheetState();
}

class _TodaysWellnessSheetState extends State<_TodaysWellnessSheet> {
  late int _mood;
  late int _stress;
  late int _sleep;
  late final TextEditingController _journalController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _mood = widget.initialMood;
    _stress = widget.initialStress;
    _sleep = widget.initialSleep;
    _journalController = TextEditingController(text: widget.initialJournal);
  }

  @override
  void dispose() {
    _journalController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final journalText = _journalController.text.trim();
      await widget.onSubmit(
        mood: _mood,
        stress: _stress,
        sleep: _sleep,
        journal: journalText,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              SizedBox(height: responsive.rz(16)),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Wellness",
                          style: responsiveTextStyle(
                            context,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: responsive.rz(2)),
                        Text(
                          'Track how you feel today',
                          style: responsiveTextStyle(
                            context,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              SizedBox(height: responsive.rz(18)),
              _WellnessSliderTile(
                emoji: '😊',
                label: 'Mood',
                valueText: '$_mood/10',
                value: _mood.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: const Color(0xFF8B5CF6),
                badgeBgColor: const Color(0xFFF3E8FF),
                badgeTextColor: const Color(0xFF7C3AED),
                onChanged: (val) => setState(() => _mood = val.round()),
              ),
              SizedBox(height: responsive.rz(14)),
              _WellnessSliderTile(
                emoji: '😌',
                label: 'Stress',
                valueText: '$_stress/10',
                value: _stress.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: const Color(0xFFF59E0B),
                badgeBgColor: const Color(0xFFFEF3C7),
                badgeTextColor: const Color(0xFFD97706),
                onChanged: (val) => setState(() => _stress = val.round()),
              ),
              SizedBox(height: responsive.rz(14)),
              _WellnessSliderTile(
                emoji: '😴',
                label: 'Sleep',
                valueText: '$_sleep hrs',
                value: _sleep.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: const Color(0xFF3B82F6),
                badgeBgColor: const Color(0xFFDBEAFE),
                badgeTextColor: const Color(0xFF2563EB),
                onChanged: (val) => setState(() => _sleep = val.round()),
              ),
              SizedBox(height: responsive.rz(18)),
              Text(
                '📝 Journal',
                style: responsiveTextStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: responsive.rz(8)),
              TextField(
                controller: _journalController,
                maxLines: 3,
                style: responsiveTextStyle(
                  context,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Write your journal notes here...',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
              SizedBox(height: responsive.rz(22)),
              PrimaryButton(
                label: 'Submit',
                loading: _isSubmitting,
                onPressed: _handleSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WellnessSliderTile extends StatelessWidget {
  const _WellnessSliderTile({
    required this.emoji,
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.activeColor,
    required this.badgeBgColor,
    required this.badgeTextColor,
    required this.onChanged,
  });

  final String emoji;
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color activeColor;
  final Color badgeBgColor;
  final Color badgeTextColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.rz(14),
        vertical: responsive.rz(12),
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(emoji, style: TextStyle(fontSize: responsive.rz(18))),
                  SizedBox(width: responsive.rz(8)),
                  Text(
                    label,
                    style: responsiveTextStyle(
                      context,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.rz(10),
                  vertical: responsive.rz(4),
                ),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  valueText,
                  style: TextStyle(
                    fontSize: responsive.rz(13),
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.rz(4)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10,
              trackShape: const RoundedRectSliderTrackShape(),
              activeTrackColor: activeColor,
              inactiveTrackColor: activeColor.withValues(alpha: 0.15),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
                elevation: 3,
              ),
              overlayColor: activeColor.withValues(alpha: 0.15),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSummaryCard extends StatelessWidget {
  const _DashboardSummaryCard({
    required this.dashboardAsync,
    this.onOpenMessages,
  });

  final AsyncValue<DashboardModel> dashboardAsync;
  final VoidCallback? onOpenMessages;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return _SurfaceCard(
      child: dashboardAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'Your dashboard',
              subtitle: 'Wellness overview from your care team',
            ),
            SizedBox(height: responsive.rz(12)),
            InlineErrorCard(message: friendlyErrorMessage(error)),
          ],
        ),
        data: (dashboard) {
          final updates = [
            ...dashboard.pendingTasks,
            ...dashboard.reminders,
            ...dashboard.notifications,
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Your dashboard',
                subtitle: 'Wellness overview from your care team',
              ),
              SizedBox(height: responsive.rz(14)),
              Wrap(
                spacing: responsive.rz(10),
                runSpacing: responsive.rz(10),
                children: [
                  _DashboardStatChip(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Messages',
                    value: '${dashboard.unreadMessages}',
                    onTap: onOpenMessages,
                  ),
                  _DashboardStatChip(
                    icon: Icons.task_alt_rounded,
                    label: 'Tasks',
                    value: '${dashboard.pendingTasks.length}',
                  ),
                  _DashboardStatChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Check-ins',
                    value: '${dashboard.weeklyCheckInsCompleted}',
                  ),
                  _DashboardStatChip(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Streak',
                    value: '${dashboard.checkInStreak}',
                  ),
                ],
              ),
              SizedBox(height: responsive.rz(16)),
              _DashboardStatusRow(
                icon: dashboard.todayCheckInCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                iconColor: dashboard.todayCheckInCompleted
                    ? AppColors.mood5
                    : AppColors.textSecondary,
                title: dashboard.todayCheckInCompleted
                    ? "Today's check-in complete"
                    : "Today's check-in not done yet",
                subtitle: _formatWellnessLine(
                  mood: dashboard.todayMood,
                  stress: dashboard.todayStress,
                  sleep: dashboard.todaySleep,
                  fallback: dashboard.todayCheckInCompleted
                      ? 'Thanks for checking in today.'
                      : 'Use the check-in card above when you are ready.',
                ),
              ),
              if (dashboard.latestMood != null ||
                  dashboard.latestStress != null ||
                  dashboard.latestSleep != null) ...[
                SizedBox(height: responsive.rz(10)),
                _DashboardStatusRow(
                  icon: Icons.insights_rounded,
                  iconColor: AppColors.primary,
                  title: 'Latest scores',
                  subtitle: _formatWellnessLine(
                    mood: dashboard.latestMood,
                    stress: dashboard.latestStress,
                    sleep: dashboard.latestSleep,
                  ),
                ),
              ],
              if (dashboard.weeklyAverageMood != null ||
                  dashboard.weeklyAverageStress != null ||
                  dashboard.weeklyAverageSleep != null) ...[
                SizedBox(height: responsive.rz(14)),
                Text(
                  'This week',
                  style: responsiveTextStyle(
                    context,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: responsive.rz(10)),
                Row(
                  children: [
                    Expanded(
                      child: _WellnessMetricTile(
                        label: 'Mood',
                        value: _formatScore(dashboard.weeklyAverageMood),
                      ),
                    ),
                    SizedBox(width: responsive.rz(8)),
                    Expanded(
                      child: _WellnessMetricTile(
                        label: 'Stress',
                        value: _formatScore(dashboard.weeklyAverageStress),
                      ),
                    ),
                    SizedBox(width: responsive.rz(8)),
                    Expanded(
                      child: _WellnessMetricTile(
                        label: 'Sleep',
                        value: _formatScore(dashboard.weeklyAverageSleep),
                      ),
                    ),
                  ],
                ),
              ],
              if (dashboard.recommendedWellnessTool.isNotEmpty) ...[
                SizedBox(height: responsive.rz(14)),
                _DashboardStatusRow(
                  icon: Icons.spa_rounded,
                  iconColor: AppColors.primary,
                  title: 'Recommended for you',
                  subtitle: _titleCase(dashboard.recommendedWellnessTool),
                ),
              ],
              if (dashboard.safetyPlanAvailable) ...[
                SizedBox(height: responsive.rz(10)),
                _DashboardStatusRow(
                  icon: Icons.shield_outlined,
                  iconColor: dashboard.safetyPlanSigned
                      ? AppColors.mood5
                      : AppColors.mood3,
                  title: 'Safety plan',
                  subtitle: dashboard.safetyPlanSigned
                      ? 'Signed and on file'
                      : 'Available — review with your care team',
                ),
              ],
              if (updates.isNotEmpty) ...[
                SizedBox(height: responsive.rz(16)),
                Text(
                  'Updates & tasks',
                  style: responsiveTextStyle(
                    context,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: responsive.rz(10)),
                for (final item in updates.take(3))
                  Padding(
                    padding: EdgeInsets.only(bottom: responsive.rz(10)),
                    child: _DashboardUpdateTile(item: item),
                  ),
              ] else ...[
                SizedBox(height: responsive.rz(14)),
                Text(
                  'No pending tasks or notifications right now.',
                  style: responsiveTextStyle(
                    context,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DashboardStatChip extends StatelessWidget {
  const _DashboardStatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: responsive.rz(150),
          padding: EdgeInsets.symmetric(
            horizontal: responsive.rz(12),
            vertical: responsive.rz(12),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: responsive.rz(22),
                color: label == 'Streak'
                    ? const Color(0xFFE77948)
                    : AppColors.primary,
              ),
              SizedBox(width: responsive.rz(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: responsiveTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      label,
                      style: responsiveTextStyle(
                        context,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
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

class _DashboardStatusRow extends StatelessWidget {
  const _DashboardStatusRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: responsive.rz(20), color: iconColor),
        SizedBox(width: responsive.rz(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: responsiveTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                SizedBox(height: responsive.rz(2)),
                Text(
                  subtitle,
                  style: responsiveTextStyle(
                    context,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardUpdateTile extends StatelessWidget {
  const _DashboardUpdateTile({required this.item});

  final DashboardItem item;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      padding: EdgeInsets.all(responsive.rz(14)),
      decoration: BoxDecoration(
        color: AppColors.primaryWash.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.displayText,
            style: responsiveTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (item.formattedTime.isNotEmpty) ...[
            SizedBox(height: responsive.rz(4)),
            Text(
              item.formattedTime,
              style: responsiveTextStyle(
                context,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WellnessMetricTile extends StatelessWidget {
  const _WellnessMetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    final (icon, color, background) = switch (label) {
      'Mood' => (
        Icons.sentiment_satisfied_alt_outlined,
        const Color(0xFF6B3FA0),
        const Color(0xFFF3EDFC),
      ),
      'Stress' => (
        Icons.spa_outlined,
        const Color(0xFFCD9B22),
        const Color(0xFFFFF8E1),
      ),
      'Sleep' => (
        Icons.bedtime_outlined,
        const Color(0xFF138B80),
        const Color(0xFFE2F4F2),
      ),
      _ => (Icons.insights_outlined, AppColors.primary, AppColors.background),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.rz(10),
        vertical: responsive.rz(12),
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: responsive.rz(25)),
          SizedBox(height: responsive.rz(8)),
          Text(
            value,
            style: responsiveTextStyle(
              context,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: responsive.rz(2)),
          Text(
            label,
            style: responsiveTextStyle(
              context,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatScore(double? value) {
  if (value == null) return '—';
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

String _formatWellnessLine({
  double? mood,
  double? stress,
  double? sleep,
  String fallback = '',
}) {
  final parts = <String>[];
  if (mood != null) parts.add('Mood ${_formatScore(mood)}');
  if (stress != null) parts.add('Stress ${_formatScore(stress)}');
  if (sleep != null) parts.add('Sleep ${_formatScore(sleep)}');
  if (parts.isEmpty) return fallback;
  return parts.join(' · ');
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

Color _riskLevelColor(String riskLevel) {
  switch (riskLevel.toLowerCase()) {
    case 'high':
      return AppColors.badge;
    case 'medium':
    case 'moderate':
      return AppColors.mood3;
    case 'low':
    default:
      return AppColors.mood5;
  }
}

// class _UpcomingCard extends StatelessWidget {
//   const _UpcomingCard({
//     required this.appointments,
//     this.onViewAll,
//   });

//   final List<AppointmentModel> appointments;
//   final VoidCallback? onViewAll;

//   @override
//   Widget build(BuildContext context) {
//     final responsive = context.responsive;

//     return _SurfaceCard(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const _SectionHeader(
//             title: 'Upcoming',
//             subtitle: 'More scheduled visits',
//           ),
//           SizedBox(height: responsive.rz(16)),
//           if (appointments.isEmpty)
//             Text(
//               'No more upcoming visits on home.',
//               style: responsiveTextStyle(
//                 context,
//                 fontSize: 14,
//                 color: AppColors.textSecondary,
//               ),
//             )
//           else
//             for (final appointment in appointments)
//               Padding(
//                 padding: EdgeInsets.only(bottom: responsive.rz(10)),
//                 child: _UpcomingAppointmentRow(appointment: appointment),
//               ),
//           if (onViewAll != null) ...[
//             SizedBox(height: responsive.rz(8)),
//             Align(
//               alignment: Alignment.centerLeft,
//               child: TextButton(
//                 onPressed: onViewAll,
//                 child: const Text('View all in Schedule'),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

class _UpcomingAppointmentRow extends StatelessWidget {
  const _UpcomingAppointmentRow({required this.appointment});

  final AppointmentModel appointment;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Container(
      padding: EdgeInsets.all(responsive.rz(12)),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: responsive.rz(42),
            height: responsive.rz(42),
            decoration: BoxDecoration(
              color: AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              appointment.isVirtual
                  ? Icons.videocam_rounded
                  : Icons.location_on_rounded,
              color: AppColors.primary,
              size: responsive.rz(20),
            ),
          ),
          SizedBox(width: responsive.rz(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.displayWhen.isNotEmpty
                      ? appointment.displayWhen
                      : appointment.title,
                  style: responsiveTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: responsive.rz(2)),
                Text(
                  appointment.subtitleLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: responsiveTextStyle(
                    context,
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progressAsync});

  final AsyncValue<ProgressModel> progressAsync;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Your progress',
            subtitle: 'Weekly wellness trends',
          ),
          SizedBox(height: responsive.rz(14)),
          progressAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            error: (error, _) =>
                InlineErrorCard(message: friendlyErrorMessage(error)),
            data: (progress) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${progress.streak ?? 0}',
                              style: responsiveTextStyle(
                                context,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'day streak',
                              style: responsiveTextStyle(
                                context,
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (progress.riskLevel.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.rz(12),
                            vertical: responsive.rz(8),
                          ),
                          decoration: BoxDecoration(
                            color: _riskLevelColor(progress.riskLevel)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_titleCase(progress.riskLevel)} risk',
                            style: responsiveTextStyle(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _riskLevelColor(progress.riskLevel),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: responsive.rz(16)),
                  Row(
                    children: [
                      Expanded(
                        child: _WellnessMetricTile(
                          label: 'Mood',
                          value: _formatScore(progress.averageMood),
                        ),
                      ),
                      SizedBox(width: responsive.rz(8)),
                      Expanded(
                        child: _WellnessMetricTile(
                          label: 'Stress',
                          value: _formatScore(progress.averageStress),
                        ),
                      ),
                      SizedBox(width: responsive.rz(8)),
                      Expanded(
                        child: _WellnessMetricTile(
                          label: 'Sleep',
                          value: _formatScore(progress.averageSleep),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.rz(12)),
                  Text(
                    '${progress.checkInsCount ?? 0} check-ins completed this week',
                    style: responsiveTextStyle(
                      context,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (progress.displaySummary.isNotEmpty) ...[
                    SizedBox(height: responsive.rz(8)),
                    Text(
                      progress.displaySummary,
                      style: responsiveTextStyle(
                        context,
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (progress.moodTrend.isNotEmpty) ...[
                    SizedBox(height: responsive.rz(16)),
                    _DailyMoodGraph(
                      moodTrend: progress.moodTrend,
                      averageMood: progress.averageMood,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DailyMoodGraph extends StatefulWidget {
  const _DailyMoodGraph({required this.moodTrend, this.averageMood});

  final List<int> moodTrend;
  final num? averageMood;

  @override
  State<_DailyMoodGraph> createState() => _DailyMoodGraphState();
}

class _DailyMoodGraphState extends State<_DailyMoodGraph> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    if (widget.moodTrend.isNotEmpty) {
      _selectedIndex = widget.moodTrend.length - 1;
    }
  }

  LinearGradient _gradientForScore(int score) {
    if (score >= 8) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF34D399), Color(0xFF059669)],
      );
    }
    if (score >= 6) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
      );
    }
    if (score >= 4) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
    );
  }

  Color _colorForScore(int score) {
    if (score >= 8) return const Color(0xFF10B981);
    if (score >= 6) return const Color(0xFF6366F1);
    if (score >= 4) return const Color(0xFFF59E0B);
    return const Color(0xFFF43F5E);
  }

  String _moodLabel(int score) {
    if (score >= 9) return 'Excellent 🤩';
    if (score >= 8) return 'Very Good 😊';
    if (score >= 6) return 'Good / Calm 😌';
    if (score >= 4) return 'Neutral 😐';
    if (score >= 2) return 'Low Energy 😔';
    return 'Challenging 💔';
  }

  String _dayNameForIndex(int index, int total) {
    final dayOffset = total - 1 - index;
    final date = DateTime.now().subtract(Duration(days: dayOffset));
    if (dayOffset == 0) return 'Today';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final trend = widget.moodTrend.length > 7
        ? widget.moodTrend.sublist(widget.moodTrend.length - 7)
        : widget.moodTrend;
    final total = trend.length;
    final selectedIdx = (_selectedIndex != null && _selectedIndex! < total)
        ? _selectedIndex!
        : (total - 1);
    final selectedMood = trend[selectedIdx];
    final selectedDay = _dayNameForIndex(selectedIdx, total);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.rz(16)),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(responsive.rz(20)),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: responsive.rz(34),
                height: responsive.rz(34),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B83F6), AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(responsive.rz(10)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              SizedBox(width: responsive.rz(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily mood',
                      style: responsiveTextStyle(
                        context,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '7-day emotional wellness pattern',
                      style: responsiveTextStyle(
                        context,
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.averageMood != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.rz(10),
                    vertical: responsive.rz(4),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(responsive.rz(20)),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Avg ${widget.averageMood!.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: responsive.rz(11),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: responsive.rz(14)),

          // Selected Day Mood Status Banner
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.rz(12),
              vertical: responsive.rz(8),
            ),
            decoration: BoxDecoration(
              color: _colorForScore(selectedMood).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(responsive.rz(12)),
              border: Border.all(
                color: _colorForScore(selectedMood).withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 15,
                      color: _colorForScore(selectedMood),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      selectedDay == 'Today'
                          ? "Today's Mood"
                          : '$selectedDay Mood',
                      style: responsiveTextStyle(
                        context,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$selectedMood/10 · ${_moodLabel(selectedMood)}',
                  style: responsiveTextStyle(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _colorForScore(selectedMood),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: responsive.rz(14)),

          // Chart Canvas
          Container(
            height: responsive.rz(132),
            padding: EdgeInsets.symmetric(
              horizontal: responsive.rz(6),
              vertical: responsive.rz(8),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(responsive.rz(16)),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Stack(
              children: [
                // Horizontal reference grid lines (dashed)
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDashedLine(),
                    _buildDashedLine(),
                    _buildDashedLine(),
                  ],
                ),

                // Bars Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < total; i++) ...[
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() => _selectedIndex = i);
                          },
                          child: _buildBarColumn(
                            context: context,
                            responsive: responsive,
                            score: trend[i],
                            dayLabel: _dayNameForIndex(i, total),
                            isSelected: i == selectedIdx,
                            isToday: i == total - 1,
                          ),
                        ),
                      ),
                      if (i < total - 1) SizedBox(width: responsive.rz(4)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: responsive.rz(12)),

          // Color Legend Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendDot(const Color(0xFF10B981), '8–10 Great'),
              _buildLegendDot(const Color(0xFF6366F1), '6–7 Good'),
              _buildLegendDot(const Color(0xFFF59E0B), '4–5 Neutral'),
              _buildLegendDot(const Color(0xFFF43F5E), '1–3 Low'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          children: List.generate(count, (_) {
            return Container(
              width: dashWidth,
              height: 1,
              margin: const EdgeInsets.only(right: dashSpace),
              color: const Color(0xFFE2E8F0),
            );
          }),
        );
      },
    );
  }

  Widget _buildBarColumn({
    required BuildContext context,
    required Responsive responsive,
    required int score,
    required String dayLabel,
    required bool isSelected,
    required bool isToday,
  }) {
    final normalized = (score.clamp(0, 10) / 10).clamp(0.15, 1.0);
    final color = _colorForScore(score);
    final gradient = _gradientForScore(score);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Top Score Value
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$score',
            maxLines: 1,
            style: TextStyle(
              fontSize: responsive.rz(isSelected ? 11.0 : 9.5),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? color : AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(height: responsive.rz(2.0)),

        // Bar with Background Slot
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxBarHeight = constraints.maxHeight;
                final barHeight = (maxBarHeight * normalized).clamp(
                  8.0,
                  maxBarHeight,
                );
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Background Slot Capsule
                    Container(
                      width: responsive.rz(14.0),
                      height: maxBarHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(responsive.rz(7.0)),
                      ),
                    ),

                    // Active Filled Bar
                    Container(
                      width: responsive.rz(isSelected ? 15.0 : 12.0),
                      height: barHeight,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(responsive.rz(7.0)),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.45),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 1.5)
                            : null,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        SizedBox(height: responsive.rz(4.0)),

        // Bottom Day Label
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.rz(2.0),
            vertical: responsive.rz(1.0),
          ),
          decoration: isSelected
              ? BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(responsive.rz(5.0)),
                )
              : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isToday ? 'Today' : dayLabel,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: responsive.rz(isToday || isSelected ? 9.5 : 9.0),
                fontWeight: isToday || isSelected
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: isSelected
                    ? color
                    : (isToday
                          ? AppColors.textPrimary
                          : AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        responsive.rz(18),
        responsive.rz(18),
        responsive.rz(18),
        responsive.rz(18),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(responsive.rz(24)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
