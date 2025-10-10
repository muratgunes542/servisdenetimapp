import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/utils/constants.dart';

class PasswordResetScreen extends StatefulWidget {
  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final response = await _supabase
          .from(Constants.usersTable)
          .select('id, email, full_name, user_type, is_active')
          .order('full_name');

      setState(() {
        _users = response;
        _isLoading = false;
      });
    } catch (e) {
      print('Kullanıcıları yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_userIdController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar('Lütfen tüm alanları doldurun', Colors.orange);
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('Şifreler eşleşmiyor', Colors.orange);
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showSnackBar('Şifre en az 6 karakter olmalıdır', Colors.orange);
      return;
    }

    setState(() => _isResetting = true);

    try {
      await _supabase
          .from(Constants.usersTable)
          .update({
        'password': _newPasswordController.text,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', _userIdController.text);

      _showSnackBar('Şifre başarıyla sıfırlandı', Colors.green);

      // Formu temizle
      _newPasswordController.clear();
      _confirmPasswordController.clear();

    } catch (e) {
      print('Şifre sıfırlama hatası: $e');
      _showSnackBar('Şifre sıfırlanırken hata oluştu', Colors.red);
    } finally {
      setState(() => _isResetting = false);
    }
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFFE3F2FD),
        title: Text(
          'Şifre Sıfırlama',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Kullanıcı Seçimi
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kullanıcı Seçin',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _userIdController.text.isEmpty ? null : _userIdController.text,
                      decoration: InputDecoration(
                        labelText: 'Kullanıcı *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      // items kısmını şu şekilde düzelt:
                      items: _users.map<DropdownMenuItem<String>>((user) {
                        return DropdownMenuItem<String>(
                          value: user['id'],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user['full_name']),
                              Text(
                                user['email'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _userIdController.text = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Şifre Sıfırlama Formu
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yeni Şifre',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Yeni Şifre
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Yeni Şifre *',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                        hintText: 'En az 6 karakter',
                      ),
                    ),
                    SizedBox(height: 12),

                    // Şifre Tekrar
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Şifre Tekrar *',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Sıfırla Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isResetting ? null : _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: _isResetting
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('ŞİFREYİ SIFIRLA'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Kullanıcı Listesi
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sistem Kullanıcıları',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return ListTile(
                              leading: Icon(
                                user['user_type'] == 'ilce'
                                    ? Icons.admin_panel_settings
                                    : Icons.assignment_ind,
                                color: user['is_active'] ? Colors.green : Colors.grey,
                              ),
                              title: Text(user['full_name']),
                              subtitle: Text(user['email']),
                              trailing: user['is_active']
                                  ? Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Aktif',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                                  : Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Pasif',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}