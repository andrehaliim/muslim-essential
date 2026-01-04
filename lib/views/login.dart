import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:muslim_essential/components/custom_snackbar.dart';
import 'package:muslim_essential/components/rotating_dot.dart';
import 'package:muslim_essential/services/colors.dart';
import 'package:muslim_essential/services/firebase_service.dart';
import 'package:muslim_essential/views/forgot_password.dart';
import 'package:muslim_essential/views/register.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool isLoading = false;

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
        Navigator.pop(context, false);
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
                Text('Log in', style: Theme.of(context).primaryTextTheme.headlineMedium),
                const SizedBox(height: 40),
                Text('Please login to track your prayer', style: Theme.of(context).primaryTextTheme.labelLarge),
                const SizedBox(height: 20),

                // Email Label
                SizedBox(
                  width: screenWidth,
                  child: Text('Email', style: Theme.of(context).primaryTextTheme.labelLarge, textAlign: TextAlign.start),
                ),
                const SizedBox(height: 5),

                // Email Field
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

                const SizedBox(height: 20),

                // Password Label
                SizedBox(
                  width: screenWidth,
                  child: Text('Password', style: Theme.of(context).primaryTextTheme.labelLarge, textAlign: TextAlign.start),
                ),
                const SizedBox(height: 5),

                // Password Field
                Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  child: TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    cursorColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password cannot be empty';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF415A77), width: 1.5),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                SizedBox(
                  width: screenWidth,
                  child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.rightToLeft,
                            childBuilder: (context) => ForgotPassword(),
                          ),
                        );
                      },
                      child: Text('Forgot password', style: Theme.of(context).primaryTextTheme.bodyMedium, textAlign: TextAlign.end)),
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
                        bool success = await FirebaseService().doLogin(
                            context,
                            emailController.text.trim(),
                            passwordController.text.trim()
                        );
                        loginLoading();
                        if(success){
                          CustomSnackbar().successSnackbar(context, 'Login success');
                          Navigator.pop(context,true);
                        }
                      }
                    },
                    child: isLoading
                        ? RotatingDot(scale: 20)
                        : Text('Login', style: Theme.of(context).primaryTextTheme.labelLarge),
                  ),
                ),

                const SizedBox(height: 20),
                Text('Don\'t have an account?', style: Theme.of(context).primaryTextTheme.bodyMedium),
                const SizedBox(height: 20),

                // Register Button
                SizedBox(
                  width: screenWidth,
                  height: kMinInteractiveDimension,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      side: BorderSide(color: AppColors.borderColor, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.rightToLeft,
                          childBuilder: (context) => Register(),
                        ),
                      );
                    },
                    child: const Text('Register'),
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
