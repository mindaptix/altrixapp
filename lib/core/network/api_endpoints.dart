class ApiEndpoints {
  const ApiEndpoints._();

  // Auth & onboarding (no token or Bearer token)
  static const patientLogin = '/api/patient/login';
  static const patientLogout = '/api/patient/logout';
  static const patientInvitePreview = '/api/patient/invite/preview';
  static const patientInviteAccept = '/api/patient/invite/accept';
  static const patientForgotPassword = '/api/patient/forgot-password';
  static const patientResetPassword = '/api/patient/reset-password';

  // Device / push notifications
  static const patientDeviceToken = '/api/patient/device-token';

  // Medications
  static const patientMedications = '/api/patient/medications';
  static const patientMedicationIntake = '/api/patient/medications/intake';

  // Profile & home
  static const patientMe = '/api/patient/me';
  static const patientAvatar = '/api/patient/avatar';
  static const patientDashboard = '/api/patient/dashboard';
  static const patientNotifications = '/api/patient/notifications';
  static const patientNotificationsReadAll =
      '/api/patient/notifications/read-all';
  static String patientNotificationRead(String id) =>
      '/api/patient/notifications/$id/read';
  static String patientNotification(String id) =>
      '/api/patient/notifications/$id';

  // Appointments
  static const patientAppointments = '/api/patient/appointments';
  static String patientAppointment(String id) =>
      '/api/patient/appointments/$id';
  static String patientAppointmentCancel(String id) =>
      '/api/patient/appointments/$id/cancel';
  static String patientAppointmentReschedule(String id) =>
      '/api/patient/appointments/$id/reschedule';

  // Doctors & slots
  static const patientDoctors = '/api/patient/doctors';
  static String patientDoctorAvailability(String doctorId) =>
      '/api/patient/doctors/$doctorId/availability';

  // Messages
  static const patientMessages = '/api/patient/messages';
  static const patientConversations = '/api/patient/conversations';
  static String patientConversationMessages(String conversationId) =>
      '/api/patient/conversations/$conversationId/messages';
  static String patientConversationStream(String conversationId) =>
      '/api/patient/conversations/$conversationId/stream';
  static String patientMessageRead(String messageId) =>
      '/api/patient/messages/$messageId/read';

  // Check-ins & progress
  static const patientCheckIns = '/api/patient/check-ins';
  static const patientProgress = '/api/patient/progress';

  // Forms & consents
  static const patientForms = '/api/patient/forms';
  static String patientForm(String id) => '/api/patient/forms/$id';

  // Telehealth (join token auth)
  static String telehealthJoin(String joinToken) =>
      '/api/telehealth/join/$joinToken';
  static const telehealthSignal = '/api/telehealth/signal';
}
