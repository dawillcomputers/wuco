import 'package:flutter_test/flutter_test.dart';
import 'package:wea_lms/features/authentication/domain/account_status.dart';
import 'package:wea_lms/features/authentication/domain/auth_state.dart';
import 'package:wea_lms/features/authentication/domain/user_profile.dart';
import 'package:wea_lms/features/authentication/domain/user_role.dart';
import 'package:wea_lms/features/events/data/events_repository.dart';
import 'package:wea_lms/features/events/data/offline_events_repository.dart';
import 'package:wea_lms/features/events/domain/event_models.dart';

UserProfile _profile(UserRole role) => UserProfile(
  id: 'u-${role.wireName}',
  email: '${role.wireName.toLowerCase()}@example.com',
  firstName: 'Test',
  lastName: 'User',
  role: role,
  status: AccountStatus.active,
  emailVerified: true,
);

void main() {
  group('payment methods', () {
    test('a method is described by what the server reports, not guessed', () {
      final options = EventPaymentOptions.fromMap({
        'environment': 'SANDBOX',
        'methods': [
          {
            'key': 'bank_transfer',
            'label': 'Bank Transfer',
            'description': 'Transfer the exact amount.',
            'flow': 'directCharge',
          },
          {
            'key': 'card',
            'label': 'Card',
            'description': 'On Flutterwave.',
            'flow': 'redirect',
          },
        ],
      });

      expect(options.methods.length, 2);
      expect(options.isSandbox, isTrue);
      // Card is a redirect precisely so no card detail reaches WEA.
      expect(options.methods.last.isRedirect, isTrue);
      expect(options.methods.first.isRedirect, isFalse);
    });

    test('no methods are offered when nothing is configured', () {
      final options = EventPaymentOptions.fromMap({
        'environment': 'SANDBOX',
        'methods': const [],
      });

      // Offering a method that cannot complete is worse than offering none.
      expect(options.methods, isEmpty);
    });

    test('the offline backend offers nothing and says it is sandbox', () async {
      final options = await OfflineEventsRepository().paymentMethods(
        'africa-trade-and-investment-summit',
      );

      expect(options.methods, isEmpty);
      expect(options.isSandbox, isTrue);
    });

    test('a payment intent never reports success by itself', () {
      final intent = EventPaymentIntent.fromMap({
        'provider': 'FLUTTERWAVE',
        'payment_reference': 'WEA-EVT-2026-00123-abc',
        'amount': 250000,
        'currency': 'NGN',
        'checkout_url': 'https://checkout.example/pay',
      });

      // There is deliberately no "paid" on this object: starting a payment
      // and having been paid are different facts, and only the server
      // establishes the second.
      expect(intent.hasCheckout, isTrue);
      expect(intent.paymentReference, 'WEA-EVT-2026-00123-abc');
    });
  });

  group('payment outcome', () {
    test('only a verified PAID unlocks the registration', () {
      final paid = EventPaymentOutcome.fromMap({
        'status': 'PAID',
        'registration_status': 'COMPLETED',
        'payment_status': 'PAID',
      });
      expect(paid.succeeded, isTrue);
    });

    test('an amount mismatch is reported as failed, not paid', () {
      // The server downgrades an underpayment to FAILED with the reason; the
      // client must not treat the processor's own "successful" as decisive.
      final mismatch = EventPaymentOutcome.fromMap({
        'status': 'FAILED',
        'registration_status': 'PAYMENT_FAILED',
        'payment_status': 'FAILED',
        'reason': 'Underpaid: 1000 NGN against 250000 NGN.',
      });

      expect(mismatch.succeeded, isFalse);
      expect(mismatch.reason, contains('Underpaid'));
    });

    test('an abandoned payment stays pending and keeps the registration', () {
      final pending = EventPaymentOutcome.fromMap({
        'status': 'PENDING',
        'registration_status': 'PAYMENT_PENDING',
        'payment_status': 'PENDING',
      });

      expect(pending.pending, isTrue);
      expect(pending.succeeded, isFalse);
    });
  });

  group('roles', () {
    test('only the owner may grant privileged roles', () {
      expect(UserRole.owner.canGrantRoles, isTrue);
      expect(UserRole.superAdmin.canGrantRoles, isFalse);
      expect(UserRole.admin.canGrantRoles, isFalse);
      expect(UserRole.eventManager.canGrantRoles, isFalse);
    });

    test('administrative roles are marked privileged', () {
      expect(UserRole.owner.isPrivileged, isTrue);
      expect(UserRole.eventManager.isPrivileged, isTrue);
      expect(UserRole.superAdmin.isPrivileged, isTrue);
      expect(UserRole.learner.isPrivileged, isFalse);
      expect(UserRole.applicant.isPrivileged, isFalse);
    });

    test('a visitor can only ever register as applicant or learner', () {
      expect(UserRole.selfAssignable, {UserRole.applicant, UserRole.learner});
      expect(UserRole.selfAssignable.contains(UserRole.owner), isFalse);
      expect(UserRole.selfAssignable.contains(UserRole.eventManager), isFalse);
    });

    test('the owner reaches every area', () {
      for (final route in const [
        '/super-admin',
        '/super-admin/content',
        '/admin',
        '/lecturer',
        '/learner',
      ]) {
        expect(UserRole.owner.canAccess(route), isTrue, reason: route);
      }
    });

    test('an event manager reaches content management, not the accounts console', () {
      expect(UserRole.eventManager.canAccess('/super-admin/content'), isTrue);
      // Not the accounts console, which is where roles are handed out.
      expect(UserRole.eventManager.canAccess('/super-admin'), isFalse);
      expect(UserRole.eventManager.canAccess('/lecturer'), isFalse);
      // The learner area is open to everybody: an event manager may enrol on
      // a programme and study it like anyone else.
      expect(UserRole.eventManager.canAccess('/learner'), isTrue);
    });

    test('an event manager does not inherit user administration', () {
      expect(UserRole.eventManager.canManageUsers, isFalse);
      expect(UserRole.eventManager.managesEvents, isTrue);
      expect(UserRole.owner.canManageUsers, isTrue);
    });

    test('an unknown role from the wire degrades to applicant', () {
      // A role this build has never heard of must not become privileged.
      expect(UserRole.fromWireName('GOD_MODE'), UserRole.applicant);
      expect(UserRole.fromWireName(null), UserRole.applicant);
      expect(UserRole.fromWireName('OWNER'), UserRole.owner);
      expect(UserRole.fromWireName('EVENT_MANAGER'), UserRole.eventManager);
    });

    test('each role lands somewhere it is allowed to be', () {
      for (final role in UserRole.values) {
        expect(
          role.canAccess(role.landingRoute),
          isTrue,
          reason: '${role.wireName} cannot open ${role.landingRoute}',
        );
      }
    });
  });

  group('route guards', () {
    test('an event manager is not admitted to the accounts console', () {
      final auth = Authenticated(_profile(UserRole.eventManager));
      expect(auth.profile.role.canAccess('/super-admin'), isFalse);
    });

    test('an owner is admitted everywhere the guard is asked about', () {
      final auth = Authenticated(_profile(UserRole.owner));
      expect(auth.profile.role.canAccess('/super-admin'), isTrue);
    });
  });

  group('no payment secrets in the client', () {
    test('the registration draft never carries an amount or a credential', () {
      const draft = EventRegistrationDraft(
        firstName: 'John',
        lastName: 'Williams',
        email: 'john@example.com',
        complete: true,
      );
      final map = draft.toMap();

      // The fee is decided by the server from the event row. Anything the
      // client could send would be something an attacker could change.
      for (final forbidden in const [
        'amount',
        'currency',
        'client_secret',
        'access_token',
        'secret_key',
      ]) {
        expect(map.containsKey(forbidden), isFalse, reason: forbidden);
      }
    });
  });
}
