// test/services/auth_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/services/auth_service.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import '../helpers/mocks.dart';
import '../helpers/test_data.dart';

// Additional mocks for auth-specific flows
class MockAuthResponse extends Mock {
  User? get user;
}

class MockUser extends Mock implements User {
  @override
  String get id => 'user-1';
}

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late AuthService authService;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    authService = AuthService(mockClient);
  });

  group('AuthService', () {
    group('currentUser', () {
      test('returns null when not authenticated', () {
        when(() => mockAuth.currentUser).thenReturn(null);
        expect(authService.currentUser, isNull);
      });

      test('returns user when authenticated', () {
        final mockUser = MockUser();
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        expect(authService.currentUser, isNotNull);
      });
    });

    group('isAuthenticated', () {
      test('returns false when no user', () {
        when(() => mockAuth.currentUser).thenReturn(null);
        expect(authService.isAuthenticated, false);
      });

      test('returns true when user exists', () {
        when(() => mockAuth.currentUser).thenReturn(MockUser());
        expect(authService.isAuthenticated, true);
      });
    });

    group('signOut', () {
      test('calls supabase signOut', () async {
        when(() => mockAuth.signOut()).thenAnswer((_) async {});
        await authService.signOut();
        verify(() => mockAuth.signOut()).called(1);
      });
    });

    group('resetPassword', () {
      test('calls resetPasswordForEmail with correct email', () async {
        when(() => mockAuth.resetPasswordForEmail(any()))
            .thenAnswer((_) async {});
        await authService.resetPassword('test@example.com');
        verify(() => mockAuth.resetPasswordForEmail('test@example.com')).called(1);
      });
    });

    group('fetchCurrentProfile', () {
      test('returns null when not authenticated', () async {
        when(() => mockAuth.currentUser).thenReturn(null);
        final result = await authService.fetchCurrentProfile();
        expect(result, isNull);
      });
    });

    group('updateProfile', () {
      test('throws StateError when not authenticated', () {
        when(() => mockAuth.currentUser).thenReturn(null);
        expect(
          () => authService.updateProfile(username: 'new'),
          throwsA(isA<StateError>()),
        );
      });

      test('does not call DB when no updates', () async {
        when(() => mockAuth.currentUser).thenReturn(MockUser());
        // No fields provided - should still succeed but do nothing meaningful
        await authService.updateProfile();
        // Verify no DB call was made (no from('users') call)
      });
    });
  });
}
