import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  User? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
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

    _loadUserProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = await AuthService().getProfile();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshProfile() async {
    await _loadUserProfile();
  }

  Future<void> _logout() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[400]),
              SizedBox(width: 12),
              Text('Konfirmasi Logout'),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari aplikasi?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        await AuthService().logout();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Error saat logout: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
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
                Container(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    children: [
                      Row(
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
                              'Profil Saya',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          SizedBox(width: 56), // Balance the back button
                        ],
                      ),
                      SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Column(
                                children: [
                                  Container(
                                    width: 85,
                                    height: 85,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.3),
                                          Colors.white.withOpacity(0.1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(42.5),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.4),
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 16,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: _isLoading
                                        ? Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : _currentUser != null
                                            ? Center(
                                                child: Text(
                                                  _currentUser!.name.isNotEmpty
                                                      ? _currentUser!.name[0]
                                                          .toUpperCase()
                                                      : 'U',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 34,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            : Icon(
                                                Icons.person,
                                                size: 42,
                                                color: Colors.white,
                                              ),
                                  ),
                                  SizedBox(height: 14),
                                  if (_currentUser != null) ...[
                                    Text(
                                      _currentUser!.name,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        _currentUser!.email,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.95),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

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
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 20,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF2196F3),
                                    strokeWidth: 3,
                                  ),
                                ),
                                SizedBox(height: 24),
                                Text(
                                  'Memuat profil...',
                                  style: TextStyle(
                                    color: Color(0xFF1A237E),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _errorMessage != null
                            ? Center(
                                child: Container(
                                  margin: EdgeInsets.all(24),
                                  padding: EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 20,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Icon(
                                          Icons.error_outline_rounded,
                                          size: 56,
                                          color: Colors.red[400],
                                        ),
                                      ),
                                      SizedBox(height: 24),
                                      Text(
                                        'Gagal Memuat Profil',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A237E),
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        _errorMessage!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          height: 1.5,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 28),
                                      ElevatedButton.icon(
                                        onPressed: _loadUserProfile,
                                        icon: Icon(Icons.refresh_rounded, size: 22),
                                        label: Text(
                                          'Coba Lagi',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF2196F3),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _refreshProfile,
                                color: Color(0xFF2196F3),
                                backgroundColor: Colors.white,
                                strokeWidth: 2.5,
                                child: SingleChildScrollView(
                                  physics: AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.all(20),
                                  child: AnimatedBuilder(
                                    animation: _fadeAnimation,
                                    builder: (context, child) {
                                      return FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position: _slideAnimation,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(height: 10),

                                              // Informasi Akun
                                              _buildSectionTitle(
                                                  'Informasi Akun',
                                                  Icons.person),
                                              SizedBox(height: 16),

                                              Container(
                                                padding: EdgeInsets.all(24),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.04),
                                                      blurRadius: 12,
                                                      offset: Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  children: [
                                                    _buildInfoRow(
                                                        'Nama Lengkap',
                                                        _currentUser?.name ??
                                                            '-',
                                                        Icons.person_outline),
                                                    _buildDivider(),
                                                    _buildInfoRow(
                                                        'Email',
                                                        _currentUser?.email ??
                                                            '-',
                                                        Icons.email_outlined),
                                                    _buildDivider(),
                                                    _buildInfoRow(
                                                        'No. Telepon',
                                                        _currentUser?.phone ??
                                                            'Belum diisi',
                                                        Icons.phone_outlined),
                                                    _buildDivider(),
                                                    _buildInfoRow(
                                                        'Group ID',
                                                        _currentUser?.groupId ?? 'Belum diisi',
                                                        Icons.group_outlined),
                                                    _buildDivider(),
                                                    _buildInfoRow(
                                                        'Status',
                                                        'Aktif',
                                                        Icons
                                                            .check_circle_outline,
                                                        valueColor:
                                                            Colors.green[600]),
                                                  ],
                                                ),
                                              ),

                                              SizedBox(height: 32),

                                              // Menu Actions
                                              _buildSectionTitle(
                                                  'Pengaturan', Icons.settings),
                                              SizedBox(height: 16),

                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.04),
                                                      blurRadius: 12,
                                                      offset: Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  children: [
                                                    _buildMenuTile(
                                                      'Edit Profil',
                                                      Icons.edit_outlined,
                                                      () async {
                                                        final result =
                                                            await Navigator
                                                                .push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                EditProfileScreen(
                                                                    user:
                                                                        _currentUser!),
                                                          ),
                                                        );
                                                        if (result == true) {
                                                          _refreshProfile();
                                                        }
                                                      },
                                                      subtitle:
                                                          'Ubah nama dan nomor telepon',
                                                    ),
                                                    Divider(height: 1),
                                                    _buildMenuTile(
                                                      'Ubah Password',
                                                      Icons.lock_outline,
                                                      () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                ChangePasswordScreen(),
                                                          ),
                                                        );
                                                      },
                                                      subtitle:
                                                          'Perbarui kata sandi Anda',
                                                    ),
                                                    Divider(height: 1),
                                                    _buildMenuTile(
                                                      'Riwayat Aktivitas',
                                                      Icons.history,
                                                      () {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          _buildSnackBar(
                                                              'Fitur riwayat aktivitas akan segera hadir',
                                                              Icons.info),
                                                        );
                                                      },
                                                      subtitle:
                                                          'Lihat aktivitas terkini',
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              SizedBox(height: 24),

                                              // Logout section
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.04),
                                                      blurRadius: 12,
                                                      offset: Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: _buildMenuTile(
                                                  'Logout',
                                                  Icons.logout,
                                                  _logout,
                                                  textColor: Colors.red[600],
                                                  iconColor: Colors.red[600],
                                                  subtitle:
                                                      'Keluar dari aplikasi',
                                                ),
                                              ),

                                              SizedBox(height: 40),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
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

  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Divider(
        height: 1,
        color: Colors.grey[200],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon,
      {Color? valueColor}) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Color(0xFF2196F3),
            size: 22,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: valueColor ?? Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile(String title, IconData icon, VoidCallback onTap,
      {Color? textColor, Color? iconColor, String? subtitle}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? Color(0xFF2196F3)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? Color(0xFF2196F3),
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor ?? Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  SnackBar _buildSnackBar(String message, IconData icon) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Color(0xFF2196F3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.all(16),
    );
  }
}
