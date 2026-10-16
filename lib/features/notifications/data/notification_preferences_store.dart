import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_preferences.dart';

class NotificationPreferencesStore {
  const NotificationPreferencesStore(this._preferences);

  final SharedPreferences _preferences;

  static const _keyPush = 'notif_pref_push';
  static const _keyAppointment = 'notif_pref_appt';
  static const _keyCareTeam = 'notif_pref_care';
  static const _keyCheckIn = 'notif_pref_checkin';
  static const _keyMedication = 'notif_pref_meds';
  static const _keyClinic = 'notif_pref_clinic';
  static const _keyEmail = 'notif_pref_email';
  static const _keySms = 'notif_pref_sms';
  static const _keyQuietHours = 'notif_pref_quiet';

  NotificationPreferences load() {
    return NotificationPreferences(
      pushEnabled: _preferences.getBool(_keyPush) ?? true,
      appointmentReminders: _preferences.getBool(_keyAppointment) ?? true,
      careTeamMessages: _preferences.getBool(_keyCareTeam) ?? true,
      dailyCheckInReminders: _preferences.getBool(_keyCheckIn) ?? true,
      medicationReminders: _preferences.getBool(_keyMedication) ?? true,
      clinicAnnouncements: _preferences.getBool(_keyClinic) ?? false,
      emailDigest: _preferences.getBool(_keyEmail) ?? true,
      smsAlerts: _preferences.getBool(_keySms) ?? true,
      quietHoursEnabled: _preferences.getBool(_keyQuietHours) ?? false,
    );
  }

  Future<void> save(NotificationPreferences value) async {
    await Future.wait([
      _preferences.setBool(_keyPush, value.pushEnabled),
      _preferences.setBool(_keyAppointment, value.appointmentReminders),
      _preferences.setBool(_keyCareTeam, value.careTeamMessages),
      _preferences.setBool(_keyCheckIn, value.dailyCheckInReminders),
      _preferences.setBool(_keyMedication, value.medicationReminders),
      _preferences.setBool(_keyClinic, value.clinicAnnouncements),
      _preferences.setBool(_keyEmail, value.emailDigest),
      _preferences.setBool(_keySms, value.smsAlerts),
      _preferences.setBool(_keyQuietHours, value.quietHoursEnabled),
    ]);
  }
}
