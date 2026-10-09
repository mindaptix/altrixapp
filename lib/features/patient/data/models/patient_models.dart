import '../../../../core/network/api_response.dart';
import '../../../../core/utils/usa_timezone_service.dart';

class AppointmentModel {
  const AppointmentModel({
    required this.id,
    required this.title,
    required this.providerName,
    required this.dateLabel,
    required this.timeLabel,
    required this.endTimeLabel,
    required this.visitType,
    required this.duration,
    required this.isVirtual,
    required this.status,
    required this.joinToken,
    required this.joinUrl,
    required this.location,
    required this.note,
    required this.sortDateTime,
    this.endDateTime,
    required this.raw,
  });

  final String id;
  final String title;
  final String providerName;
  final String dateLabel;
  final String timeLabel;
  final String endTimeLabel;
  final String visitType;
  final String duration;
  final bool isVirtual;
  final String status;
  final String joinToken;
  final String joinUrl;
  final String location;
  final String note;
  final DateTime? sortDateTime;
  final DateTime? endDateTime;
  final Map<String, dynamic> raw;

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final nestedProvider = _readNestedName(json, [
      'clinician',
      'doctor',
      'provider',
      'therapist',
    ]);

    final type = readString(json, ['type', 'visitType', 'visit_type', 'title']);
    final virtualFlag = readBool(json, ['isVirtual', 'is_virtual', 'virtual']);
    final typeLower = type.toLowerCase();
    final isVirtual =
        virtualFlag ||
        typeLower.contains('virtual') ||
        typeLower.contains('telehealth') ||
        typeLower.contains('video');

    final date = readString(json, ['date', 'dateLabel', 'date_label', 'day']);
    final startTime = readString(json, [
      'startTime',
      'start_time',
      'time',
      'timeLabel',
      'time_label',
    ]);
    final endTime = readString(json, ['endTime', 'end_time']);
    final startsAt = readString(json, [
      'startsAt',
      'starts_at',
      'scheduledAt',
      'scheduled_at',
    ]);
    final endsAt = readString(json, ['endsAt', 'ends_at']);
    final sortDateTime = _parseSortDateTime(
      startsAt: startsAt,
      date: date,
      startTime: startTime,
    );
    final endSortDateTime = _parseSortDateTime(
      startsAt: endsAt,
      date: date,
      startTime: endTime,
    );

    final formattedDate = _formatDateLabel(sortDateTime, date);
    final formattedStart = _formatTimeLabel(startTime, sortDateTime);
    final formattedEnd = _formatTimeLabel(endTime, endSortDateTime);

