import 'dart:convert';

import 'package:altrix/core/network/api_endpoints.dart';
import 'package:altrix/core/network/api_exception.dart';
import 'package:altrix/core/network/api_response.dart';
import 'package:altrix/features/auth/data/models/client_model.dart';
import 'package:dio/dio.dart';
import 'package:altrix/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:altrix/features/auth/data/models/login_request.dart';
import 'package:altrix/features/auth/data/models/update_profile_request.dart';
import 'package:altrix/features/patient/data/datasources/patient_remote_datasource.dart';
import 'package:altrix/features/patient/data/models/patient_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Standard Error Format Extraction', () {
    test('extracts error message with field-level details', () {
      final payload = {
        'success': false,
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Invalid credentials or request data',
          'fields': {
            'email': 'Invalid email address',
          },
        },
      };

      final message = extractApiErrorMessage(payload);
      expect(message, contains('Invalid credentials or request data'));
      expect(message, contains('email: Invalid email address'));
    });

    test('extracts error message when error is a plain string', () {
      final payload = {
        'success': false,
        'error': 'Unauthorized access',
      };

      final message = extractApiErrorMessage(payload);
      expect(message, 'Unauthorized access');
    });

    test('extracts error code and message from standard error structure', () {
      final payload = {
        'success': false,
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Invalid request',
        },
      };

      final code = extractApiErrorCode(payload);
      final message = extractApiErrorMessage(payload);

      expect(code, 'VALIDATION_ERROR');
      expect(message, 'Invalid request');
    });

    test('requireApiSuccess throws ApiException with code and message', () {
      final payload = {
        'success': false,
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Invalid request',
        },
      };

      try {
        requireApiSuccess(payload);
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(e.code, 'VALIDATION_ERROR');
        expect(e.message, 'Invalid request');
        expect(e.isValidationError, isTrue);
      }
    });
  });

  group('Update Profile Request', () {
    test('only includes changed / non-null fields in JSON body', () {
      const request = UpdateProfileRequest(
        phone: '+14105550199',
        addressLine1: '456 New Ave',
        city: 'Baltimore',
        emergencyContactName: 'Jane Doe',
        emergencyContactPhone: '+14105550101',
      );

      final json = request.toJson();
      expect(json, {
        'phone': '+14105550199',
        'addressLine1': '456 New Ave',
        'city': 'Baltimore',
        'emergencyContactName': 'Jane Doe',
        'emergencyContactPhone': '+14105550101',
      });
      expect(json.containsKey('name'), isFalse);
      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('state'), isFalse);
      expect(json.containsKey('postalCode'), isFalse);
    });
  });

  group('PatientFormModel Parsing', () {
    test('parses pending and signed status correctly', () {
      final pendingJson = {
        'id': 'form_1',
        'title': 'HIPAA Consent Form',
        'status': 'pending',
        'description': 'Annual privacy agreement',
        'dueDate': '2026-09-30T00:00:00.000Z',
      };

      final model = PatientFormModel.fromJson(pendingJson);
      expect(model.id, 'form_1');
      expect(model.title, 'HIPAA Consent Form');
      expect(model.isPending, isTrue);
      expect(model.isSigned, isFalse);
      expect(model.isExpired, isFalse);

      final signedModel = PatientFormModel.fromJson({
        'id': 'form_2',
        'title': 'Intake Questionnaire',
        'status': 'signed',
      });
      expect(signedModel.isSigned, isTrue);
      expect(signedModel.isPending, isFalse);
    });
  });

  group('ClientModel & Telehealth Model Parsing', () {
    test('parses nested address and emergencyContact objects', () {
      final json = {
        'id': 'p_123',
        'name': 'Rahul Sharma',
        'email': 'rahul@example.com',
        'phone': '+14155552671',
        'address': {
          'line1': '789 Market St',
          'city': 'San Francisco',
          'state': 'CA',
          'postalCode': '94103',
        },
        'emergencyContact': {
          'name': 'Pooja Sharma',
          'phone': '+14155559999',
        },
      };

      final client = ClientModel.fromJson(json);
      expect(client.id, 'p_123');
      expect(client.name, 'Rahul Sharma');
      expect(client.addressLine1, '789 Market St');
      expect(client.city, 'San Francisco');
      expect(client.state, 'CA');
      expect(client.postalCode, '94103');
      expect(client.emergencyContactName, 'Pooja Sharma');
      expect(client.emergencyContactPhone, '+14155559999');
    });

    test('parses TelehealthSessionModel with Zoom join link', () {
      final json = {
        'provider': 'zoom',
        'joinUrl': 'https://zoom.us/j/1234567890?pwd=abc',
        'status': 'ready',
      };

      final session = TelehealthSessionModel.fromJson(json);
      expect(session.provider, 'zoom');
      expect(session.joinUrl, 'https://zoom.us/j/1234567890?pwd=abc');
      expect(session.status, 'ready');
    });
  });

  group('Dio JSON Request Serialization', () {
    test('verifies Dio serializes Map to valid JSON when contentType is configured', () async {
      final dio = Dio(BaseOptions(
        contentType: 'application/json',
      ));
      final options = RequestOptions(
        path: '/api/patient/login',
        data: {'email': 'user@example.com', 'password': 'secret'},
        contentType: dio.options.contentType,
      );
      final body = await dio.transformer.transformRequest(options);
      expect(body, '{"email":"user@example.com","password":"secret"}');
    });

    test('verifies AuthRemoteDataSource.login sends data in body in raw JSON form', () async {
      RequestOptions? captured;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'token': 'jwt_token_123',
                    'client': {
                      'id': 'patient_1',
                      'name': 'Test Patient',
                      'email': 'patient@example.com',
                    },
                  },
                },
              ),
            );
          },
        ),
      );

      final authSource = AuthRemoteDataSource(dio);
      final response = await authSource.login(
        const LoginRequest(
          email: 'patient@example.com',
          password: 'YourPassword123',
        ),
      );

      expect(response.token, 'jwt_token_123');
      expect(captured, isNotNull);
      expect(captured!.path, '/api/patient/login');
      expect(captured!.method, 'POST');
      // Body is sent as raw JSON string:
      expect(captured!.data, isA<String>());
      expect(
        captured!.data,
        '{"email":"patient@example.com","mail":"patient@example.com","password":"YourPassword123"}',
      );
      expect(captured!.contentType, 'application/json');
    });
  });

  group('Patient Appointment API Contract', () {
    test('list, actions, and insurance update match the API', () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://altrixs.com'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        requests.add(options);
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'appointment': {'id': 'appt-1', 'status': 'pending'},
              'appointments': <Map<String, dynamic>>[],
              'client': {'id': 'patient-1'},
            },
          },
        ));
      }));
      final source = PatientRemoteDataSource(dio);

      await source.getAppointments();
      await source.cancelAppointment('appt-1', reason: 'Schedule conflict');
      await source.rescheduleAppointment(
        id: 'appt-1',
        date: '2026-10-28',
        startTime: '14:00',
        note: 'Need afternoon time slot',
      );
      await source.updateProfile(
        insurancePayer: 'Maryland Medicaid HealthChoice',
        insuranceMemberId: 'MD-998877',
        insuranceGroupNumber: 'GRP-MD-01',
      );

      expect(requests[0].queryParameters['includePast'], isTrue);
      expect(requests[0].queryParameters['includeCancelled'], isTrue);
      expect(requests[1].method, 'POST');
      expect(requests[1].data['reason'], 'Schedule conflict');
      expect(requests[2].method, 'POST');
      expect(requests[3].method, 'PATCH');
      expect(requests[3].data['insurancePayer'], 'Maryland Medicaid HealthChoice');
      expect(requests[3].data['insuranceMemberId'], 'MD-998877');
      expect(requests[3].data['insuranceGroupNumber'], 'GRP-MD-01');
    });
  });

  group('Patient Check-in API Contract', () {
    test('createCheckIn sends expected json payload with mood, stress, sleep, journal', () async {
      RequestOptions? capturedOptions;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'success': true,
                  'data': {
                    'checkIn': {
                      'id': 'chk_123',
                      'mood': 8,
                      'stress': 3,
                      'sleep': 7,
                      'journal': 'Feeling much better today and rested well.',
                      'createdAt': '2026-09-10T13:30:00.000Z',
                    },
                  },
                },
              ),
            );
          },
        ),
      );

      final dataSource = PatientRemoteDataSource(dio);
      final checkIn = await dataSource.createCheckIn(
        mood: 8,
        stress: 3,
        sleep: 7,
        journal: 'Feeling much better today and rested well.',
      );

      expect(checkIn.id, 'chk_123');
      expect(checkIn.mood, 8);
      expect(checkIn.stress, 3);
      expect(checkIn.sleep, 7);
      expect(checkIn.journal, 'Feeling much better today and rested well.');

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, '/api/patient/check-ins');
      expect(capturedOptions!.method, 'POST');
      final requestData = capturedOptions!.data is String
          ? jsonDecode(capturedOptions!.data as String) as Map<String, dynamic>
          : capturedOptions!.data as Map<String, dynamic>;
      expect(requestData, {
        'mood': 8,
        'stress': 3,
        'sleep': 7,
        'journal': 'Feeling much better today and rested well.',
      });
    });

    test('getCheckIns supports limit and skip query parameters', () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://altrixs.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'checkIns': [
                      {
                        'id': 'chk_1',
                        'mood': 8,
                        'stress': 2,
                        'sleep': 8,
                        'journal': 'Great day',
                        'createdAt': '2026-09-10T12:00:00Z',
                      }
                    ],
                  },
                },
              ),
            );
          },
        ),
      );

      final dataSource = PatientRemoteDataSource(dio);
      final checkIns = await dataSource.getCheckIns(limit: 10, skip: 0);

      expect(checkIns.length, 1);
      expect(checkIns.first.id, 'chk_1');
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, '/api/patient/check-ins');
      expect(capturedOptions!.queryParameters['limit'], 10);
      expect(capturedOptions!.queryParameters['skip'], 0);
    });
  });

  group('Patient API Endpoints & Auth Contracts', () {
    test('ApiEndpoints match API specification exactly', () {
      expect(ApiEndpoints.patientLogin, '/api/patient/login');
      expect(ApiEndpoints.patientLogout, '/api/patient/logout');
      expect(ApiEndpoints.patientInviteAccept, '/api/patient/invite/accept');
      expect(ApiEndpoints.patientForgotPassword, '/api/patient/forgot-password');
      expect(ApiEndpoints.patientResetPassword, '/api/patient/reset-password');
      expect(ApiEndpoints.patientMe, '/api/patient/me');
      expect(ApiEndpoints.patientAvatar, '/api/patient/avatar');
      expect(ApiEndpoints.patientDashboard, '/api/patient/dashboard');
      expect(ApiEndpoints.patientProgress, '/api/patient/progress');
      expect(ApiEndpoints.patientCheckIns, '/api/patient/check-ins');
      expect(ApiEndpoints.patientDoctors, '/api/patient/doctors');
      expect(ApiEndpoints.patientDoctorAvailability('doc123'), '/api/patient/doctors/doc123/availability');
      expect(ApiEndpoints.patientAppointments, '/api/patient/appointments');
      expect(ApiEndpoints.patientAppointmentReschedule('apt123'), '/api/patient/appointments/apt123/reschedule');
      expect(ApiEndpoints.patientAppointmentCancel('apt123'), '/api/patient/appointments/apt123/cancel');
      expect(ApiEndpoints.patientConversations, '/api/patient/conversations');
      expect(ApiEndpoints.patientConversationMessages('c123'), '/api/patient/conversations/c123/messages');
      expect(ApiEndpoints.patientConversationStream('c123'), '/api/patient/conversations/c123/stream');
      expect(ApiEndpoints.patientMessageRead('m123'), '/api/patient/messages/m123/read');
      expect(ApiEndpoints.patientForms, '/api/patient/forms');
      expect(ApiEndpoints.patientForm('f123'), '/api/patient/forms/f123');
      expect(ApiEndpoints.telehealthJoin('token123'), '/api/telehealth/join/token123');
    });

    test('AuthRemoteDataSource calls logout via POST /api/patient/logout', () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://altrixs.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true},
              ),
            );
          },
        ),
      );

      final authSource = AuthRemoteDataSource(dio);
      await authSource.logout();

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, '/api/patient/logout');
      expect(capturedOptions!.method, 'POST');
    });

    test('AuthRemoteDataSource calls deleteAccount via DELETE /api/patient/me', () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://altrixs.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true},
              ),
            );
          },
        ),
      );

      final authSource = AuthRemoteDataSource(dio);
      await authSource.deleteAccount();

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, '/api/patient/me');
      expect(capturedOptions!.method, 'DELETE');
    });

    test('ClientModel and User correctly parse avatarUrl and support copyWith', () {
      final json = {
        'id': 'p123',
        'name': 'Sarah Connor',
        'email': 'sarah@example.com',
        'phone': '+15552345678',
        'avatarUrl': 'https://altrixs.com/uploads/sarah.jpg',
      };

      final client = ClientModel.fromJson(json);
      expect(client.avatarUrl, 'https://altrixs.com/uploads/sarah.jpg');

      final user = client.toEntity();
      expect(user.avatarUrl, 'https://altrixs.com/uploads/sarah.jpg');

      final updated = user.copyWith(avatarUrl: 'https://altrixs.com/uploads/sarah_new.jpg');
      expect(updated.avatarUrl, 'https://altrixs.com/uploads/sarah_new.jpg');
      expect(updated.name, 'Sarah Connor');
    });
  });
}
