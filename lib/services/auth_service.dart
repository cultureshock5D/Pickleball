import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/validators.dart';
import '../data/mock_data.dart';
import '../models/user_profile.dart';
import 'booking_service.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  Session? _mockSession;
  final StreamController<AuthState> _mockAuthStateController =
      StreamController<AuthState>.broadcast();

  static String get appUrl {
    try {
      if (dotenv.isInitialized) {
        final val = dotenv.maybeGet('NEXT_PUBLIC_APP_URL') ?? dotenv.maybeGet('APP_URL');
        if (val != null && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    } catch (_) {}
    return 'https://c-j-pickleball.vercel.app';
  }

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
    return _mockAuthStateController.stream;
  }

  /// Current authenticated Supabase user
  User? get currentUser {
    if (isSupabaseReady && _supabase != null) {
      return _supabase!.auth.currentUser;
    }
    return _mockSession?.user;
  }

  /// Current active session
  Session? get currentSession {
    if (isSupabaseReady && _supabase != null) {
      return _supabase!.auth.currentSession;
    }
    return _mockSession;
  }

  /// Whether a valid session exists
  bool get isAuthenticated => currentSession != null;

  Never _handleAuthError(dynamic e) {
    final str = e.toString();
    if (str.contains('SocketException') ||
        str.contains('Failed host lookup') ||
        str.contains('ClientException') ||
        str.contains('errno = 7')) {
      throw const AuthException(
        'Unable to reach server. Please check your internet connection.',
      );
    }
    if (e is AuthException) {
      if (e.message.contains('SocketException') ||
          e.message.contains('Failed host lookup') ||
          e.message.contains('ClientException') ||
          e.message.contains('errno = 7')) {
        throw const AuthException(
          'Unable to reach server. Please check your internet connection.',
        );
      }
      throw e;
    }
    throw AuthException('Authentication error: ${str.replaceFirst(RegExp(r'^Exception:\s*'), '')}');
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (!isSupabaseReady || _supabase == null) {
      final name = cleanEmail.split('@').first;
      final user = User(
        id: 'mock-user-${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
        appMetadata: const {},
        userMetadata: {
          'full_name': name,
          'role': 'client',
        },
        aud: 'authenticated',
        email: cleanEmail,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      final session = Session(
        accessToken: 'mock-jwt-access-token',
        tokenType: 'bearer',
        user: user,
      );
      _mockSession = session;
      _mockAuthStateController.add(AuthState(AuthChangeEvent.signedIn, session));
      return AuthResponse(session: session, user: user);
    }

    try {
      final response = await _supabase!.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );
      return response;
    } catch (e) {
      _handleAuthError(e);
    }
  }

  /// Sign in as a guest/mock user for offline preview and testing
  AuthResponse signInAsGuest({String? email, String? fullName}) {
    final cleanEmail = (email ?? MockData.mockUserProfile.email ?? 'player@pickleball.dev')
        .trim()
        .toLowerCase();
    final cleanName = fullName ?? MockData.mockUserProfile.fullName ?? 'Demo Player';

    final user = User(
      id: MockData.mockUserProfile.id,
      appMetadata: const {},
      userMetadata: {
        'full_name': cleanName,
        'role': 'client',
      },
      aud: 'authenticated',
      email: cleanEmail,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final session = Session(
      accessToken: 'mock-guest-access-token',
      tokenType: 'bearer',
      user: user,
    );
    _mockSession = session;
    _mockAuthStateController.add(AuthState(AuthChangeEvent.signedIn, session));
    return AuthResponse(session: session, user: user);
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
      final user = User(
        id: 'mock-user-${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
        appMetadata: const {},
        userMetadata: {
          'full_name': sanitizedName,
          'role': 'client',
        },
        aud: 'authenticated',
        email: cleanEmail,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      final session = Session(
        accessToken: 'mock-jwt-access-token',
        tokenType: 'bearer',
        user: user,
      );
      _mockSession = session;
      _mockAuthStateController.add(AuthState(AuthChangeEvent.signedIn, session));
      return AuthResponse(session: session, user: user);
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
    } catch (e) {
      _handleAuthError(e);
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

    return Validators.validateEmail(cleanEmail) == null;
  }

  /// Update user password in auth.users
  Future<void> updatePassword(String newPassword) async {
    if (!isSupabaseReady || _supabase == null) {
      if (currentUser == null) {
        throw const AuthException('Authenticated session required to update password.');
      }
      return;
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
      final user = currentUser;
      if (user == null) {
        throw const AuthException('No authenticated user session found.');
      }

      final newName = fullName != null
          ? Validators.sanitizeText(fullName, maxLength: Validators.maxFullNameLength)
          : (user.userMetadata?['full_name'] as String? ?? 'Player');
      final newPhone = phone?.trim() ?? user.phone ?? '+63 917 555 0192';

      final updatedUser = User(
        id: user.id,
        appMetadata: user.appMetadata,
        userMetadata: {
          if (user.userMetadata != null) ...user.userMetadata!,
          'full_name': newName,
        },
        aud: user.aud,
        email: user.email,
        phone: newPhone,
        createdAt: user.createdAt,
      );
      _mockSession = Session(
        accessToken: _mockSession?.accessToken ?? 'mock-jwt-access-token',
        tokenType: _mockSession?.tokenType ?? 'bearer',
        user: updatedUser,
      );

      return UserProfile(
        id: user.id,
        fullName: newName,
        email: user.email,
        phone: newPhone,
        role: (user.userMetadata?['role'] as String?) ?? 'client',
      );
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

    if (isSupabaseReady && _supabase != null) {
      try {
        if (uid != null) {
          final data = await _supabase!
              .from('profiles')
              .select()
              .eq('id', uid)
              .maybeSingle();

          if (data != null) {
            return UserProfile.fromJson(data);
          }
        }
      } catch (e) {
        debugPrint('Notice: Error querying profile: $e');
      }

      // Fallback from auth metadata
      final liveUser = currentUser;
      if (liveUser != null && (uid == null || liveUser.id == uid)) {
        final metaName =
            (liveUser.userMetadata?['full_name'] as String?)?.trim();
        return UserProfile(
          id: liveUser.id,
          fullName: metaName ?? liveUser.email?.split('@').first ?? 'Player',
          email: liveUser.email,
          role: (liveUser.userMetadata?['role'] as String?) ?? 'client',
        );
      }
    }

    // Fallback from mock session or mock user profile
    final mockUser = currentUser;
    if (mockUser != null && (uid == null || mockUser.id == uid)) {
      final metaName =
          (mockUser.userMetadata?['full_name'] as String?)?.trim();
      return UserProfile(
        id: mockUser.id,
        fullName: metaName ?? mockUser.email?.split('@').first ?? MockData.mockUserProfile.fullName,
        email: mockUser.email ?? MockData.mockUserProfile.email,
        phone: mockUser.phone ?? MockData.mockUserProfile.phone,
        role: (mockUser.userMetadata?['role'] as String?) ?? 'client',
      );
    }

    return MockData.mockUserProfile;
  }

  /// Sign out the current user and clear local availability caches
  Future<void> signOut() async {
    BookingService.instance.invalidateAvailabilityCache();

    if (_mockSession != null) {
      _mockSession = null;
      _mockAuthStateController.add(const AuthState(AuthChangeEvent.signedOut, null));
    }

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