    return AppointmentModel(
      id: readString(json, ['id', '_id']),
      title: type.isNotEmpty ? type : 'Appointment',
      providerName: readString(json, [
        'providerName',
        'provider_name',
        'clinicianName',
        'clinician_name',
        'doctorName',
        'doctor_name',
        'provider',
      ], fallback: nestedProvider),
      dateLabel: formattedDate,
      timeLabel: formattedStart,
      endTimeLabel: formattedEnd,
      visitType: isVirtual ? 'Video visit' : 'In-person visit',
      duration: _formatDuration(
        startTime: startTime,
        endTime: endTime,
        fallback: readString(json, [
          'duration',
          'durationLabel',
        ], fallback: '50 min'),
      ),
      isVirtual: isVirtual,
      status: readString(json, ['status', 'state'], fallback: 'scheduled'),
      joinToken: readString(json, [
        'joinToken',
        'join_token',
        'telehealthToken',
      ]),
      joinUrl: readString(json, [
        'joinUrl',
        'join_url',
        'meetingUrl',
        'meeting_url',
      ]),
      location: readString(json, [
        'location',
        'address',
        'clinicName',
        'clinic_name',
      ]),
      note: readString(json, ['note', 'notes', 'reason']),
      sortDateTime: sortDateTime,
      endDateTime:
          endSortDateTime ??
          (sortDateTime != null
              ? sortDateTime.add(const Duration(minutes: 50))
              : null),
      raw: json,
    );
  }

  String get displayWhen {
    if (dateLabel.isNotEmpty && timeLabel.isNotEmpty) {
      return '$dateLabel  ·  $timeLabel';
    }
    if (dateLabel.isNotEmpty) return dateLabel;
    if (timeLabel.isNotEmpty) return timeLabel;
    return readString(raw, [
      'startsAt',
      'starts_at',
      'scheduledAt',
      'scheduled_at',
    ]);
  }

  String get subtitleLine {
    final parts = <String>[
      if (providerName.isNotEmpty) providerName,
      visitType,
      if (duration.isNotEmpty) duration,
    ];
    return parts.join('  ·  ');
  }

  String get effectiveJoinUrl {
    if (joinUrl.isNotEmpty) return joinUrl;
    final parsed = readString(raw, [
      'joinUrl',
      'join_url',
      'meetingUrl',
      'meeting_url',
      'zoomUrl',
      'zoom_url',
      'url',
    ]);
    if (parsed.isNotEmpty) return parsed;
    if (isVirtual) {
      final seed = id.isNotEmpty ? id : clinicianId;
      final numericPart = seed.replaceAll(RegExp(r'[^0-9]'), '');
      final meetingId = numericPart.length >= 10
          ? numericPart.substring(0, 10)
          : '${seed.hashCode.abs()}'.padRight(10, '7').substring(0, 10);
      return 'https://zoom.us/j/$meetingId';
    }
    return '';
  }

  bool get hasJoinLink =>
      effectiveJoinUrl.trim().isNotEmpty || joinToken.trim().isNotEmpty;

  String get clinicianId => readString(
    raw,
    ['clinicianId', 'clinician_id'],
    fallback: raw['clinician'] is Map<String, dynamic>
        ? readString(raw['clinician'] as Map<String, dynamic>, ['id'])
        : '',
  );

  bool get canManage {
    final start =
        DateTime.tryParse(readString(raw, ['startsAt', 'starts_at'])) ??
        sortDateTime;
    return id.isNotEmpty &&
        start != null &&
        start.isAfter(DateTime.now()) &&
        const {
          'pending',
          'confirmed',
          'scheduled',
          'reschedule_requested',
        }.contains(status.toLowerCase());
  }

  /// Whether the appointment is joinable at [currentTime] (defaults to DateTime.now()).
  /// Patients can join starting 5 minutes before the scheduled start time
  /// until the scheduled session concludes.
  bool canJoinMeeting([DateTime? currentTime]) {
    final start = sortDateTime;
    if (start == null) return true;

    final now = currentTime ?? DateTime.now();
    final joinWindowStart = start.subtract(const Duration(minutes: 5));
    final sessionEnd = endDateTime ?? start.add(const Duration(minutes: 60));

    return !now.isBefore(joinWindowStart) && !now.isAfter(sessionEnd);
  }

  /// Whether the appointment is more than 5 minutes away from starting.
  bool isTooEarlyToJoin([DateTime? currentTime]) {
    final start = sortDateTime;
    if (start == null) return false;

    final now = currentTime ?? DateTime.now();
    final joinWindowStart = start.subtract(const Duration(minutes: 5));
    return now.isBefore(joinWindowStart);
  }

  /// Whether the appointment has already concluded.
  bool isMeetingConcluded([DateTime? currentTime]) {
    final start = sortDateTime;
    if (start == null) return false;

    final now = currentTime ?? DateTime.now();
    final sessionEnd = endDateTime ?? start.add(const Duration(minutes: 60));
    return now.isAfter(sessionEnd);
  }
}

String _readNestedName(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map<String, dynamic>) {
      final name = readString(value, [
        'name',
        'fullName',
        'full_name',
        'title',
      ]);
      if (name.isNotEmpty) return name;
    }
  }
  return '';
}

DateTime? _parseSortDateTime({
  required String startsAt,
  required String date,
  required String startTime,
}) {
  final normalizedDate = date.contains('T') ? date.split('T').first : date;
  if (normalizedDate.isNotEmpty && startTime.isNotEmpty) {
    // Also support 12-hour AM/PM times e.g. "10:00 AM" or "02:30 PM"
    final clockMatch = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(startTime.trim());
    if (clockMatch != null) {
      var hour = int.tryParse(clockMatch.group(1)!);
      final minute = int.tryParse(clockMatch.group(2)!);
      final period = clockMatch.group(3)?.toUpperCase();
      if (hour != null && minute != null) {
        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        final timeFormatted =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
        final parsed = DateTime.tryParse('${normalizedDate}T$timeFormatted');
        if (parsed != null) return parsed;
      }
    }

    final time = startTime.length == 5 ? '$startTime:00' : startTime;
    final parsed = DateTime.tryParse('${normalizedDate}T$time');
    if (parsed != null) return parsed;
  }

  if (startsAt.isNotEmpty) {
    final parsed = DateTime.tryParse(startsAt);
    if (parsed != null) {
      return parsed;
    }
  }
  if (normalizedDate.isNotEmpty) {
    return DateTime.tryParse(normalizedDate);
  }
  return null;
}

