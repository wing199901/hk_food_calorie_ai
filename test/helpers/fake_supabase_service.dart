import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSupabaseService extends SupabaseService {
  FakeSupabaseService({
    this.shouldFailSignIn = false,
    this.shouldFailSignUp = false,
    this.signInErrorMessage = 'Invalid credentials',
    this.signUpErrorMessage = 'Unable to sign up',
    UserProfile? profileToReturn,
  }) : profileToReturn = profileToReturn ?? UserProfile();

  bool shouldFailSignIn;
  bool shouldFailSignUp;
  String signInErrorMessage;
  String signUpErrorMessage;
  UserProfile profileToReturn;

  bool isSignedIn = false;
  int signInCount = 0;
  int signUpCount = 0;
  int signOutCount = 0;

  @override
  bool get isAuthenticated => isSignedIn;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    signInCount += 1;
    if (shouldFailSignIn) {
      throw AuthException(signInErrorMessage, statusCode: '401');
    }
    isSignedIn = true;
    return AuthResponse();
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    signUpCount += 1;
    if (shouldFailSignUp) {
      throw AuthException(signUpErrorMessage, statusCode: '400');
    }
    return AuthResponse();
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    isSignedIn = false;
  }

  @override
  Future<UserProfile> fetchProfile() async {
    return profileToReturn;
  }
}
