import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/auth_service.dart';
import '/utils/constants.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _showAddUserForm = false;

  // Form controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  String _selectedUserType = 'denetim';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final response = await _supabase
          .from(Constants.usersTable)
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _users = response;
        _isLoading = false;
      });
    } catch (e) {
      print('Kullanıcıları yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addUser() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _fullNameController.text.isEmpty) {
      _showSnackBar('Lütfen zorunlu alanları doldurunuz', Colors.orange);
      return;
    }

    try {
      final currentUser = await _authService.getCurrentUser();

      final newUser = await _supabase
          .from(Constants.usersTable)
          .insert({
        'email': _emailController.text.trim().toLowerCase(),
        'password': _passwordController.text,
        'full_name': _fullNameController.text.trim(),
        'user_type': _selectedUserType,
        'phone': _phoneController.text.trim(),
        'department': _departmentController.text.trim(),
        'is_active': _isActive,
        'created_by': currentUser?['id'],
      })
          .select()
          .single();

      _showSnackBar('Kullanıcı başarıyla eklendi', Colors.green);

      _clearForm();
      _loadUsers();
      setState(() => _showAddUserForm = false);

    } catch (e) {
      print('Kullanıcı ekleme hatası: $e');
      _showSnackBar('Kullanıcı eklenirken hata oluştu: $e', Colors.red);
    }
  }

  Future<void> _updateUserStatus(String userId, bool isActive) async {
    try {
      await _supabase
          .from(Constants.usersTable)
          .update({'is_active': isActive})
          .eq('id', userId);

      _showSnackBar('Kullanıcı durumu güncellendi', Colors.green);
      _loadUsers();

    } catch (e) {
      print('Kullanıcı güncelleme hatası: $e');
      _showSnackBar('Güncelleme sırasında hata oluştu', Colors.red);
    }
  }

  Future<void> _resetUserPassword(String userId) async {
    try {
      await _supabase
          .from(Constants.usersTable)
          .update({
        'password': '123456',
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', userId);

      _showSnackBar('Şifre başarıyla sıfırlandı (123456)', Colors.green);
    } catch (e) {
      print('Şifre sıfırlama hatası: $e');
      _showSnackBar('Şifre sıfırlanırken hata oluştu', Colors.red);
    }
  }

  void _showPasswordResetDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Şifre Sıfırlama'),
        content: Text('${user['full_name']} kullanıcısının şifresini sıfırlamak istediğinizden emin misiniz? Yeni şifre "123456" olarak ayarlanacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _resetUserPassword(user['id']);
            },
            child: Text('Sıfırla', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId, String userEmail) async {
    final currentUser = await _authService.getCurrentUser();
    if (currentUser?['id'] == userId) {
      _showSnackBar('Kendi hesabınızı silemezsiniz', Colors.red);
      return;
    }

    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kullanıcıyı Sil'),
        content: Text('$userEmail kullanıcısını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase
            .from(Constants.usersTable)
            .delete()
            .eq('id', userId);

        _showSnackBar('Kullanıcı başarıyla silindi', Colors.green);
        _loadUsers();

      } catch (e) {
        print('Kullanıcı silme hatası: $e');
        _showSnackBar('Silme sırasında hata oluştu', Colors.red);
      }
    }
  }

  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    _fullNameController.clear();
    _phoneController.clear();
    _departmentController.clear();
    _selectedUserType = 'denetim';
    _isActive = true;
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

  Color _getUserTypeColor(String userType) {
    switch (userType) {
      case 'ilce': return Colors.blue;
      case 'denetim': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _getUserTypeText(String userType) {
    switch (userType) {
      case 'ilce': return 'İlçe MEM';
      case 'denetim': return 'Denetim Görevlisi';
      default: return userType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFFE3F2FD),
        title: Text(
          'Kullanıcı Yönetimi',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFF2196F3)),
            onPressed: _loadUsers,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sistem Kullanıcıları',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _showAddUserForm = !_showAddUserForm);
                  },
                  icon: Icon(Icons.person_add),
                  label: Text('Yeni Kullanıcı Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2196F3),
                  ),
                ),
              ],
            ),
          ),

          if (_showAddUserForm) _buildAddUserForm(),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'Henüz kullanıcı bulunmuyor',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return _buildUserCard(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddUserForm() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni Kullanıcı Ekle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),

            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
                hintText: 'ornek@mem.gov.tr',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 12),

            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Şifre *',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
                hintText: '123456',
              ),
              obscureText: true,
            ),
            SizedBox(height: 12),

            TextField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: 'Ad Soyad *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
                hintText: 'Ahmet Yılmaz',
              ),
            ),
            SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedUserType,
              decoration: InputDecoration(
                labelText: 'Kullanıcı Tipi *',
                prefixIcon: Icon(Icons.assignment_ind),
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'denetim', child: Text('Denetim Görevlisi')),
                DropdownMenuItem(value: 'ilce', child: Text('İlçe MEM')),
                DropdownMenuItem(value: 'school', child: Text('Okul Kullanıcısı')), // BU SATIRI EKLE
              ],
              onChanged: (value) {
                setState(() => _selectedUserType = value!);
              },
            ),
            SizedBox(height: 12),

            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Telefon',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
                hintText: '05551234567',
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 12),

            TextField(
              controller: _departmentController,
              decoration: InputDecoration(
                labelText: 'Departman',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
                hintText: 'Denetim Birimi',
              ),
            ),
            SizedBox(height: 12),

            Row(
              children: [
                Checkbox(
                  value: _isActive,
                  onChanged: (value) {
                    setState(() => _isActive = value!);
                  },
                ),
                Text('Kullanıcı Aktif'),
              ],
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _clearForm();
                      setState(() => _showAddUserForm = false);
                    },
                    child: Text('İptal'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2196F3),
                    ),
                    child: Text('Kullanıcı Ekle'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getUserTypeColor(user['user_type']).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            user['user_type'] == 'ilce'
                ? Icons.admin_panel_settings
                : Icons.assignment_ind,
            color: _getUserTypeColor(user['user_type']),
            size: 20,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['full_name'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: user['is_active'] ? Colors.grey[800] : Colors.grey[400],
              ),
            ),
            Text(
              user['email'],
              style: TextStyle(
                fontSize: 12,
                color: user['is_active'] ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getUserTypeColor(user['user_type']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getUserTypeText(user['user_type']),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getUserTypeColor(user['user_type']),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                if (user['department'] != null)
                  Text(
                    user['department'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Şifre Sıfırlama Butonu - FutureBuilder ile
            FutureBuilder<bool>(
              future: _authService.isIlceUser(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return IconButton(
                    icon: Icon(Icons.vpn_key, color: Colors.blue),
                    onPressed: () => _showPasswordResetDialog(user),
                    tooltip: 'Şifre Sıfırla',
                  );
                }
                return SizedBox.shrink();
              },
            ),
            // Aktif/Pasif Toggle
            IconButton(
              icon: Icon(
                user['is_active'] ? Icons.toggle_on : Icons.toggle_off,
                color: user['is_active'] ? Colors.green : Colors.grey,
                size: 30,
              ),
              onPressed: () => _updateUserStatus(user['id'], !user['is_active']),
              tooltip: user['is_active'] ? 'Pasif Yap' : 'Aktif Yap',
            ),
            // Sil Butonu
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteUser(user['id'], user['email']),
              tooltip: 'Kullanıcıyı Sil',
            ),
          ],
        ),
      ),
    );
  }
}