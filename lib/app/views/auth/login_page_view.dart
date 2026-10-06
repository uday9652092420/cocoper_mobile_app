import 'package:cocoper_mobile/app/controllers/auth/login_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginPageView extends GetView<LoginController> {
  const LoginPageView({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0C9F70),
              Color(0xFF087A55),
              Color(0xFF2F963A),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBrandSection(context),
                  const SizedBox(height: 28),
                  _buildLoginCard(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandSection(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 50,
            height: 50,
            child: Image.asset(
              'assets/cocoper-icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: Colors.white,
                    size: 30,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'COCOPER',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Coconut Wholesale Management System',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        24,
        26,
        24,
        24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF14342B),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Sign in with your administrator credentials.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF14342B),
              ),
            ),
            const SizedBox(height: 25),
            _buildFieldLabel('Email'),
            const SizedBox(height: 7),
            _buildEmailField(),
            const SizedBox(height: 18),
            _buildFieldLabel('Password'),
            const SizedBox(height: 7),
            _buildPasswordField(),
            const SizedBox(height: 14),
            _buildRememberForgotRow(),
            const SizedBox(height: 24),
            Obx(
              () => SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      controller.isLoading.value ? null : controller.submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D8135),
                    disabledBackgroundColor:
                        const Color(0xFF2D8135).withValues(alpha: 0.6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  child: controller.isLoading.value
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF14342B),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: controller.emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: controller.validateEmail,
      decoration: _buildInputDecoration(
        hintText: 'Enter email',
        prefixIcon: const Icon(
          Icons.mail_outline,
          size: 19,
          color: Color(0xFF14342B),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Obx(
      () => TextFormField(
        controller: controller.passwordController,
        obscureText: !controller.isPasswordVisible.value,
        textInputAction: TextInputAction.done,
        validator: controller.validatePassword,
        onFieldSubmitted: (_) {
          controller.submit();
        },
        decoration: _buildInputDecoration(
          hintText: 'Enter password',
          prefixIcon: const Icon(
            Icons.lock_outline,
            size: 19,
            color: Color(0xFF14342B),
          ),
          suffixIcon: IconButton(
            onPressed: controller.togglePasswordVisibility,
            icon: Icon(
              controller.isPasswordVisible.value
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 19,
              color: const Color(0xFF14342B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRememberForgotRow() {
    return Row(
      children: [
        Obx(
          () => SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: controller.rememberMe.value,
              onChanged: controller.toggleRememberMe,
              activeColor: const Color(0xFF2D8135),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Remember me',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF14342B),
          ),
        ),
        const Spacer(),
        // TextButton(
        //   onPressed: controller.forgotPassword,
        //   style: TextButton.styleFrom(
        //     padding: EdgeInsets.zero,
        //     minimumSize: const Size(0, 0),
        //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        //     foregroundColor: const Color(0xFF2D8135),
        //   ),
        //   child: const Text(
        //     'Forgot password?',
        //     style: TextStyle(
        //       fontSize: 12,
        //       fontWeight: FontWeight.w600,
        //     ),
        //   ),
        // ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 12,
        color: Color(0xFF14342B),
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(
          color: Color(0xFFD6DEE5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(
          color: Color(0xFF2D8135),
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
    );
  }
}
