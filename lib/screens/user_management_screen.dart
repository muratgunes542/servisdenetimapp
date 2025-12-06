import 'package:flutter/material.dart';
import '/services/database_service.dart';
import '/services/auth_service.dart';
import '/utils/constants.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _schools = [];
  bool _isLoading = true;
  bool _showAddForm = false;
  String _searchQuery = '';
  String _selectedSchoolFilter = '';

  // Form controllers
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedType = Constants.userTypeSchool;
  String _selectedSchool = '';

  // Edit form
  Map<String, dynamic>? _editingUser;
  final _editEmailController = TextEditingController();
  final _editNameController = TextEditingController();
  final _editPhoneController = TextEditingController();
  String _editSelectedType = Constants.userTypeSchool;
  String _editSelectedSchool = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final users = await _dbService.getUsers();
      final schools = await _dbService.getSchools();

      setState(() {
        _users = users;
        _schools = schools;
        _isLoading = false;
      });
    } catch (e) {
      print('Veri yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var filtered = _users;

    // Arama filtresi
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final name = user['full_name']?.toString().toLowerCase() ?? '';
        final email = user['email']?.toString().toLowerCase() ?? '';
        return name.contains(_searchQuery.toLowerCase()) ||
            email.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Okul filtresi
    if (_selectedSchoolFilter.isNotEmpty) {
      filtered = filtered.where((user) {
        return user['school_id']?.toString() == _selectedSchoolFilter;
      }).toList();
    }

    return filtered;
  }

  // KULLANICI EKLEME - GÜNCELLENDİ (Daha iyi hata yönetimi)
  Future<void> _addUser() async {
    if (_emailController.text.isEmpty || _nameController.text.isEmpty) {
      _showSnackBar('Lütfen email ve ad soyad giriniz', Colors.orange);
      return;
    }

    // Email kontrolü
    final email = _emailController.text.trim();
    if (_users.any((user) => user['email'] == email)) {
      _showSnackBar('Bu email adresi zaten kullanılıyor', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newUser = {
        'email': email,
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'user_type': _selectedType,
        'school_id': _selectedType == Constants.userTypeSchool && _selectedSchool.isNotEmpty
            ? _selectedSchool
            : null,
        'is_active': true,
        'department': _getDepartmentByType(_selectedType),
        'created_at': DateTime.now().toIso8601String(), // created_at ekle
      };

      print('🔄 HYBRID: Kullanıcı oluşturma başlatılıyor: $email');

      // HYBRID kullanıcı oluşturma - DatabaseService'deki geliştirilmiş metodları kullan
      await _dbService.createUser(newUser);

      _showSnackBar('Kullanıcı başarıyla eklendi', Colors.green);
      _clearForm();
      await _loadData(); // Verileri yeniden yükle

    } catch (e) {
      print('❌ Kullanıcı oluşturma hatası: $e');
      _showSnackBar('Kullanıcı eklenirken hata: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
        _showAddForm = false;
      });
    }
  }

  // KULLANICI GÜNCELLEME - GÜNCELLENDİ
  Future<void> _updateUser() async {
    if (_editingUser == null) return;

    try {
      final updates = {
        'email': _editEmailController.text.trim(),
        'full_name': _editNameController.text.trim(),
        'phone': _editPhoneController.text.trim(),
        'user_type': _editSelectedType,
        'school_id': _editSelectedType == Constants.userTypeSchool && _editSelectedSchool.isNotEmpty
            ? _editSelectedSchool
            : null,
        'department': _getDepartmentByType(_editSelectedType),
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('🔄 Kullanıcı güncelleniyor: ${_editingUser!['id']}');
      await _dbService.updateUser(_editingUser!['id'].toString(), updates);

      _showSnackBar('Kullanıcı başarıyla güncellendi', Colors.green);
      _cancelEdit();
      await _loadData();

    } catch (e) {
      print('❌ Kullanıcı güncelleme hatası: $e');
      _showSnackBar('Kullanıcı güncellenirken hata: $e', Colors.red);
    }
  }

  // KULLANICI SİLME - GÜNCELLENDİ
  Future<void> _deleteUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kullanıcıyı Sil'),
        content: Text('$userName kullanıcısını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        print('🗑️ Kullanıcı siliniyor: $userId');
        // ID'yi string olarak gönder
        await _dbService.deleteUser(userId.toString());

        _showSnackBar('Kullanıcı başarıyla silindi', Colors.green);
        await _loadData();

      } catch (e) {
        print('❌ Kullanıcı silme hatası: $e');
        _showSnackBar('Kullanıcı silinirken hata: $e', Colors.red);
      }
    }
  }

  // DURUM DEĞİŞTİRME - GÜNCELLENDİ
  Future<void> _toggleUserStatus(String userId, bool currentStatus, String userName) async {
    try {
      final newStatus = !currentStatus;

      // ID'yi string olarak gönder
      await _dbService.updateUserStatus(userId.toString(), newStatus);

      final statusText = newStatus ? 'aktif' : 'pasif';
      _showSnackBar('$userName kullanıcısı $statusText yapıldı', Colors.green);
      await _loadData();

    } catch (e) {
      print('❌ Durum değiştirme hatası: $e');
      _showSnackBar('Durum değiştirilirken hata: $e', Colors.red);
    }
  }

  String _getDepartmentByType(String userType) {
    switch (userType) {
      case Constants.userTypeIlce:
        return 'İlçe MEM';
      case Constants.userTypeDenetim:
        return 'Denetim Birimi';
      case Constants.userTypeSchool:
        return 'Okul Müdürlüğü';
      default:
        return 'Belirtilmemiş';
    }
  }

  void _clearForm() {
    _emailController.clear();
    _nameController.clear();
    _phoneController.clear();
    _selectedType = Constants.userTypeSchool;
    _selectedSchool = '';
  }

  void _cancelEdit() {
    setState(() {
      _editingUser = null;
      _editEmailController.clear();
      _editNameController.clear();
      _editPhoneController.clear();
      _editSelectedType = Constants.userTypeSchool;
      _editSelectedSchool = '';
    });
  }

  void _startEdit(Map<String, dynamic> user) {
    setState(() {
      _editingUser = user;
      _editEmailController.text = user['email']?.toString() ?? '';
      _editNameController.text = user['full_name']?.toString() ?? '';
      _editPhoneController.text = user['phone']?.toString() ?? '';
      _editSelectedType = user['user_type']?.toString() ?? Constants.userTypeSchool;
      _editSelectedSchool = user['school_id']?.toString() ?? '';
    });
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

  // UI WIDGET'ları - OVERFLOW ÇÖZÜMLÜ
  Widget _buildFilterBar() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Kullanıcı Ara',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedSchoolFilter.isEmpty ? null : _selectedSchoolFilter,
            decoration: InputDecoration(
              labelText: 'Okula Göre Filtrele',
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: '', child: Text('Tüm Okullar')),
              ..._schools.map((school) => DropdownMenuItem(
                value: school['id'].toString(),
                child: Text(school['name']?.toString() ?? ''),
              )),
            ],
            onChanged: (value) => setState(() => _selectedSchoolFilter = value ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final activeUsers = _users.where((user) => user['is_active'] == true).length;
    final schoolUsers = _users.where((user) => user['user_type'] == Constants.userTypeSchool).length;
    final ilceUsers = _users.where((user) => user['user_type'] == Constants.userTypeIlce).length;
    final denetimUsers = _users.where((user) => user['user_type'] == Constants.userTypeDenetim).length;

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildStatItem('Toplam', _users.length, Icons.people),
            _buildStatItem('Aktif', activeUsers, Icons.check_circle, color: Colors.green),
            _buildStatItem('Okul', schoolUsers, Icons.school),
            _buildStatItem('İlçe', ilceUsers, Icons.account_balance),
            _buildStatItem('Denetim', denetimUsers, Icons.security),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon, {Color color = Colors.blue}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 4),
          Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yeni Kullanıcı Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Ad Soyad', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(labelText: 'Kullanıcı Tipi', border: OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: Constants.userTypeSchool, child: Text('Okul Kullanıcısı')),
                DropdownMenuItem(value: Constants.userTypeIlce, child: Text('İlçe Kullanıcısı')),
                DropdownMenuItem(value: Constants.userTypeDenetim, child: Text('Denetim Kullanıcısı')),
              ],
              onChanged: (value) => setState(() => _selectedType = value ?? Constants.userTypeSchool),
            ),
            if (_selectedType == Constants.userTypeSchool) ...[
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedSchool.isEmpty ? null : _selectedSchool,
                decoration: InputDecoration(labelText: 'Okul', border: OutlineInputBorder()),
                items: _schools.map((school) => DropdownMenuItem(
                  value: school['id'].toString(),
                  child: Text(school['name']?.toString() ?? ''),
                )).toList(),
                onChanged: (value) => setState(() => _selectedSchool = value ?? ''),
              ),
            ],
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addUser,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: _isLoading
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Kullanıcı Ekle'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => setState(() => _showAddForm = false),
                    child: Text('İptal'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    if (_editingUser == null) return SizedBox.shrink();

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kullanıcıyı Düzenle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            TextField(
              controller: _editEmailController,
              decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _editNameController,
              decoration: InputDecoration(labelText: 'Ad Soyad', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _editPhoneController,
              decoration: InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _editSelectedType,
              decoration: InputDecoration(labelText: 'Kullanıcı Tipi', border: OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: Constants.userTypeSchool, child: Text('Okul Kullanıcısı')),
                DropdownMenuItem(value: Constants.userTypeIlce, child: Text('İlçe Kullanıcısı')),
                DropdownMenuItem(value: Constants.userTypeDenetim, child: Text('Denetim Kullanıcısı')),
              ],
              onChanged: (value) => setState(() => _editSelectedType = value ?? Constants.userTypeSchool),
            ),
            if (_editSelectedType == Constants.userTypeSchool) ...[
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _editSelectedSchool.isEmpty ? null : _editSelectedSchool,
                decoration: InputDecoration(labelText: 'Okul', border: OutlineInputBorder()),
                items: _schools.map((school) => DropdownMenuItem(
                  value: school['id'].toString(),
                  child: Text(school['name']?.toString() ?? ''),
                )).toList(),
                onChanged: (value) => setState(() => _editSelectedSchool = value ?? ''),
              ),
            ],
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateUser,
                    child: _isLoading
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Güncelle'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _cancelEdit,
                    child: Text('İptal'),
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
    final isActive = user['is_active'] == true;
    final schoolName = user['schools'] != null
        ? user['schools']['name']?.toString()
        : 'Okul Atanmamış';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getUserColor(user['user_type']),
          child: Text(
            user['full_name']?.toString().substring(0, 1).toUpperCase() ?? '?',
            style: TextStyle(color: Colors.white),
          ),
        ),
        title: Text(user['full_name']?.toString() ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email']?.toString() ?? ''),
            Text('${_getUserTypeText(user['user_type'])} • $schoolName'),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isActive ? 'Aktif' : 'Pasif',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Düzenle')],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(isActive ? Icons.block : Icons.check_circle, size: 18),
                  SizedBox(width: 8),
                  Text(isActive ? 'Pasif Yap' : 'Aktif Yap'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.red))],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _startEdit(user);
                break;
              case 'toggle':
                _toggleUserStatus(user['id'].toString(), isActive, user['full_name']?.toString() ?? '');
                break;
              case 'delete':
                _deleteUser(user['id'].toString(), user['full_name']?.toString() ?? '');
                break;
            }
          },
        ),
      ),
    );
  }

  Color _getUserColor(String? userType) {
    switch (userType) {
      case Constants.userTypeIlce:
        return Colors.blue;
      case Constants.userTypeDenetim:
        return Colors.orange;
      case Constants.userTypeSchool:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getUserTypeText(String? userType) {
    switch (userType) {
      case Constants.userTypeIlce:
        return 'İlçe Kullanıcısı';
      case Constants.userTypeDenetim:
        return 'Denetim Kullanıcısı';
      case Constants.userTypeSchool:
        return 'Okul Kullanıcısı';
      default:
        return 'Kullanıcı';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kullanıcı Yönetimi'),
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Yenile'
          ),
          IconButton(
            icon: Icon(_showAddForm ? Icons.close : Icons.person_add),
            onPressed: () => setState(() => _showAddForm = !_showAddForm),
            tooltip: _showAddForm ? 'Formu Kapat' : 'Yeni Kullanıcı',
          ),
        ],
      ),
      body: SingleChildScrollView( // TÜM İÇERİĞİ SCROLL YAPALIM
        child: Column(
          children: [
            // Filtre çubuğu
            _buildFilterBar(),

            // İstatistik kartı
            _buildStatsCard(),

            // Formlar
            if (_showAddForm) _buildAddForm(),
            if (_editingUser != null) _buildEditForm(),

            // Liste - SABİT YÜKSEKLİK VEYA SHRINKWRAP
            Container(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.4, // Minimum yükseklik
              ),
              child: _isLoading
                  ? Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
                  : _filteredUsers.isEmpty
                  ? Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text('Kullanıcı bulunamadı'),
                      SizedBox(height: 8),
                      Text(
                        'Arama kriterlerinizi değiştirin veya yeni kullanıcı ekleyin',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
                  : ListView.builder(
                physics: NeverScrollableScrollPhysics(), // İç scroll'u devre dışı bırak
                shrinkWrap: true, // İçeriğe göre boyutlandır
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
              ),
            ),
            SizedBox(height: 20), // Alt boşluk
          ],
        ),
      ),
    );
  }
  }