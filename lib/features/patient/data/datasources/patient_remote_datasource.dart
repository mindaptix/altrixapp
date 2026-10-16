import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../models/medication_model.dart';
import '../models/patient_models.dart';

class PatientRemoteDataSource {
  const PatientRemoteDataSource(this._dio);

  final Dio _dio;

  void _ensureApiConfigured() {
    if (!Env.isApiConfigured) {
      throw const ApiException(
        'API URL is not configured yet. Add API_BASE_URL when your backend is ready.',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<Map<String, dynamic>>> Function() call,
  ) async {
    _ensureApiConfigured();
    try {
      final response = await call();
      final data = response.data;
      if (data == null) {
        throw const ApiException('Empty response from server');
      }
      requireApiSuccess(data);
      return data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<InvitePreviewModel> previewInvite(String token) async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(
        ApiEndpoints.patientInvitePreview,
        queryParameters: {'token': token},
      ),
    );
    return InvitePreviewModel.fromJson(data);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(ApiEndpoints.patientMe),
    );
    return unwrapApiPayload(data);
  }

  Future<Map<String, dynamic>> updateProfile({
    String? phone,
    String? addressLine1,
    String? city,
    String? state,
    String? postalCode,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? insurancePayer,
    String? insuranceMemberId,
    String? insuranceGroupNumber,
  }) async {
    final data = await _request(
      () => _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.patientMe,
        data: {
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (addressLine1 != null && addressLine1.isNotEmpty) ...{
            'addressLine1': addressLine1,
            'address': addressLine1,
          },
          if (city != null && city.isNotEmpty) 'city': city,
          if (state != null && state.isNotEmpty) 'state': state,
          if (postalCode != null && postalCode.isNotEmpty) ...{
            'postalCode': postalCode,
            'zipCode': postalCode,
          },
          if (emergencyContactName != null && emergencyContactName.isNotEmpty)
            'emergencyContactName': emergencyContactName,
          if (emergencyContactPhone != null && emergencyContactPhone.isNotEmpty)
            'emergencyContactPhone': emergencyContactPhone,
          if (insurancePayer != null) 'insurancePayer': insurancePayer.trim(),
          if (insuranceMemberId != null)
            'insuranceMemberId': insuranceMemberId.trim(),
          if (insuranceGroupNumber != null)
            'insuranceGroupNumber': insuranceGroupNumber.trim(),
        },
      ),
    );
    return unwrapApiPayload(data);
  }