String _formatDateLabel(DateTime? sortDateTime, String rawDate) {
  if (sortDateTime != null) {
    return UsaTimezoneService.formatRelativeDate(sortDateTime);
  }
  return rawDate;
}

String _formatTimeLabel(String rawTime, DateTime? fallbackDateTime) {
  final trimmed = rawTime.trim();
  if (trimmed.isNotEmpty) {
    if (RegExp(
      r'^\d{1,2}:\d{2}\s*(?:AM|PM)$',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return trimmed;
    }
    final clockMatch = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$')
        .firstMatch(trimmed);
    if (clockMatch != null) {
      final hour = int.tryParse(clockMatch.group(1)!);
      final minute = int.tryParse(clockMatch.group(2)!);
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour < 24 &&
          minute >= 0 &&
          minute < 60) {
        final period = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour % 12 == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return '$hour12:${minute.toString().padLeft(2, '0')} $period';
      }
    }
  }

  if (fallbackDateTime != null) {
    return UsaTimezoneService.formatTime(fallbackDateTime, includeTz: false);
  }
  return rawTime;
}

String _formatDuration({
  required String startTime,
  required String endTime,
  required String fallback,
}) {
  if (startTime.isEmpty || endTime.isEmpty) return fallback;

  final start = _minutesFromClock(startTime);
  final end = _minutesFromClock(endTime);
  if (start == null || end == null || end <= start) return fallback;

  final minutes = end - start;
  if (minutes % 60 == 0) return '${minutes ~/ 60} hr';
  return '$minutes min';
}

int? _minutesFromClock(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return hour * 60 + minute;
}

class DoctorModel {
  const DoctorModel({
    required this.id,
    required this.name,
    required this.title,
    required this.specialty,
    required this.raw,
  });

  final String id;
  final String name;
  final String title;
  final String specialty;
  final Map<String, dynamic> raw;

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: readString(json, ['id', '_id', 'clinicianId', 'clinician_id']),
      name: readString(json, ['name', 'fullName', 'full_name']),
      title: readString(json, ['title', 'credentials']),
      specialty: readString(json, ['specialty', 'role', 'type']),
      raw: json,
    );
  }
}

class AvailabilitySlotModel {
  const AvailabilitySlotModel({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.raw,
  });

  final String date;
  final String startTime;
  final String endTime;
  final Map<String, dynamic> raw;

  // Missing availability must never make an unverified slot bookable.
  bool get isAvailable => raw['available'] == true;

  factory AvailabilitySlotModel.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlotModel(
      date: readString(json, ['date', 'day']),
      startTime: readString(json, ['startTime', 'start_time', 'from']),
      endTime: readString(json, ['endTime', 'end_time', 'to']),
      raw: json,
    );
  }
}

class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.title,
    required this.preview,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.topic,
    this.avatarUrl = '',
    this.participantName = '',
    this.participantRole = '',
    required this.raw,
  });

  final String id;
  final String title;
  final String preview;
  final String lastMessageAt;
  final int unreadCount;
  final String topic;
  final String avatarUrl;
  final String participantName;
  final String participantRole;
  final Map<String, dynamic> raw;

  String get effectiveName {
    if (participantName.isNotEmpty) return participantName;
    if (title.isNotEmpty) return title;
    return 'Care Team';
  }

  String get initials {
    final name = effectiveName.trim();
    if (name.isEmpty) return 'CT';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'C';
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get displayTime {
    if (lastMessageAt.isEmpty) return '';
    final dt = DateTime.tryParse(lastMessageAt)?.toLocal();
    if (dt == null) return lastMessageAt;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0 && now.day == dt.day) {
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$hour12:$minute $period';
    }
    if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dt.day)) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dt.weekday - 1];
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final participant =
        json['participant'] ??
        json['clinician'] ??
        json['doctor'] ??
        json['user'];
    var pName = '';
    var pAvatar = '';
    var pRole = '';
    if (participant is Map<String, dynamic>) {
      pName = readString(participant, [
        'name',
        'fullName',
        'full_name',
        'title',
      ]);
      pAvatar = readString(participant, [
        'avatar',
        'avatarUrl',
        'avatar_url',
        'imageUrl',
        'photoUrl',
      ]);
      pRole = readString(participant, ['role', 'title', 'specialty']);
    }

    final title = readString(json, [
      'title',
      'name',
      'clinicName',
      'clinic_name',
      'doctorName',
      'doctor_name',
      'clinicianName',
      'clinician_name',
    ]);

    return ConversationModel(
      id: readString(json, ['id', '_id', 'conversationId']),
      title: title,
      preview: readString(json, [
        'preview',
        'lastMessage',
        'last_message',
        'message',
        'body',
      ]),
      lastMessageAt: readString(json, [
        'lastMessageAt',
        'last_message_at',
        'updatedAt',
        'updated_at',
        'time',
      ]),
      unreadCount:
          readInt(json, ['unreadCount', 'unread_count', 'unread']) ?? 0,
      topic: readString(json, ['topic', 'category']),
      avatarUrl: pAvatar.isNotEmpty
          ? pAvatar
          : readString(json, [
              'avatar',
              'avatarUrl',
              'avatar_url',
              'imageUrl',
              'photoUrl',
            ]),
      participantName: pName,
      participantRole: pRole.isNotEmpty
          ? pRole
          : readString(json, ['role', 'participantRole', 'participant_role']),
      raw: json,
    );
  }
}

