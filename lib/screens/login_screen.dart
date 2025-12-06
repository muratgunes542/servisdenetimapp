import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/services/auth_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  void _checkExistingLogin() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      _navigateToDashboard();
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Lütfen email ve şifre giriniz', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🔐 Giriş deneniyor: ${_emailController.text}');
      final result = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (result['success'] == true) {
        print('✅ Giriş başarılı, yönlendiriliyor...');
        _showSnackBar('Giriş başarılı!', Colors.green);
        _navigateToDashboard();
      } else {
        _showSnackBar(result['error'] ?? 'Giriş başarısız', Colors.red);
      }
    } catch (e) {
      print('❌ Giriş hatası: $e');
      _showSnackBar('Giriş başarısız: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery
        .of(context)
        .size
        .width >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 500),
        padding: EdgeInsets.all(40),
        child: _buildLoginContent(true),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery
              .of(context)
              .size
              .height,
        ),
        padding: EdgeInsets.all(20),
        child: _buildLoginContent(false),
      ),
    );
  }

  Widget _buildLoginContent(bool isTablet) {
    return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // MİLLİ EĞİTİM BAKANLIĞI LOGOSU
            Image.asset(
              'assets/images/arac.png', // MEB logosunun yolunu buraya girin
              height: isTablet ? 100 : 80,
              width: isTablet ? 100 : 80,
            ),
            SizedBox(height: 20),

            // BAŞLIK
            Column(
              children: [
                Text(
                  'Milli Eğitim Bakanlığı',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2196F3),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Okul Servis Araçları Denetim Uygulaması',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2196F3),
                  ),
                ),
              ],
            ),

            SizedBox(height: 40),

            // LOGIN FORM
            Column(
              children: [
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: 'ilce@mem.gov.tr',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons
                            .visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: '123456',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2196F3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                      'GİRİŞ YAP',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 30),

            // TEST KULLANICI BİLGİLERİ
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Kullanıcıları:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('• İlçe Kullanıcısı: ilce@mem.gov.tr / 123456'),
                  Text('• Denetim Kullanıcısı: denetim@mem.gov.tr / 123456'),
                  Text('• Okul Kullanıcısı: okul@test.com / 123456'),
                ],
              ),
            ),

            SizedBox(height: 40),

            // ALT BİLGİ VE LOGO
            Column(
              children: [
                Image.asset(
                  'assets/images/meb_logo.png',
                  // MEB logosunun yolunu buraya girin
                  height: isTablet ? 120 : 80,
                  width: isTablet ? 120 : 80,
                ),
                SizedBox(height: 10),
                Text(
                  'Milli Eğitim Bakanlığı',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        )
    );
  }
}