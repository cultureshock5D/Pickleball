import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final StreamController<AuthState> _mockAuthStreamController =
      StreamController<AuthState>.broadcast();

  bool _isDemoLoggedIn = false;
  UserProfile _demoProfile = const UserProfile(
    id: 'demo-user-12345',
    fullName: 'Alex Morgan',
    role: 'customer',
  );

  bool get isSupabaseReady {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get _supabase {
    try {
      return isSupabaseReady ? Supabase.instance.client : null;
    } catch (_) {
      return null;
    }
  }

  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges {
    if (isSupabaseReady && _supabase != null) {
      return _supabase!.auth.onAuthStateChange;
    }
    return _mockAuthStreamController.stream;
  }

  /// Current authenticated user
  User? get currentUser {
    if (isSupabaseReady && _supabase != null) {
      return _supabase!.auth.currentUser;
    }
    if (_isDemoLoggedIn) {
      return User(
        id: _demoProfile.id,
        appMetadata: {},
        userMetadata: {'full_name': _demoProfile.fullName},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'customer@pickleball.com',
      );
    }
    return null;
  }

  /// Current active session
  Session? get currentSession {
    if (isSupabaseReady && _supabase != null) {
      return _supabase!.auth.currentSession;
    }
    if (_isDemoLoggedIn) {
      return Session(
        accessToken: 'demo-access-token',
        tokenType: 'bearer',
        user: currentUser!,
      );
    }
    return null;
  }

  /// Whether a valid session exists
  bool get isAuthenticated => currentSession != null;

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (isSupabaseReady && _supabase != null) {
      try {
        final response = await _supabase!.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        return response;
      } on AuthException {
        rethrow;
      } catch (e) {
        throw AuthException('An unexpected error occurred during sign in: $e');
      }
    } else {
      // Demo authentication mode fallback
      _isDemoLoggedIn = true;
      _mockAuthStreamController.add(
        AuthState(AuthChangeEvent.signedIn, currentSession),
      );
      return AuthResponse(session: currentSession, user: currentUser);
    }
  }

  /// Sign up with email, password, and insert user into public.profiles
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (isSupabaseReady && _supabase != null) {
      try {
        final response = await _supabase!.auth.signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': fullName.trim()},
        );

        final user = response.user;
        if (user != null && response.session != null) {
          try {
            await _supabase!.from('profiles').upsert({
              'id': user.id,
              'full_name': fullName.trim(),
              'role': 'customer',
            });
          } catch (pe) {
            debugPrint('Notice: Initial profile upsert: $pe');
          }
        }

        return response;
      } on AuthException {
        rethrow;
      } catch (e) {
        throw AuthException('Sign up failed: $e');
      }
    } else {
      _demoProfile = _demoProfile.copyWith(fullName: fullName.trim());
      _isDemoLoggedIn = true;
      _mockAuthStreamController.add(
        AuthState(AuthChangeEvent.signedIn, currentSession),
      );
      return AuthResponse(session: currentSession, user: currentUser);
    }
  }

  /// Update user full name in public.profiles and auth user metadata
  Future<UserProfile> updateUserProfile({required String fullName}) async {
    if (isSupabaseReady && _supabase != null) {
      final user = currentUser;
      if (user == null) {
        throw const AuthException('No authenticated user session found.');
      }

      try {
        final response = await _supabase!
            .from('profiles')
            .update({'full_name': fullName.trim()})
            .eq('id', user.id)
            .select()
            .single();

        await _supabase!.auth.updateUser(
          UserAttributes(data: {'full_name': fullName.trim()}),
        );

        return UserProfile.fromJson(response);
      } on PostgrestException catch (pe) {
        throw Exception('Failed to update profile: ${pe.message}');
      } catch (e) {
        throw Exception('Failed to update profile: $e');
      }
    } else {
      _demoProfile = _demoProfile.copyWith(fullName: fullName.trim());
      return _demoProfile;
    }
  }

  /// Sign out the current user and purge local session tokens
  Future<void> signOut() async {
    if (isSupabaseReady && _supabase != null) {
      try {
        await _supabase!.auth.signOut(scope: SignOutScope.local);
      } on AuthException {
        rethrow;
      } catch (e) {
        throw AuthException('Failed to sign out: $e');
      }
    } else {
      _isDemoLoggedIn = false;
      _mockAuthStreamController.add(
        const AuthState(AuthChangeEvent.signedOut, null),
      );
    }
  }

  /// Fetch user profile details from public.profiles
  Future<UserProfile?> fetchUserProfile(String userId) async {
    if (isSupabaseReady && _supabase != null) {
      try {
        final data = await _supabase!
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (data == null) return null;
        return UserProfile.fromJson(data);
      } catch (e) {
        debugPrint('Error fetching profile: $e');
        return _demoProfile;
      }
    }
    return _demoProfile;
  }
}