class MessageModel {
  const MessageModel({
    required this.id,
    this.threadId = '',
    required this.body,
    required this.sender,
    required this.createdAt,
    required this.isRead,
    this.senderName = '',
    this.senderAvatar = '',
    this.isPending = false,
    this.hasError = false,
    required this.raw,
  });

  final String id;
  final String threadId;
  final String body;
  final String sender;
  final String createdAt;
  final bool isRead;
  final String senderName;
  final String senderAvatar;
  final bool isPending;
  final bool hasError;
  final Map<String, dynamic> raw;

  MessageModel copyWith({
    String? id,
    String? threadId,
    String? body,
    String? sender,
    String? createdAt,
    bool? isRead,
    String? senderName,
    String? senderAvatar,
    bool? isPending,
    bool? hasError,
    Map<String, dynamic>? raw,
  }) {
    return MessageModel(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      body: body ?? this.body,
      sender: sender ?? this.sender,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      isPending: isPending ?? this.isPending,
      hasError: hasError ?? this.hasError,
      raw: raw ?? this.raw,
    );
  }

  bool isFromMe({String? currentUserId, String? currentUserName}) {
    final s = sender.toLowerCase().trim();
    if (s == 'clinician' || s == 'doctor' || s == 'provider') {
      return false;
    }
    if (s == 'patient' || s == 'client' || s == 'me' || s == 'user') {
      return true;
    }
    final rawSenderId = readString(raw, [
      'senderId',
      'sender_id',
      'clientId',
      'client_id',
      'userId',
      'user_id',
      'authorId',
    ]);
    if (currentUserId != null &&
        currentUserId.isNotEmpty &&
        rawSenderId.isNotEmpty) {
      if (rawSenderId == currentUserId) return true;
    }
    if (currentUserName != null && currentUserName.isNotEmpty) {
      if (senderName.isNotEmpty &&
          senderName.toLowerCase().trim() ==
              currentUserName.toLowerCase().trim()) {
        return true;
      }
    }
    return false;
  }

  String get initials {
    final name = senderName.isNotEmpty
        ? senderName
        : (sender.isNotEmpty ? sender : 'CT');
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'C';
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get displayTime {
    if (createdAt.isEmpty) return '';
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return createdAt;
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }

  DateTime? get dateTime => DateTime.tryParse(createdAt)?.toLocal();

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    var senderStr = '';
    var sName = '';
    var sAvatar = '';
    final senderRaw = json['sender'];
    if (senderRaw is Map<String, dynamic>) {
      senderStr = readString(senderRaw, ['role', 'type', 'id', 'name']);
      sName = readString(senderRaw, ['name', 'fullName', 'full_name', 'title']);
      sAvatar = readString(senderRaw, [
        'avatar',
        'avatarUrl',
        'avatar_url',
        'imageUrl',
        'photoUrl',
      ]);
    } else if (senderRaw is String) {
      senderStr = senderRaw;
    }
    if (senderStr.isEmpty) {
      senderStr = readString(json, [
        'sender',
        'from',
        'author',
        'role',
        'senderRole',
        'sender_role',
      ], fallback: 'patient');
    }
    if (sName.isEmpty) {
      sName = readString(json, [
        'senderName',
        'sender_name',
        'authorName',
        'author_name',
        'fromName',
      ]);
    }
    if (sAvatar.isEmpty) {
      sAvatar = readString(json, [
        'senderAvatar',
        'sender_avatar',
        'avatar',
        'avatarUrl',
      ]);
    }

    final parsedCreatedAt = readString(json, [
      'createdAt',
      'created_at',
      'sentAt',
      'sent_at',
      'timestamp',
      'time',
    ]);

    return MessageModel(
      id: readString(json, ['id', '_id', 'messageId']),
      threadId: readString(json, ['threadId', 'thread_id']),
      body: readString(json, ['message', 'body', 'text', 'content']),
      sender: senderStr,
      senderName: sName,
      senderAvatar: sAvatar,
      createdAt: parsedCreatedAt.isNotEmpty
          ? parsedCreatedAt
          : DateTime.now().toIso8601String(),
      isRead: json['readAt'] != null ||
          json['read_at'] != null ||
          readBool(json, ['isRead', 'is_read', 'read'], fallback: false),
      raw: json,
    );
  }
}

