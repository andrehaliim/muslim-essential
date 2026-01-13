import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:muslim_essential/components/custom_snackbar.dart';

class FirebaseService {
  final auth = FirebaseAuth.instance;

  Future<bool> doLogin(BuildContext context, String xemail, String xpassword) async {
    try {
      await auth.signInWithEmailAndPassword(
        email: xemail,
        password: xpassword,
      );
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDocRef = FirebaseFirestore.instance.collection("users").doc(user.uid);
        final doc = await userDocRef.get();
        if (doc.exists) {
          return true;
        } else {
          CustomSnackbar().failedSnackbar(context, 'Incorrect email or password.');
          return false;
        }
      }
      return false;
    } on FirebaseAuthException catch (e) {
     // log("Firebase Auth Error Code: ${e.code}");

      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many login attempts. Please try again later.';
          break;
        case 'invalid-credential':
          errorMessage = 'Incorrect email or password.';
          break;
        default:
          errorMessage = 'An unknown error occurred. Please try again.';
      }
      CustomSnackbar().failedSnackbar(context, errorMessage);
      return false;
    }
  }

  Future<bool> doRegister(BuildContext context, String xemail, String xpassword, String xnickname) async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: xemail,
        password: xpassword,
      );

      final user = credential.user;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .set({
          "nickname": xnickname,
          "email": xemail,
          "createdAt": FieldValue.serverTimestamp(),
        });
        CustomSnackbar().successSnackbar(context, "Registration successful");
        Navigator.pop(context);
        return true;
      }
      CustomSnackbar().failedSnackbar(context, "Registration failed");
      return false;
    } on FirebaseAuthException catch (e) {
      CustomSnackbar().failedSnackbar(context, e.message ?? '');
      return false;
    }
  }

  Future<void> sendPasswordResetEmail(BuildContext context, String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
     // log('Password reset email sent to $email');
      CustomSnackbar().successSnackbar(
        context,
        'Password reset link sent! Check your email inbox.',
      );
    } on FirebaseAuthException catch (e) {
     // log('Error sending password reset email: ${e.code}');
      String errorMessage = 'An error occurred. Please try again.';

      if (e.code == 'invalid-email') {
        errorMessage = 'The email address is not valid.';
      }

      if (e.code == 'invalid-email') {
        CustomSnackbar().failedSnackbar(context, errorMessage);
      } else {
        CustomSnackbar().successSnackbar(
          context,
          'Password reset link sent! Check your email inbox.',
        );
      }
    }
  }

  Future<User?> getUserInfo() async {
    return FirebaseAuth.instance.currentUser;
  }

  Future<String> loadNickname() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return doc.data()?["nickname"];
      }
    }
    return '';
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}