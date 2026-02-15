// test/providers/auth_providers_test.dart
//
// Tests for auth provider logic and AuthNotifier behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yu_map/providers/auth_providers.dart';
import 'package:yu_map/providers/service_providers.dart';
import 'package:yu_map/services/auth_service.dart';
import '../helpers/mocks.dart';
import '../helpers/test_data.dart';

void main() {
  group('AuthNotifier', () {
    late ProviderContainer container;
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is AsyncData(null)', () {
      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });

    test('signInWithEmail sets loading then data on success', () async {
      when(() => mockAuthService.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => TestData.user());

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.signInWithEmail('test@test.com', 'password');

      final state = container.read(authNotifierProvider);
      expect(state.hasError, false);
    });

    test('signInWithEmail sets error state on failure', () async {
      when(() => mockAuthService.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('Invalid credentials'));

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.signInWithEmail('bad@test.com', 'wrong');

      final state = container.read(authNotifierProvider);
      expect(state.hasError, true);
    });

    test('signUpWithEmail calls service with correct params', () async {
      when(() => mockAuthService.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
            displayName: any(named: 'displayName'),
          )).thenAnswer((_) async => TestData.user());

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.signUpWithEmail(
        email: 'new@test.com',
        password: 'pass123',
        username: 'newuser',
        displayName: 'New User',
      );

      verify(() => mockAuthService.signUpWithEmail(
            email: 'new@test.com',
            password: 'pass123',
            username: 'newuser',
            displayName: 'New User',
          )).called(1);
    });

    test('signOut calls service signOut', () async {
      when(() => mockAuthService.signOut()).thenAnswer((_) async {});

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.signOut();

      verify(() => mockAuthService.signOut()).called(1);
    });

    test('signOut sets error state on failure', () async {
      when(() => mockAuthService.signOut())
          .thenThrow(Exception('Network error'));

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.signOut();

      final state = container.read(authNotifierProvider);
      expect(state.hasError, true);
    });
  });
}