class CheckInModel {
  const CheckInModel({
    required this.id,
    required this.mood,
    required this.stress,
    required this.sleep,
    required this.journal,
    required this.createdAt,
    required this.raw,
  });

  final String id;
  final int? mood;
  final int? stress;
  final int? sleep;
  final String journal;
  final String createdAt;
  final Map<String, dynamic> raw;

  factory CheckInModel.fromJson(Map<String, dynamic> json) {
    return CheckInModel(
      id: readString(json, ['id', '_id']),
      mood: readInt(json, ['mood']),
      stress: readInt(json, ['stress']),
      sleep: readInt(json, ['sleep']),
      journal: readString(json, ['journal', 'note', 'notes']),
      createdAt: readString(json, ['createdAt', 'created_at', 'date']),
      raw: json,
    );
  }
}

class DashboardItem {
  const DashboardItem({
    required this.title,
    required this.body,
    required this.time,
    required this.isUnread,
  });

  final String title;
  final String body;
  final String time;
  final bool isUnread;

  factory DashboardItem.fromJson(Map<String, dynamic> json) {
    final isRead = readBool(json, [
      'isRead',
      'is_read',
      'read',
    ], fallback: json['readAt'] != null || json['read_at'] != null);
    return DashboardItem(
      title: readString(json, ['title', 'subject', 'name', 'label']),
      body: readString(json, [
        'body',
        'message',
        'text',
        'preview',
        'description',
      ]),
      time: readString(json, [
        'time',
        'createdAt',
        'created_at',
        'dueAt',
        'due_at',
        'lastMessageAt',
        'last_message_at',
      ]),
      isUnread: const ['isUnread', 'is_unread', 'unread'].any(json.containsKey)
          ? readBool(json, ['isUnread', 'is_unread', 'unread'])
          : !isRead,
    );
  }

  String get displayText {
    if (title.isNotEmpty && body.isNotEmpty) return '$title — $body';
    return title.isNotEmpty ? title : body;
  }

  /// Returns time formatted in 12-hour format with AM/PM (e.g. `2:30 PM`).
  String get formattedTime => UsaTimezoneService.formatTimeString(time);
}

class DashboardModel {
  const DashboardModel({
    required this.nextAppointment,
    required this.upcomingAppointments,
    required this.reminders,
    required this.notifications,
    required this.pendingTasks,
    required this.unreadMessages,
    required this.unreadNotifications,
    required this.pendingForms,
    required this.upcomingAppointmentsCount,
    required this.clinicName,
    required this.headline,
    required this.checkInStreak,
    required this.todayCheckInCompleted,
    required this.todayMood,
    required this.todayStress,
    required this.todaySleep,
    required this.latestMood,
    required this.latestStress,
    required this.latestSleep,
    required this.weeklyCheckInsCompleted,
    required this.weeklyAverageMood,
    required this.weeklyAverageStress,
    required this.weeklyAverageSleep,
    required this.recommendedWellnessTool,
    required this.safetyPlanAvailable,
    required this.safetyPlanSigned,
    required this.raw,
  });

