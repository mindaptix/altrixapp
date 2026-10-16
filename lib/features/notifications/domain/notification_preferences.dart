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
      dailyCheckInReminders:
          dailyCheckInReminders ?? this.dailyCheckInReminders,
      medicationReminders: medicationReminders ?? this.medicationReminders,
      clinicAnnouncements: clinicAnnouncements ?? this.clinicAnnouncements,
      emailDigest: emailDigest ?? this.emailDigest,
      smsAlerts: smsAlerts ?? this.smsAlerts,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    );
  }
}
