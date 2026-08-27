import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../demo/demo_data.dart';
import '../models/user_profile.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final StreamController<AuthState> _mockAuthStreamController =
      StreamController<AuthState>.broadcast();

  bool _isDemoLoggedIn = false;
  UserProfile _currentDemoProfile = DemoData.demoProfile;

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

  /// Whether current session is in demo/guest mode
  bool get isDemoMode => _isDemoLoggedIn;

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
      final liveUser = _supabase!.auth.currentUser;
      if (liveUser != null) return liveUser;
    }
    if (_isDemoLoggedIn) {
      return User(
        id: _currentDemoProfile.id,
        appMetadata: {},
        userMetadata: {'full_name': _currentDemoProfile.fullName},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: DemoData.demoEmail,
      );
    }
    return null;
  }

  /// Current active session
  Session? get currentSession {
    if (isSupabaseReady && _supabase != null) {
      final liveSession = _supabase!.auth.currentSession;
      if (liveSession != null) return liveSession;
    }
    if (_isDemoLoggedIn && currentUser != null) {
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

  /// Whether the active user is a legitimate live Supabase user (not demo/mockup)
  bool get isLiveUser {
    if (isSupabaseReady && _supabase != null) {
      final user = _supabase!.auth.currentUser;
      return user != null && !DemoData.isDemoUser(user.id) && !_isDemoLoggedIn;
    }
    return false;
  }

  /// Sign in with email and password for legitimate accounts
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    
    // Explicit demo guest bypass
    if (cleanEmail == DemoData.demoEmail || !isSupabaseReady || _supabase == null) {
      return signInWithDemoAccess();
    }

    try {
      _isDemoLoggedIn = false;
      final response = await _supabase!.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('An unexpected error occurred during sign in: $e');
    }
  }

  /// Explicit quick demo access with mock preview data
  Future<AuthResponse> signInWithDemoAccess() async {
    _isDemoLoggedIn = true;
    _currentDemoProfile = DemoData.demoProfile;
    _mockAuthStreamController.add(
      AuthState(AuthChangeEvent.signedIn, currentSession),
    );
    return AuthResponse(session: currentSession, user: currentUser);
  }

  /// Sign up with email, password, and insert user into public.profiles
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (isSupabaseReady && _supabase != null) {
      try {
        _isDemoLoggedIn = false;
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
      _currentDemoProfile = _currentDemoProfile.copyWith(fullName: fullName.trim());
      _isDemoLoggedIn = true;
      _mockAuthStreamController.add(
        AuthState(AuthChangeEvent.signedIn, currentSession),
      );
      return AuthResponse(session: currentSession, user: currentUser);
    }
  }

  /// Update user full name in public.profiles and auth user metadata
  Future<UserProfile> updateUserProfile({required String fullName}) async {
    final trimmedName = fullName.trim();
    if (isLiveUser && _supabase != null) {
      final user = currentUser;
      if (user == null) {
        throw const AuthException('No authenticated user session found.');
      }

      try {
        final response = await _supabase!
            .from('profiles')
            .update({'full_name': trimmedName})
            .eq('id', user.id)
            .select()
            .single();

        await _supabase!.auth.updateUser(
          UserAttributes(data: {'full_name': trimmedName}),
        );

        return UserProfile.fromJson(response);
      } on PostgrestException catch (pe) {
        throw Exception('Failed to update profile: ${pe.message}');
      } catch (e) {
        throw Exception('Failed to update profile: $e');
      }
    } else {
      _currentDemoProfile = _currentDemoProfile.copyWith(fullName: trimmedName);
      return _currentDemoProfile;
    }
  }

  /// Sign out the current user and purge local session tokens
  Future<void> signOut() async {
    _isDemoLoggedIn = false;
    if (isSupabaseReady && _supabase != null) {
      try {
        await _supabase!.auth.signOut(scope: SignOutScope.local);
      } on AuthException {
        rethrow;
      } catch (e) {
        throw AuthException('Failed to sign out: $e');
      }
    } else {
      _mockAuthStreamController.add(
        const AuthState(AuthChangeEvent.signedOut, null),
      );
    }
  }

  /// Fetch user profile details from public.profiles.
  /// Never returns mock/demo data for legitimate live users.
  Future<UserProfile?> fetchUserProfile(String userId) async {
    if (DemoData.isDemoUser(userId) || _isDemoLoggedIn) {
      return _currentDemoProfile;
    }

    if (isSupabaseReady && _supabase != null) {
      try {
        final data = await _supabase!
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (data != null) {
          return UserProfile.fromJson(data);
        }
      } catch (e) {
        debugPrint('Notice: Error querying live profile: $e');
      }

      // Fallback for real user without a database profile row yet:
      // Construct profile from real user metadata, NEVER from DemoData!
      final liveUser = currentUser;
      final metaName = (liveUser?.userMetadata?['full_name'] as String?)?.trim();
      final emailPrefix = liveUser?.email?.split('@').first ?? 'Player';
      final displayName = (metaName != null && metaName.isNotEmpty) ? metaName : emailPrefix;

      return UserProfile(
        id: userId,
        fullName: displayName,
        role: 'customer',
      );
    }

    return null;
  }
}
