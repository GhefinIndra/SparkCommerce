import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(
          'Password berhasil diubah',
          Icons.check_circle,
          Colors.green[600]!,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(
          'Gagal mengubah password: ${e.toString()}',
          Icons.error_outline,
          Colors.red[400]!,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password tidak boleh kosong';
    }
    if (value != _newPasswordController.text) {
      return 'Konfirmasi password tidak cocok';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Color(0xFF1A237E),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1A237E), // Deep Blue
                Color(0xFF283593), // Medium Blue
                Color(0xFF3949AB), // Light Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Compact Header
                Container(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Ubah Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      SizedBox(width: 56),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(20),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 10),

                                    // Security Icon
                                    Center(
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF2196F3)
                                                  .withOpacity(0.2),
                                              Color(0xFF2196F3)
                                                  .withOpacity(0.1),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(40),
                                          border: Border.all(
                                            color: Color(0xFF2196F3)
                                                .withOpacity(0.3),
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.lock_outline,
                                          color: Color(0xFF2196F3),
                                          size: 36,
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: 24),

                                    Center(
                                      child: Column(
                                        children: [
                                          Text(
                                            'Keamanan Akun',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1A237E),
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Pastikan password baru Anda kuat dan mudah diingat',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: 32),

                                    // Password Saat Ini Section
                                    _buildSectionTitle(
                                      'Password Saat Ini',
                                      Icons.lock_outlined,
                                    ),
                                    SizedBox(height: 16),

                                    Container(
                                      padding: EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.04),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: _buildPasswordField(
                                        controller: _currentPasswordController,
                                        label: 'Password Saat Ini',
                                        icon: Icons.lock_outlined,
                                        obscureText: _obscureCurrentPassword,
                                        onToggleObscure: () {
                                          setState(() {
                                            _obscureCurrentPassword =
                                                !_obscureCurrentPassword;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Password saat ini harus diisi';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),

                                    SizedBox(height: 24),

                                    // Password Baru Section
                                    _buildSectionTitle(
                                      'Password Baru',
                                      Icons.lock_reset,
                                    ),
                                    SizedBox(height: 16),

                                    Container(
                                      padding: EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.04),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          _buildPasswordField(
                                            controller: _newPasswordController,
                                            label: 'Password Baru',
                                            icon: Icons.lock_reset,
                                            obscureText: _obscureNewPassword,
                                            onToggleObscure: () {
                                              setState(() {
                                                _obscureNewPassword =
                                                    !_obscureNewPassword;
                                              });
                                            },
                                            validator: _validatePassword,
                                          ),
                                          SizedBox(height: 20),
                                          _buildPasswordField(
                                            controller:
                                                _confirmPasswordController,
                                            label: 'Konfirmasi Password Baru',
                                            icon: Icons.lock_clock,
                                            obscureText:
                                                _obscureConfirmPassword,
                                            onToggleObscure: () {
                                              setState(() {
                                                _obscureConfirmPassword =
                                                    !_obscureConfirmPassword;
                                              });
                                            },
                                            validator:
                                                _validateConfirmPassword,
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: 24),

                                    // Password Requirements
                                    Container(
                                      padding: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF2196F3)
                                            .withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Color(0xFF2196F3)
                                              .withOpacity(0.15),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF2196F3)
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.info_outline,
                                                  color: Color(0xFF2196F3),
                                                  size: 16,
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                'Ketentuan Password',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF2196F3),
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 14),
                                          _buildRequirement(
                                              'Minimal 6 karakter'),
                                          _buildRequirement(
                                              'Kombinasi huruf dan angka (disarankan)'),
                                          _buildRequirement(
                                              'Hindari password yang mudah ditebak'),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: 32),

                                    // Save Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isLoading ? null : _changePassword,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF2196F3),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor:
                                              Color(0xFF2196F3)
                                                  .withOpacity(0.6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          elevation: 0,
                                          shadowColor: Color(0xFF2196F3)
                                              .withOpacity(0.3),
                                        ),
                                        child: _isLoading
                                            ? Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    'Mengubah Password...',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.security,
                                                    size: 22,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Ubah Password',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),

                                    SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Color(0xFF2196F3),
            size: 20,
          ),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A237E),
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(
        fontSize: 16,
        color: Colors.grey[800],
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Container(
          margin: EdgeInsets.all(12),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Color(0xFF2196F3),
            size: 20,
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.grey[500],
            size: 20,
          ),
          onPressed: onToggleObscure,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red[400]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: Color(0xFF2196F3),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  SnackBar _buildSnackBar(
      String message, IconData icon, Color backgroundColor) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.all(16),
      elevation: 3,
    );
  }
}