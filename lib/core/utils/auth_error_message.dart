import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'config-not-found':
        return 'Firebase Authentication is not enabled for this project. Turn on Email/Password and Anonymous sign-in in Firebase Console.';
      case 'operation-not-allowed':
        return 'This sign-in method is disabled in Firebase Authentication. Enable it in Firebase Console.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'network-request-failed':
        return 'Network request failed. Check your connection and try again.';
      default:
        return error.message ?? 'Authentication failed: ${error.code}';
    }
  }

  return error.toString();
}