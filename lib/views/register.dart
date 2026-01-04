import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shalat_essential/components/rotating_dot.dart';
import 'package:shalat_essential/services/colors.dart';
import 'package:shalat_essential/services/firebase_service.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _formKey = GlobalKey<FormState>();
  final nicknameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
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
                Text('Register', style: Theme.of(context).primaryTextTheme.headlineMedium),
                Text('Fullfill the form below', style: Theme.of(context).primaryTextTheme.labelLarge),
                const SizedBox(height: 20),

                // Email Label
                SizedBox(
                  width: screenWidth,
                  child: Text('Nickname', style: Theme.of(context).primaryTextTheme.labelLarge, textAlign: TextAlign.start),
                ),
                const SizedBox(height: 5),

                // Email Field
                Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  child: TextFormField(
                    controller: nicknameController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Nickname cannot be empty';
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
                        bool success = await FirebaseService().doRegister(
                            context,
                            emailController.text,
                            passwordController.text,
                            nicknameController.text);
                        loginLoading();
                        if(success){
                          Navigator.pop(context, true);
                        }
                      }
                    },
                    child: isLoading
                        ? RotatingDot(scale: 20,)
                        : Text('Register', style: Theme.of(context).primaryTextTheme.labelLarge),
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