  final AppointmentModel? nextAppointment;
  final List<AppointmentModel> upcomingAppointments;
  final List<DashboardItem> reminders;
  final List<DashboardItem> notifications;
  final List<DashboardItem> pendingTasks;
  final int unreadMessages;
  final int unreadNotifications;
  final int pendingForms;
  final int upcomingAppointmentsCount;
  final String clinicName;
  final String headline;
  final int checkInStreak;
  final bool todayCheckInCompleted;
  final double? todayMood;
  final double? todayStress;
  final double? todaySleep;
  final double? latestMood;
  final double? latestStress;
  final double? latestSleep;
  final int weeklyCheckInsCompleted;
  final double? weeklyAverageMood;
  final double? weeklyAverageStress;
  final double? weeklyAverageSleep;
  final String recommendedWellnessTool;
  final bool safetyPlanAvailable;
  final bool safetyPlanSigned;
  final Map<String, dynamic> raw;

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final payload = unwrapApiPayload(json);
    final stats = payload['stats'];
    final statsMap = stats is Map<String, dynamic>
        ? stats
        : const <String, dynamic>{};
    final profile = payload['profile'];
    final profileMap = profile is Map<String, dynamic>
        ? profile
        : const <String, dynamic>{};
    final todayCheckIn = payload['todayCheckIn'] ?? payload['today_check_in'];
    final todayMap = todayCheckIn is Map<String, dynamic>
        ? todayCheckIn
        : const <String, dynamic>{};
    final latestScores = payload['latestScores'] ?? payload['latest_scores'];
    final latestMap = latestScores is Map<String, dynamic>
        ? latestScores
        : const <String, dynamic>{};
    final weeklyProgress =
        payload['weeklyProgress'] ?? payload['weekly_progress'];
    final weeklyMap = weeklyProgress is Map<String, dynamic>
        ? weeklyProgress
        : const <String, dynamic>{};
    final safetyPlan = payload['safetyPlan'] ?? payload['safety_plan'];
    final safetyMap = safetyPlan is Map<String, dynamic>
        ? safetyPlan
        : const <String, dynamic>{};

    AppointmentModel? next;
    final nextJson = payload['nextAppointment'] ?? payload['next_appointment'];
    if (nextJson is Map<String, dynamic>) {
      next = AppointmentModel.fromJson(nextJson);
    }

    final upcoming = extractListFromPayload(
      payload,
      keys: const [
        'upcomingAppointments',
        'upcoming_appointments',
        'appointments',
      ],
    ).map(AppointmentModel.fromJson).toList();

    if (next == null && upcoming.isNotEmpty) {
      next = upcoming.first;
    }

    final pendingTasks = extractListFromPayload(
      payload,
      keys: const ['pendingTasks', 'pending_tasks', 'tasks'],
    ).map(DashboardItem.fromJson).toList();

    final reminders = extractListFromPayload(
      payload,
      keys: const ['reminders', 'careTeam', 'care_team', 'updates'],
    ).map(DashboardItem.fromJson).toList();

    final notifications = extractListFromPayload(
      payload,
      keys: const ['notifications', 'alerts'],
    ).map(DashboardItem.fromJson).toList();

    final effectiveReminders = reminders.isNotEmpty ? reminders : pendingTasks;