  Future<DashboardModel> getDashboard() async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(ApiEndpoints.patientDashboard),
    );
    return DashboardModel.fromJson(data);
  }

  Future<PatientNotificationPage> getNotifications({
    int page = 1,
    int limit = 50,
    bool unreadOnly = false,
    String? type,
  }) async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(
        ApiEndpoints.patientNotifications,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (unreadOnly) 'unreadOnly': true,
          if (type?.trim().isNotEmpty == true) 'type': type!.trim(),
        },
      ),
    );
    return PatientNotificationPage.fromJson(data);
  }

  Future<void> markNotificationRead(String id) async {
    await _request(
      () => _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.patientNotificationRead(id),
      ),
    );
  }

  Future<void> markAllNotificationsRead() async {
    await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.patientNotificationsReadAll,
      ),
    );
  }

  Future<void> deleteNotification(String id) async {
    await _request(
      () => _dio.delete<Map<String, dynamic>>(
        ApiEndpoints.patientNotification(id),
      ),
    );
  }

  Future<List<AppointmentModel>> getAppointments() async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(
        ApiEndpoints.patientAppointments,
        queryParameters: const {'includePast': true, 'includeCancelled': true},
      ),
    );

    final rootData = data['data'];
    final List<Map<String, dynamic>> items;
    if (rootData is List) {
      items = asJsonMapList(rootData);
    } else {
      final payload = unwrapApiPayload(data);
      items = extractListFromPayload(
        payload,
        keys: const ['appointments', 'items'],
      );
    }

    return items.map(AppointmentModel.fromJson).toList();
  }

  Future<AppointmentModel> getAppointment(String id) async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(ApiEndpoints.patientAppointment(id)),
    );
    final payload = unwrapApiPayload(data);
    final appointment = payload['appointment'];
    if (appointment is Map<String, dynamic>) {
      return AppointmentModel.fromJson(appointment);
    }
    return AppointmentModel.fromJson(payload);
  }

  Future<AppointmentModel> bookAppointment({
    required String clinicianId,
    required String type,
    required String date,
    required String startTime,
    String? endTime,
    required bool isVirtual,
  }) async {
    final data = await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.patientAppointments,
        data: {
          'clinicianId': clinicianId,
          'type': type,
          'date': date,
          'startTime': startTime,
          'endTime': ?endTime,
          'isVirtual': isVirtual,
        },
      ),
    );
    final payload = unwrapApiPayload(data);
    final appointment = payload['appointment'];
    if (appointment is Map<String, dynamic>) {
      return AppointmentModel.fromJson(appointment);
    }
    return AppointmentModel.fromJson(payload);
  }

  Future<AppointmentModel> cancelAppointment(
    String id, {
    String? reason,
  }) async {
    final data = await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.patientAppointmentCancel(id),
        data: {if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim()},
      ),
    );
    final payload = unwrapApiPayload(data);
    final appointment = payload['appointment'];
    if (appointment is Map<String, dynamic>) {
      return AppointmentModel.fromJson(appointment);
    }
    return AppointmentModel.fromJson(payload);
  }

  Future<AppointmentModel> rescheduleAppointment({
    required String id,
    required String date,
    required String startTime,
    String? endTime,
    String? note,
  }) async {
    final data = await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.patientAppointmentReschedule(id),
        data: {
          'date': date,
          'startTime': startTime,
          'endTime': ?endTime,
          'note': ?note,
        },
      ),
    );
    final payload = unwrapApiPayload(data);
    final appointment = payload['appointment'];
    if (appointment is Map<String, dynamic>) {
      return AppointmentModel.fromJson(appointment);
    }
    return AppointmentModel.fromJson(payload);
  }

  Future<List<DoctorModel>> getDoctors() async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(ApiEndpoints.patientDoctors),
    );
    final payload = unwrapApiPayload(data);
    return extractListFromPayload(
      payload,
      keys: const ['doctors', 'items'],
    ).map(DoctorModel.fromJson).toList();
  }

  Future<List<AvailabilitySlotModel>> getDoctorAvailability({
    required String doctorId,
    String? from,
    int? days,
  }) async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(
        ApiEndpoints.patientDoctorAvailability(doctorId),
        queryParameters: {'from': ?from, 'days': ?days},
      ),
    );
    final payload = unwrapApiPayload(data);
    return extractListFromPayload(
      payload,
      keys: const ['slots', 'availability', 'items'],
    ).map(AvailabilitySlotModel.fromJson).toList();
  }

  Future<List<ConversationModel>> getConversations() async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(ApiEndpoints.patientConversations),
    );
    final payload = unwrapApiPayload(data);
    return extractListFromPayload(
      payload,
      keys: const ['conversations', 'items'],
    ).map(ConversationModel.fromJson).toList();
  }

  Future<ConversationModel> createConversation({
    required String topic,
    required String message,
  }) async {
    final data = await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.patientConversations,
        data: {'topic': topic, 'message': message},
      ),
    );
    final payload = unwrapApiPayload(data);
    final conversation = payload['conversation'];
    if (conversation is Map<String, dynamic>) {
      return ConversationModel.fromJson(conversation);
    }
    return ConversationModel.fromJson(payload);
  }

  /// Fetch chat messages history
  /// `GET /api/patient/conversations/<THREAD_ID>/messages` or fallback `GET /api/patient/messages`
  Future<({String threadId, List<MessageModel> messages})> getPatientMessages({
    String? threadId,
  }) async {
    String resolvedThreadId = threadId ?? '';

    // If threadId is not provided, discover the latest active conversation
    if (resolvedThreadId.isEmpty) {
      try {
        final conversations = await getConversations();
        if (conversations.isNotEmpty) {
          resolvedThreadId = conversations.first.id;
        }
      } catch (_) {}
    }

    if (resolvedThreadId.isNotEmpty) {
      try {
        final messages = await getConversationMessages(
          conversationId: resolvedThreadId,
        );
        return (threadId: resolvedThreadId, messages: messages);
      } catch (_) {}
    }

    // Fallback route: GET /api/patient/messages
    try {
      final data = await _request(
        () => _dio.get<Map<String, dynamic>>(
          ApiEndpoints.patientMessages,
          queryParameters: resolvedThreadId.isNotEmpty
              ? {'threadId': resolvedThreadId}
              : null,
        ),
      );
      final payload = unwrapApiPayload(data);
      final id = readString(payload, ['threadId', 'thread_id', 'id']);
      final rawMessages = extractListFromPayload(
        payload,
        keys: const ['messages', 'items'],
      );
      final messages = rawMessages.map(MessageModel.fromJson).toList();
      return (
        threadId: id.isNotEmpty ? id : resolvedThreadId,
        messages: messages,
      );
    } catch (_) {
      if (resolvedThreadId.isNotEmpty) {
        final messages = await getConversationMessages(
          conversationId: resolvedThreadId,
        );
        return (threadId: resolvedThreadId, messages: messages);
      }
      return (threadId: '', messages: <MessageModel>[]);
    }
  }

  /// Send new message (REST fallback)
  /// `POST /api/patient/conversations/<THREAD_ID>/messages` or fallback `POST /api/patient/messages`
  Future<MessageModel> sendPatientMessage({
    required String content,
    String? threadId,
  }) async {
    String resolvedThreadId = threadId ?? '';

    // If no threadId given, discover existing conversation or create a new one
    if (resolvedThreadId.isEmpty) {
      try {
        final conversations = await getConversations();
        if (conversations.isNotEmpty) {
          resolvedThreadId = conversations.first.id;
        } else {
          final newConvo = await createConversation(
            topic: 'general',
            message: content,
          );
          resolvedThreadId = newConvo.id;
          return MessageModel(
            id: 'convo_${DateTime.now().millisecondsSinceEpoch}',
            threadId: resolvedThreadId,
            body: content,
            sender: 'patient',
            senderName: 'You',
            createdAt: DateTime.now().toIso8601String(),
            isRead: true,
            raw: const {},
          );
        }
      } catch (_) {}
    }

    if (resolvedThreadId.isNotEmpty) {
      try {
        return await sendMessage(
          conversationId: resolvedThreadId,
          message: content,
        );
      } catch (_) {}
    }

    final data = await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.patientMessages,
        data: {
          'content': content,
          'message': content,
          if (resolvedThreadId.isNotEmpty) 'threadId': resolvedThreadId,
        },
      ),
    );
    final payload = unwrapApiPayload(data);
    final item = payload['message'];
    if (item is Map<String, dynamic>) {
      return MessageModel.fromJson(item);
    }
    return MessageModel.fromJson(payload);
  }

  Future<List<MessageModel>> getConversationMessages({
    required String conversationId,
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(
        ApiEndpoints.patientConversationMessages(conversationId),
        queryParameters: {'page': page, 'limit': limit},
      ),
    );
    final payload = unwrapApiPayload(data);
    return extractListFromPayload(
      payload,
      keys: const ['messages', 'items'],
    ).map(MessageModel.fromJson).toList();
  }

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String message,
  }) async {
    final data = await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.patientConversationMessages(conversationId),
        data: {'message': message},
      ),
    );
    final payload = unwrapApiPayload(data);
    final item = payload['message'];
    if (item is Map<String, dynamic>) {
      return MessageModel.fromJson(item);
    }
    return MessageModel.fromJson(payload);
  }

  Future<void> markMessageRead(String messageId) async {
    await _request(
      () => _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.patientMessageRead(messageId),
        data: const {},
      ),
    );
  }

  Future<List<CheckInModel>> getCheckIns({
    int? page,
    int limit = 20,
    int? skip,
    String? from,
    String? to,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'skip': ?skip,
      if (page != null && skip == null) 'page': page,
      'from': ?from,
      'to': ?to,
    };
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(
        ApiEndpoints.patientCheckIns,
        queryParameters: queryParams,
      ),
    );
    final payload = unwrapApiPayload(data);
    return extractListFromPayload(
      payload,
      keys: const ['checkIns', 'check_ins', 'items'],
    ).map(CheckInModel.fromJson).toList();
  }

  Future<CheckInModel> createCheckIn({
    required int mood,
    required int stress,
    int sleep = 7,
    String journal = 'Feeling much better today and rested well.',
  }) async {
    final journalText = journal.trim().isNotEmpty
        ? journal.trim()
        : 'Feeling much better today and rested well.';
    final payload = <String, dynamic>{
      'mood': mood.clamp(1, 10),
      'stress': stress.clamp(1, 10),
      'sleep': sleep.clamp(1, 10),
      'journal': journalText,
    };

    final data = await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.patientCheckIns,
        data: payload,
      ),
    );
    final unwrapped = unwrapApiPayload(data);
    final item = unwrapped['checkIn'] ?? unwrapped['check_in'];
    if (item is Map<String, dynamic>) {
      return CheckInModel.fromJson(item);
    }
    return CheckInModel.fromJson(unwrapped);
  }

  Future<ProgressModel> getProgress() async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(ApiEndpoints.patientProgress),
    );
    return ProgressModel.fromJson(data);
  }

  Future<TelehealthSessionModel> getTelehealthSession(String joinToken) async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(
        ApiEndpoints.telehealthJoin(joinToken),
      ),
    );
    return TelehealthSessionModel.fromJson(data);
  }

  Future<Map<String, dynamic>> markTelehealthHere(String joinToken) async {
    final data = await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.telehealthJoin(joinToken),
        data: const {'action': 'here'},
      ),
    );
    return unwrapApiPayload(data);
  }

  Future<Map<String, dynamic>> pollTelehealthSignal({
    required String joinToken,
    int after = 0,
  }) async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(
        ApiEndpoints.telehealthSignal,
        queryParameters: {'token': joinToken, 'after': after},
      ),
    );
    return unwrapApiPayload(data);
  }

  Future<Map<String, dynamic>> sendTelehealthSignal({
    required String joinToken,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final response = await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.telehealthSignal,
        data: {
          'token': joinToken,
          'from': 'client',
          'type': type,
          'data': data ?? const {},
        },
      ),
    );
    return unwrapApiPayload(response);
  }

  Future<List<PatientFormModel>> getForms({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(
        ApiEndpoints.patientForms,
        queryParameters: {'page': page, 'limit': limit},
      ),
    );
    final payload = unwrapApiPayload(data);
    return extractListFromPayload(
      payload,
      keys: const ['forms', 'items'],
    ).map(PatientFormModel.fromJson).toList();
  }

  Future<PatientFormModel> getForm(String id) async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(ApiEndpoints.patientForm(id)),
    );
    final payload = unwrapApiPayload(data);
    final form = payload['form'];
    if (form is Map<String, dynamic>) {
      return PatientFormModel.fromJson(form);
    }
    return PatientFormModel.fromJson(payload);
  }

  /// POST /api/patient/logout
  Future<void> logout() async {
    await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.patientLogout,
        data: const {},
      ),
    );
  }

  /// DELETE /api/patient/me
  Future<void> deleteAccount() async {
    await _request(
      () => _dio.delete<Map<String, dynamic>>(ApiEndpoints.patientMe),
    );
  }

  /// POST /api/patient/avatar (Multipart)
  Future<String?> uploadAvatar(String filePath) async {
    _ensureApiConfigured();
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });

    final data = await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.patientAvatar,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      ),
    );

    final payload = unwrapApiPayload(data);
    final clientMap = payload['client'] is Map<String, dynamic>
        ? payload['client'] as Map<String, dynamic>
        : (payload['patient'] is Map<String, dynamic>
              ? payload['patient'] as Map<String, dynamic>
              : const <String, dynamic>{});
    final rawUrl = readString(
      payload,
      [
        'avatarUrl',
        'avatar_url',
        'avatar',
        'image',
        'imageUrl',
        'image_url',
        'photoUrl',
        'photo_url',
        'url',
      ],
      fallback: readString(clientMap, [
        'avatarUrl',
        'avatar_url',
        'avatar',
        'image',
        'imageUrl',
        'image_url',
        'photoUrl',
        'photo_url',
        'url',
      ]),
    );

    return rawUrl.isNotEmpty ? resolveMediaUrl(rawUrl) : null;
  }

  /// GET /api/patient/medications
  /// Returns all active medication schedules with today's intake log.
  Future<List<MedicationScheduleModel>> getMedications() async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(ApiEndpoints.patientMedications),
    );
    final payload = unwrapApiPayload(data);
    final rawList =
        payload['medications'] ??
        payload['schedules'] ??
        payload['data'] ??
        data['medications'] ??
        data['data'];
    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map(
            (e) =>
                MedicationScheduleModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    }
    return const [];
  }

  /// POST /api/patient/medications/intake
  /// Records that a patient took or skipped a dose.
  Future<void> logMedicationIntake({
    required String scheduleId,
    required String doseTime,
    required String status, // "taken" or "skipped"
  }) async {
    final timeParts = doseTime.split(':');
    if (timeParts.length != 2) {
      throw ArgumentError.value(doseTime, 'doseTime', 'Expected HH:mm format');
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw ArgumentError.value(doseTime, 'doseTime', 'Expected HH:mm format');
    }

    final now = DateTime.now();
    final scheduledFor = DateTime(now.year, now.month, now.day, hour, minute);

    await _request(
      () => _dio.post<Map<String, dynamic>>(
        ApiEndpoints.patientMedicationIntake,
        data: {
          'scheduleId': scheduleId,
          'scheduledFor': scheduledFor.toIso8601String(),
          'taken': status == 'taken',
          'skipped': status == 'skipped',
        },
      ),
    );
  }

  /// Real-Time Live Message Stream (SSE)
  /// GET /api/patient/conversations/`THREAD_ID`/stream
  Stream<Map<String, dynamic>> streamLiveMessages({
    required String threadId,
    required String token,
  }) async* {
    _ensureApiConfigured();
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;

    try {
      final uri = Uri.parse(
        '${Env.apiBaseUrl}${ApiEndpoints.patientConversationStream(threadId)}',
      );
      final request = await client.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Accept', 'text/event-stream');
      final response = await request.close();

      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6).trim();
          if (jsonStr.isNotEmpty) {
            try {
              final payload = jsonDecode(jsonStr);
              if (payload is Map<String, dynamic>) {
                yield payload;
              }
            } catch (_) {}
          }
        }
      }
    } finally {
      client.close(force: true);
    }
  }
}
