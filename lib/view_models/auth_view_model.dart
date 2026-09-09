import 'package:flutter/foundation.dart';
import '../data/repositories/auth_repository.dart';
import '../models/user_profile.dart';

/// ViewModel managing authentication flows, session state, and profile mutations.
class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repository;

  AuthViewModel({AuthRepository? repository})
      : _repository = repository ?? SupabaseAuthRepository();

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _repository.isAuthenticated;

  Future<void> loadProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _userProfile = await _repository.getCurrentUserProfile();
    } catch (e) {
      _errorMessage = 'Failed to load profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      await loadProfile();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.signUp(
        email: email.trim(),
        password: password,
        fullName: fullName?.trim() ?? 'Player',
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.signOut();
      _userProfile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
