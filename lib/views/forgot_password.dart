import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:muslim_essential/components/colors.dart';
import 'package:muslim_essential/components/rotating_dot.dart';
import 'package:muslim_essential/services/firebase_service.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool obscurePassword = true;
  bool isLoading = false;
  final auth = FirebaseAuth.instance;

  void loginLoading() {
    setState(() {
      isLoading = !isLoading;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    //final screenHeight = size.height;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(title: const Text('Muslim Essential'), backgroundColor: AppColors.background, surfaceTintColor: Colors.transparent),
        body: Container(
          width: screenWidth,
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Forgot Password', style: Theme.of(context).primaryTextTheme.headlineMedium),
                const SizedBox(height: 40),
                Text('Enter your email address and we will send you a link to reset your password.', style: Theme.of(context).primaryTextTheme.labelLarge, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                // Email Label
                SizedBox(
                  width: screenWidth,
                  child: Text('Email', style: Theme.of(context).primaryTextTheme.labelLarge, textAlign: TextAlign.start),
                ),

                Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  child: TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email cannot be empty';
                      }
                      const emailPattern = r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$';
                      if (!RegExp(emailPattern).hasMatch(value)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF415A77), width: 1.5),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Login Button
                SizedBox(
                  width: screenWidth,
                  height: kMinInteractiveDimension,
                  child: ElevatedButton(
                    style: Theme.of(context).elevatedButtonTheme.style,
                    onPressed: () async{
                      if (_formKey.currentState!.validate()) {
                        loginLoading();
                        await FirebaseService().sendPasswordResetEmail(context, emailController.text);
                        loginLoading();
                      }
                    },
                    child: isLoading
                        ? RotatingDot(scale: 20,)
                        : Text('Send Reset Link', style: Theme.of(context).primaryTextTheme.labelLarge),
                  ),
                ),
                Spacer(),
                Text('© 2025 @andrehaliim')
              ],
            ),
          ),
        ),
      ),
    );
  }
}
