import 'package:flutter/material.dart';
import '/services/auth_service.dart';
import '/services/database_service.dart';

class ProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileEditScreen({Key? key, required this.user}) : super(key: key);

  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    // Mevcut kullanıcı bilgilerini form alanlarına yükle
    _nameController.text = widget.user['full_name'] ?? widget.user['name'] ?? '';
    _emailController.text = widget.user['email'] ?? '';
    _phoneController.text = widget.user['phone'] ?? '';
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updates = {
        'full_name': _nameController.text.trim(), // DÜZELTİLDİ: 'name' yerine 'full_name'
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // GERÇEK database güncellemesi
      await _dbService.updateUser(widget.user['id'], updates);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil bilgileri başarıyla güncellendi'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, updates);
    } catch (e) {
      print('❌ Profil güncelleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil güncelleme başarısız: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profili Düzenle'),
        backgroundColor: Color(0xFF2196F3),
        actions: [
          if (_isLoading)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Ad Soyad',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen ad soyad giriniz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen email giriniz';
                  }
                  if (!value.contains('@')) {
                    return 'Geçerli bir email adresi giriniz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2196F3),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('GÜNCELLE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}