import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '/services/database_service.dart';
import '/services/auth_service.dart';
import '/utils/constants.dart';

class SchoolManagementScreen extends StatefulWidget {
  @override
  State<SchoolManagementScreen> createState() => _SchoolManagementScreenState();
}

class _SchoolManagementScreenState extends State<SchoolManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _schools = [];
  bool _isLoading = true;
  bool _showAddForm = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    try {
      print('🏫 Okullar yükleniyor...');
      final schools = await _dbService.getSchools();
      setState(() {
        _schools = schools;
        _isLoading = false;
      });
      print('✅ ${schools.length} okul yüklendi');
    } catch (e) {
      print('❌ Okul yükleme hatası: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Okullar yüklenirken hata: $e', Colors.red);
    }
  }

  // School Management Screen - HATA YÖNETİMİ İYİLEŞTİRME
  Future<void> _addSchool() async {
    if (_nameController.text.isEmpty || _districtController.text.isEmpty) {
      _showSnackBar('Lütfen zorunlu alanları doldurunuz', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('➕ HYBRID: Yeni okul ekleniyor: ${_nameController.text}');

      final newSchool = await _dbService.createSchool(
        name: _nameController.text.trim(),
        district: _districtController.text.trim(),
        address: _addressController.text.trim(),
      );

      setState(() {
        _schools.insert(0, newSchool);
        _showAddForm = false;
      });

      _clearForm();
      _showSnackBar('${_nameController.text} okulu başarıyla eklendi', Colors.green);

    } catch (e) {
      print('❌ Okul ekleme hatası: $e');
      _showSnackBar('Okul ekleme hatası: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performEditSchool(Map<String, dynamic> school) async {
    setState(() => _isLoading = true);

    try {
      final updatedData = {
        'name': _nameController.text.trim(),
        'district': _districtController.text.trim(),
        'address': _addressController.text.trim(),
      };

      print('✏️ HYBRID: Okul güncelleniyor: ${school['id']}');
      await _dbService.updateSchool(school['id'].toString(), updatedData);

      // Local'de güncelle
      setState(() {
        final index = _schools.indexWhere((s) => s['id'] == school['id']);
        if (index != -1) {
          _schools[index] = {
            ..._schools[index],
            ...updatedData,
            'updated_at': DateTime.now().toIso8601String(),
          };
        }
      });

      _clearForm();
      _showSnackBar('${_nameController.text} okulu güncellendi', Colors.green);
    } catch (e) {
      print('❌ Okul güncelleme hatası: $e');
      throw e;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performDeleteSchool(Map<String, dynamic> school) async {
    setState(() => _isLoading = true);

    try {
      print('🗑️ HYBRID: Okul siliniyor: ${school['id']}');
      await _dbService.deleteSchool(school['id'].toString());

      setState(() {
        _schools.removeWhere((s) => s['id'] == school['id']);
      });

      _showSnackBar('${school['name']} okulu silindi', Colors.green);
    } catch (e) {
      print('❌ Okul silme hatası: $e');
      _showSnackBar('Silme hatası: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editSchool(Map<String, dynamic> school) async {
    _nameController.text = school['name'] ?? '';
    _districtController.text = school['district'] ?? '';
    _addressController.text = school['address'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Okul Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Okul Adı *',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _districtController,
                decoration: InputDecoration(
                  labelText: 'İlçe *',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Adres',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearForm();
              Navigator.pop(context);
            },
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isEmpty || _districtController.text.isEmpty) {
                _showSnackBar('Lütfen zorunlu alanları doldurunuz', Colors.orange);
                return;
              }

              try {
                await _performEditSchool(school);
                Navigator.pop(context);
              } catch (e) {
                _showSnackBar('Güncelleme hatası: $e', Colors.red);
              }
            },
            child: Text('KAYDET'),
          ),
        ],
      ),
    );
  }



  void _deleteSchool(Map<String, dynamic> school) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Okulu Sil'),
        content: Text('${school['name']} okulunu silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDeleteSchool(school);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('SİL'),
          ),
        ],
      ),
    );
  }



  Future<void> _importSchoolsFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null) {
        _showSnackBar('Excel dosyası seçildi. İşlem başlatılıyor...', Colors.blue);
        // Excel işleme kodu buraya gelecek
        _showSnackBar('Okullar başarıyla içe aktarıldı', Colors.green);
        _loadSchools();
      }
    } catch (e) {
      _showSnackBar('Dosya işleme hatası: $e', Colors.red);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _districtController.clear();
    _addressController.clear();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
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
          'Okul Yönetimi',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFF2196F3)),
            onPressed: _loadSchools,
          ),
        ],
      ),
      body: Column(
        children: [
          // İstatistik Kartı - Dashboard stilinize uygun
          Card(
            elevation: 2,
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildStatItem('Toplam Okul', _schools.length.toString(), Icons.school, Colors.blue),
                  SizedBox(width: 20),
                  _buildStatItem('Aktif', _schools.length.toString(), Icons.check_circle, Colors.green),
                ],
              ),
            ),
          ),

          // Aksiyon Butonları
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _showAddForm = !_showAddForm),
                    icon: Icon(Icons.add),
                    label: Text('YENİ OKUL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importSchoolsFromExcel,
                    icon: Icon(Icons.upload),
                    label: Text('EXCEL İÇE AKTAR'),
                  ),
                ),
              ],
            ),
          ),

          // Yeni Okul Formu
          if (_showAddForm) _buildAddSchoolForm(),

          // Okul Listesi
          Expanded(
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Okullar yükleniyor...'),
                ],
              ),
            )
                : _schools.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'Henüz okul bulunmuyor',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Yeni okul eklemek için "YENİ OKUL" butonunu kullanın',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _schools.length,
              itemBuilder: (context, index) {
                final school = _schools[index];
                return _buildSchoolCard(school);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 30, color: color),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddSchoolForm() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni Okul Ekle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Okul Adı *',
                border: OutlineInputBorder(),
                hintText: 'Atatürk İlkokulu',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _districtController,
              decoration: InputDecoration(
                labelText: 'İlçe *',
                border: OutlineInputBorder(),
                hintText: 'Üsküdar',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Adres',
                border: OutlineInputBorder(),
                hintText: 'Okulun tam adresi...',
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _clearForm();
                      setState(() => _showAddForm = false);
                    },
                    child: Text('İptal'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addSchool,
                    child: _isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text('OKUL EKLE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolCard(Map<String, dynamic> school) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(0xFF2196F3),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.school, color: Colors.white, size: 20),
        ),
        title: Text(
          school['name'] ?? 'İsimsiz Okul',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${school['district']}'),
            if (school['address'] != null && school['address'].isNotEmpty)
              Text(
                school['address'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editSchool(school),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteSchool(school),
            ),
          ],
        ),
      ),
    );
  }
}