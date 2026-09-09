import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/validators.dart';
import '../models/user_profile.dart';
import 'booking_service.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const String appUrl = 'https://c-j-pickleball.vercel.app';

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
    return const Stream.empty();
  }

  /// Current authenticated Supabase user
  User? get currentUser {
    if (isSupabaseReady && _supabase != null) {
      return _supabase!.auth.currentUser;
    }
    return null;
  }

  /// Current active session
  Session? get currentSession {
    if (isSupabaseReady && _supabase != null) {
      return _supabase!.auth.currentSession;
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
    final cleanEmail = email.trim().toLowerCase();

    if (!isSupabaseReady || _supabase == null) {
      throw const AuthException('Supabase backend connection required.');
    }

    try {
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

  /// Sign up with email, password, and full name with 'client' role
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final sanitizedName =
        Validators.sanitizeText(fullName, maxLength: Validators.maxFullNameLength);

    if (!isSupabaseReady || _supabase == null) {
      throw const AuthException('Supabase backend connection required.');
    }

    try {
      final response = await _supabase!.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'full_name': sanitizedName,
          'role': 'client',
        },
        emailRedirectTo: '$appUrl/auth/callback?next=/dashboard',
      );

      final user = response.user;
      if (user != null && response.session != null) {
        try {
          await _supabase!.from('profiles').upsert({
            'id': user.id,
            'full_name': sanitizedName,
            'email': cleanEmail,
            'role': 'client',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (pe) {
          debugPrint('Notice: Profile upsert after signup: $pe');
        }
      }

      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Sign up failed: $e');
    }
  }

  /// Request temporary password reset via Next.js API or Supabase Auth
  Future<bool> requestPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      final res = await http.post(
        Uri.parse('$appUrl/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': cleanEmail}),
      );

      if (res.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('Next.js reset-password endpoint note: $e (trying fallback)');
    }

    if (isSupabaseReady && _supabase != null) {
      try {
        await _supabase!.auth.resetPasswordForEmail(
          cleanEmail,
          redirectTo: '$appUrl/auth/callback?next=/dashboard',
        );
        return true;
      } catch (e) {
        debugPrint('Supabase reset password fallback note: $e');
      }
    }

    return false;
  }

  /// Update user password in auth.users
  Future<void> updatePassword(String newPassword) async {
    if (!isSupabaseReady || _supabase == null || currentUser == null) {
      throw const AuthException('Authenticated session required to update password.');
    }

    try {
      await _supabase!.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  /// Update user profile details (full name and phone) in public.profiles
  Future<UserProfile> updateUserProfile({
    String? fullName,
    String? phone,
  }) async {
    if (!isSupabaseReady || _supabase == null) {
      throw const AuthException('Supabase connection required.');
    }

    final user = currentUser;
    if (user == null) {
      throw const AuthException('No authenticated user session found.');
    }

    final updatePayload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (fullName != null) {
      final sanitizedName =
          Validators.sanitizeText(fullName, maxLength: Validators.maxFullNameLength);
      updatePayload['full_name'] = sanitizedName;
    }

    if (phone != null) {
      updatePayload['phone'] = phone.trim();
    }

    try {
      final response = await _supabase!
          .from('profiles')
          .update(updatePayload)
          .eq('id', user.id)
          .select()
          .single();

      if (fullName != null) {
        try {
          await _supabase!.auth.updateUser(
            UserAttributes(data: {'full_name': updatePayload['full_name']}),
          );
        } catch (_) {}
      }

      return UserProfile.fromJson(response);
    } on PostgrestException catch (pe) {
      throw Exception('Failed to update profile: ${pe.message}');
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Fetch user profile details from public.profiles
  Future<UserProfile?> fetchUserProfile([String? userId]) async {
    final uid = userId ?? currentUser?.id;
    if (uid == null) return null;

    if (isSupabaseReady && _supabase != null) {
      try {
        final data = await _supabase!
            .from('profiles')
            .select()
            .eq('id', uid)
            .maybeSingle();

        if (data != null) {
          return UserProfile.fromJson(data);
        }
      } catch (e) {
        debugPrint('Notice: Error querying profile: $e');
      }

      // Fallback from auth metadata
      final liveUser = currentUser;
      if (liveUser != null && liveUser.id == uid) {
        final metaName =
            (liveUser.userMetadata?['full_name'] as String?)?.trim();
        return UserProfile(
          id: uid,
          fullName: metaName ?? liveUser.email?.split('@').first ?? 'Player',
          email: liveUser.email,
          role: (liveUser.userMetadata?['role'] as String?) ?? 'client',
        );
      }
    }

    return null;
  }

  /// Sign out the current user and clear local availability caches
  Future<void> signOut() async {
    BookingService.instance.invalidateAvailabilityCache();

    if (isSupabaseReady && _supabase != null) {
      try {
        await _supabase!.auth.signOut();
      } on AuthException {
        rethrow;
      } catch (e) {
        throw AuthException('Failed to sign out: $e');
      }
    }
  }
}
