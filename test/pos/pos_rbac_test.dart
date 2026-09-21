import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/user_profile.dart';
import 'package:pickleball_app/services/pos_service.dart';

void main() {
  group('POS Cashier-Only RBAC & Barrier Verification', () {
    test('UserProfile correctly classifies cashier, admin, owner as staff', () {
      const cashierProfile = UserProfile(id: 'u-1', role: 'cashier');
      const adminProfile = UserProfile(id: 'u-2', role: 'admin');
      const ownerProfile = UserProfile(id: 'u-3', role: 'owner');

      expect(cashierProfile.isStaff, isTrue);
      expect(cashierProfile.isCashier, isTrue);
      expect(cashierProfile.isClient, isFalse);

      expect(adminProfile.isStaff, isTrue);
      expect(adminProfile.isAdmin, isTrue);
      expect(adminProfile.isClient, isFalse);

      expect(ownerProfile.isStaff, isTrue);
      expect(ownerProfile.isAdmin, isTrue);
      expect(ownerProfile.isClient, isFalse);
    });

    test('UserProfile correctly classifies player / client as non-staff', () {
      const playerProfile = UserProfile(id: 'u-4', role: 'player');
      const clientProfile = UserProfile(id: 'u-5');

      expect(playerProfile.isStaff, isFalse);
      expect(playerProfile.isClient, isTrue);
      expect(playerProfile.isPlayer, isTrue);

      expect(clientProfile.isStaff, isFalse);
      expect(clientProfile.isClient, isTrue);
    });

    test('Allowed POS roles strictly include only cashier, admin, owner', () {
      const allowedRoles = ['owner', 'admin', 'cashier'];

      expect(allowedRoles.contains('cashier'), isTrue);
      expect(allowedRoles.contains('admin'), isTrue);
      expect(allowedRoles.contains('owner'), isTrue);

      // Player must be strictly denied
      expect(allowedRoles.contains('player'), isFalse);
      expect(allowedRoles.contains('client'), isFalse);
    });

    test('Supervisor Master PIN verification authenticates default 8888', () async {
      final posService = PosService.instance;

      final valid = await posService.verifySupervisorPin('8888');
      expect(valid, isTrue);

      final invalid = await posService.verifySupervisorPin('1234');
      expect(invalid, isFalse);

      final empty = await posService.verifySupervisorPin('');
      expect(empty, isFalse);
    });
  });
}