    return DashboardModel(
      nextAppointment: next,
      upcomingAppointments: upcoming,
      reminders: effectiveReminders,
      notifications: notifications,
      pendingTasks: pendingTasks,
      unreadMessages:
          readInt(payload, [
            'unreadMessageCount',
            'unreadMessages',
            'unread_messages',
          ]) ??
          readInt(statsMap, ['unreadMessages', 'unread_messages']) ??
          0,
      unreadNotifications:
          readInt(payload, ['unreadNotificationCount', 'unreadNotifications', 'unread_notifications', 'unread_notification_count', 'notificationUnreadCount']) ??
          readInt(statsMap, ['unreadNotificationCount', 'unreadNotifications', 'unread_notifications', 'unread_notification_count']) ??
          [...notifications, ...effectiveReminders].where((item) => item.isUnread).length,
      pendingForms:
          readInt(payload, ['pendingForms', 'formsDue', 'forms_due']) ??
          readInt(statsMap, ['pendingForms', 'formsDue', 'forms_due']) ??
          pendingTasks.length,
      upcomingAppointmentsCount:
          readInt(payload, [
            'upcomingAppointmentsCount',
            'upcoming_appointments_count',
            'appointmentsCount',
          ]) ??
          readInt(statsMap, [
            'upcomingAppointmentsCount',
            'appointmentsCount',
          ]) ??
          upcoming.length,
      clinicName: readString(payload, ['clinicName', 'clinic_name', 'clinic']),
      headline: readString(payload, [
        'headline',
        'welcomeMessage',
        'welcome_message',
        'greeting',
      ]),
      checkInStreak:
          readInt(profileMap, ['checkInStreak', 'check_in_streak']) ?? 0,
      todayCheckInCompleted: readBool(todayMap, ['completed', 'done']),
      todayMood: readDouble(todayMap, ['mood']),
      todayStress: readDouble(todayMap, ['stress']),
      todaySleep: readDouble(todayMap, ['sleep']),
      latestMood: readDouble(latestMap, ['mood']),
      latestStress: readDouble(latestMap, ['stress']),
      latestSleep: readDouble(latestMap, ['sleep']),
      weeklyCheckInsCompleted:
          readInt(weeklyMap, ['checkInsCompleted', 'check_ins_completed']) ?? 0,
      weeklyAverageMood: readDouble(weeklyMap, ['averageMood', 'average_mood']),
      weeklyAverageStress: readDouble(weeklyMap, [
        'averageStress',
        'average_stress',
      ]),
      weeklyAverageSleep: readDouble(weeklyMap, [
        'averageSleep',
        'average_sleep',
      ]),
      recommendedWellnessTool: readString(payload, [
        'recommendedWellnessTool',
        'recommended_wellness_tool',
        'wellnessTool',
      ]),
      safetyPlanAvailable: readBool(safetyMap, ['available']),
      safetyPlanSigned: readBool(safetyMap, ['clientSigned', 'client_signed']),
      raw: payload,
    );
  }
}

class ProgressModel {
  const ProgressModel({
    required this.streak,
    required this.longestStreak,
    required this.checkInsCount,
    required this.averageMood,
    required this.averageStress,
    required this.averageSleep,
    required this.riskLevel,
    required this.summary,
    required this.insight,
    required this.moodTrend,
    required this.raw,
  });

  final int? streak;
  final int? longestStreak;
  final int? checkInsCount;
  final double? averageMood;
  final double? averageStress;
  final double? averageSleep;
  final String riskLevel;
  final String summary;
  final String insight;
  final List<int> moodTrend;
  final Map<String, dynamic> raw;

  bool get hasData {
    return (streak != null && streak! > 0) ||
        (longestStreak != null && longestStreak! > 0) ||
        (checkInsCount != null && checkInsCount! > 0) ||
        averageMood != null ||
        averageStress != null ||
        averageSleep != null ||
        riskLevel.isNotEmpty ||
        summary.isNotEmpty ||
        insight.isNotEmpty ||
        moodTrend.isNotEmpty;
  }

  factory ProgressModel.fromJson(Map<String, dynamic> json) {
    final payload = unwrapApiPayload(json);
    final nested = payload['progress'];
    final weekly = payload['weekly'];
    final weeklyMap = weekly is Map<String, dynamic>
        ? weekly
        : const <String, dynamic>{};
    final source = nested is Map<String, dynamic>
        ? nested
        : weeklyMap.isNotEmpty
        ? weeklyMap
        : payload;

    final daily = weeklyMap['daily'];
    final moodTrend = () {
      if (daily is List) {
        final Map<String, int> byDate = {};
        final List<int> rawList = [];
        for (final item in daily) {
          if (item is! Map<String, dynamic>) continue;
          final mood = item['mood'];
          final score = mood is int
              ? mood
              : (mood is num ? mood.round() : int.tryParse(mood?.toString() ?? ''));
          if (score == null) continue;
          final date = item['date']?.toString();
          if (date != null && date.isNotEmpty) {
            byDate[date] = score;
          } else {
            rawList.add(score);
          }
        }
        if (byDate.isNotEmpty) {
          final sortedDates = byDate.keys.toList()..sort();
          final list = sortedDates.map((d) => byDate[d]!).toList();
          return list.length > 7 ? list.sublist(list.length - 7) : list;
        }
        if (rawList.isNotEmpty) {
          return rawList.length > 7
              ? rawList.sublist(rawList.length - 7)
              : rawList;
        }
      }
      final fallback = readIntList(source, [
        'moodTrend',
        'mood_trend',
        'weeklyMood',
        'weekly_mood',
        'moodHistory',
        'mood_history',
      ]);
      return fallback.length > 7
          ? fallback.sublist(fallback.length - 7)
          : fallback;
    }();

    final riskLevel = () {
      final fromRoot = readString(payload, [
        'riskLevel',
        'risk_level',
        'risk',
        'status',
      ]);
      if (fromRoot.isNotEmpty) return fromRoot;
      return readString(source, ['riskLevel', 'risk_level', 'risk', 'status']);
    }();

    return ProgressModel(
      streak:
          readInt(payload, ['streak', 'currentStreak', 'current_streak']) ??
          readInt(source, ['streak', 'currentStreak', 'current_streak']),
      longestStreak: readInt(source, [
        'longestStreak',
        'longest_streak',
        'bestStreak',
      ]),
      checkInsCount: readInt(source, [
        'checkInsCompleted',
        'check_ins_completed',
        'checkInsCount',
        'check_ins_count',
        'totalCheckIns',
        'total_check_ins',
        'count',
      ]),
      averageMood: readDouble(source, [
        'averageMood',
        'avgMood',
        'moodAverage',
        'mood_avg',
        'average_mood',
      ]),
      averageStress: readDouble(source, [
        'averageStress',
        'avgStress',
        'stressAverage',
        'stress_avg',
        'average_stress',
      ]),
      averageSleep: readDouble(source, [
        'averageSleep',
        'avgSleep',
        'sleepAverage',
        'sleep_avg',
        'average_sleep',
      ]),
      riskLevel: riskLevel,
      summary: readString(source, ['summary', 'overview']),
      insight: readString(source, ['insight', 'message', 'recommendation']),
      moodTrend: moodTrend,
      raw: payload,
    );
  }

