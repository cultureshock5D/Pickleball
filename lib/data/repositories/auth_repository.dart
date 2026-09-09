import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';

abstract class AuthRepository {
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<void> signOut();

  Future<UserProfile?> getCurrentUserProfile();

  Future<UserProfile> updateUserProfile({
    String? fullName,
    String? phone,
  });

  User? get currentUser;
  Session? get currentSession;
  bool get isAuthenticated;
}

class SupabaseAuthRepository implements AuthRepository {
  final AuthService _authService;

  SupabaseAuthRepository({AuthService? authService})
      : _authService = authService ?? AuthService.instance;

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _authService.signIn(email: email, password: password);
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _authService.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
  }

  @override
  Future<void> signOut() => _authService.signOut();

  @override
  Future<UserProfile?> getCurrentUserProfile() =>
      _authService.fetchUserProfile();

  @override
  Future<UserProfile> updateUserProfile({String? fullName, String? phone}) {
    return _authService.updateUserProfile(fullName: fullName, phone: phone);
  }

  @override
  User? get currentUser => _authService.currentUser;

  @override
  Session? get currentSession => _authService.currentSession;

  @override
  bool get isAuthenticated => _authService.isAuthenticated;
}
