import 'package:firebase_auth/firebase_auth.dart';

import '../utils/vozac_boja.dart';

/// 🔥 FIREBASE AUTHENTICATION SERVICE
/// Zamena za Supabase EmailAuthService sa istim API-jem
class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Trenutno ulogovan korisnik
  static User? get currentUser => _auth.currentUser;

  /// Da li je korisnik ulogovan
  static bool get isLoggedIn => currentUser != null;

  /// Stream trenutnog korisnika za realtime updates
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Email registracija sa automatskom verifikacijom
  static Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String vozacName,
  }) async {
    try {
      // 🔒 VALIDACIJA: Email mora biti dozvoljen za vozača
      if (!VozacBoja.isEmailDozvoljenForVozac(email, vozacName)) {
        return AuthResult.failure(
            'Email $email nije dozvoljen za vozača $vozacName');
      }

      // Kreiranje korisnika
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Postavljanje display name-a na vozač ime
      await credential.user?.updateDisplayName(vozacName);

      // 📧 SLANJE EMAIL VERIFIKACIJE
      await credential.user?.sendEmailVerification();

      return AuthResult.success(
        user: credential.user,
        message:
            'Registracija uspešna! Proverite svoj email za confirmation link.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Neočekivana greška: $e');
    }
  }

  /// Email login sa email verifikacijom
  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 🔒 PROVERA EMAIL VERIFIKACIJE
      if (credential.user != null && !credential.user!.emailVerified) {
        // Automatski pošaljemo novi verification email
        await credential.user!.sendEmailVerification();

        return AuthResult.failure(
          'Email adresa nije verifikovana. Novi confirmation link je poslat na $email. Proverite svoj inbox i kliknite na link.',
        );
      }

      return AuthResult.success(
        user: credential.user,
        message: 'Uspešno ulogovanje!',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Neočekivana greška: $e');
    }
  }

  /// Logout
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Slanje reset password email-a
  static Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(
        message: 'Link za reset šifre je poslat na $email',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Neočekivana greška: $e');
    }
  }

  /// Ponovno slanje email verifikacije
  static Future<AuthResult> resendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('Nema aktivnog korisnika');
      }

      if (user.emailVerified) {
        return AuthResult.success(
          message: 'Email je već verifikovan',
        );
      }

      await user.sendEmailVerification();
      return AuthResult.success(
        message: 'Novi confirmation link je poslat na ${user.email}',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Neočekivana greška: $e');
    }
  }

  /// Provera da li je trenutni korisnik verifikovan
  static bool get isEmailVerified {
    return currentUser?.emailVerified ?? false;
  }

  /// Validacija email formata
  static bool isValidEmailFormat(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  /// Reset password preko email-a (kompatibilnost sa starim API)
  static Future<bool> resetPasswordViaEmail(String email) async {
    final result = await resetPassword(email);
    return result.isSuccess;
  }

  // EMAIL VERIFIKACIJA UKLONJENA - DIREKTNA REGISTRACIJA I LOGIN

  /// Konverzija Firebase grešaka u srpski
  static String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Šifra je previše slaba. Minimum 6 karaktera.';
      case 'email-already-in-use':
        return 'Email je već registrovan. Pokušajte login.';
      case 'invalid-email':
        return 'Email adresa nije validna.';
      case 'user-not-found':
        return 'Korisnik sa tim email-om ne postoji.';
      case 'wrong-password':
        return 'Neispravna šifra.';
      case 'too-many-requests':
        return 'Previše pokušaja. Pokušajte ponovo kasnije.';
      case 'network-request-failed':
        return 'Nema internet konekcije.';
      default:
        return 'Greška: ${e.message}';
    }
  }
}

/// Result wrapper za auth operacije
class AuthResult {
  AuthResult._({
    required this.isSuccess,
    required this.message,
    this.user,
  });

  factory AuthResult.success({User? user, String? message}) {
    return AuthResult._(
      isSuccess: true,
      message: message ?? 'Uspešno!',
      user: user,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(
      isSuccess: false,
      message: message,
    );
  }
  final bool isSuccess;
  final String message;
  final User? user;
}