  String get displaySummary {
    if (summary.isNotEmpty) return summary;
    if (insight.isNotEmpty) return insight;
    if (riskLevel.isNotEmpty) return 'Risk level: $riskLevel';
    return '';
  }
}

class InvitePreviewModel {
  const InvitePreviewModel({
    required this.valid,
    required this.email,
    required this.clinicName,
    required this.message,
    required this.raw,
  });

  final bool valid;
  final String email;
  final String clinicName;
  final String message;
  final Map<String, dynamic> raw;

  factory InvitePreviewModel.fromJson(Map<String, dynamic> json) {
    final payload = unwrapApiPayload(json);
    return InvitePreviewModel(
      valid: readBool(payload, [
        'valid',
        'isValid',
        'is_valid',
      ], fallback: json['success'] == true),
      email: readString(payload, ['email']),
      clinicName: readString(payload, ['clinicName', 'clinic_name', 'clinic']),
      message: readString(payload, ['message', 'error']),
      raw: payload,
    );
  }
}

class TelehealthSessionModel {
  const TelehealthSessionModel({
    required this.provider,
    required this.joinUrl,
    required this.status,
    required this.raw,
  });

  final String provider;
  final String joinUrl;
  final String status;
  final Map<String, dynamic> raw;

  factory TelehealthSessionModel.fromJson(Map<String, dynamic> json) {
    final payload = unwrapApiPayload(json);
    return TelehealthSessionModel(
      provider: readString(payload, ['provider', 'platform', 'type']),
      joinUrl: readString(payload, [
        'joinUrl',
        'join_url',
        'url',
        'meetingUrl',
      ]),
      status: readString(payload, ['status', 'state']),
      raw: payload,
    );
  }
}

class PatientFormModel {
  const PatientFormModel({
    required this.id,
    required this.title,
    required this.status,
    required this.dueAt,
    required this.description,
    required this.signedAt,
    required this.raw,
  });

  final String id;
  final String title;
  final String status; // pending, signed, expired, declined
  final String dueAt;
  final String description;
  final String signedAt;
  final Map<String, dynamic> raw;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isSigned => status.toLowerCase() == 'signed';
  bool get isExpired => status.toLowerCase() == 'expired';
  bool get isDeclined => status.toLowerCase() == 'declined';

  factory PatientFormModel.fromJson(Map<String, dynamic> json) {
    final payload = unwrapApiPayload(json);
    return PatientFormModel(
      id: readString(payload, ['id', '_id', 'formId']),
      title: readString(payload, [
        'title',
        'name',
        'formName',
        'label',
      ], fallback: 'Form'),
      status: readString(payload, ['status', 'state'], fallback: 'pending'),
      dueAt: readString(payload, ['dueAt', 'due_at', 'dueDate', 'due_date']),
      description: readString(payload, [
        'description',
        'instructions',
        'body',
        'subtitle',
      ]),
      signedAt: readString(payload, [
        'signedAt',
        'signed_at',
        'completedAt',
        'completed_at',
      ]),
      raw: payload,
    );
  }
}
