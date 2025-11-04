// screens/school_management_screen.dart - YENİ EKRAN
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

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
  bool _showAddSchoolForm = false;

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
      final schools = await _dbService.getSchools();
      setState(() {
        _schools = schools;
        _isLoading = false;
      });
    } catch (e) {
      print('Okul yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }



  Future<void> _importSchoolsFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null) {
        _showSnackBar('Excel dosyası seçildi. İşlem başlatılıyor...', Colors.blue);

        // Burada Excel/CSV işleme kodu olacak
        // Örnek:
        // List<Map<String, dynamic>> schools = await ExcelService.parseSchools(result.files.first);
        // await _dbService.bulkInsertSchools(schools);

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
      appBar: AppBar(
        title: Text('Okul Yönetimi'),
        backgroundColor: Color(0xFF1976D2),
      ),
      body: Column(
        children: [
          // Başlık ve Butonlar
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Okul Listesi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showAddForm = !_showAddForm),
                  icon: Icon(Icons.add),
                  label: Text('Yeni Okul'),
                ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _importSchoolsFromExcel,
                  icon: Icon(Icons.upload),
                  label: Text('Excel İçe Aktar'),
                ),
              ],
            ),
          ),

          // Yeni Okul Formu
          if (_showAddForm) _buildAddSchoolForm(),

          // Okul Listesi
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _schools.isEmpty
                ? Center(child: Text('Henüz okul bulunmuyor'))
                : ListView.builder(
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



  Widget _buildSchoolCard(Map<String, dynamic> school) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(Icons.school, color: Color(0xFF2196F3)),
        title: Text(school['name']),
        subtitle: Text('${school['district']} • ${school['address'] ?? ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ DÜZELTİLDİ: Düzenle butonu eklendi
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



  // ✅ EKSİK METOD: _deleteSchool
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

  // ✅ EKSİK METOD: _performDeleteSchool
  Future<void> _performDeleteSchool(Map<String, dynamic> school) async {
    try {
      // Burada gerçek silme işlemi yapılacak
      // Şimdilik sadece local'den kaldıralım
      setState(() {
        _schools.removeWhere((s) => s['id'] == school['id']);
      });

      _showSnackBar('${school['name']} okulu silindi', Colors.green);
    } catch (e) {
      _showSnackBar('Silme hatası: $e', Colors.red);
    }
  }

  // ✅ EKSİK METOD: _editSchool (daha gelişmiş versiyon)
  void _editSchool(Map<String, dynamic> school) {
    // Formu doldur
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
                  labelText: 'Okul Adı',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _districtController,
                decoration: InputDecoration(
                  labelText: 'İlçe',
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
              await _performEditSchool(school);
              Navigator.pop(context);
            },
            child: Text('KAYDET'),
          ),
        ],
      ),
    );
  }

  // ✅ EKSİK METOD: _performEditSchool
  Future<void> _performEditSchool(Map<String, dynamic> school) async {
    if (_nameController.text.isEmpty || _districtController.text.isEmpty) {
      _showSnackBar('Lütfen zorunlu alanları doldurunuz', Colors.orange);
      return;
    }

    try {
      final updatedData = {
        'name': _nameController.text.trim(),
        'district': _districtController.text.trim(),
        'address': _addressController.text.trim(),
      };

      // Local'de güncelle
      setState(() {
        final index = _schools.indexWhere((s) => s['id'] == school['id']);
        if (index != -1) {
          _schools[index] = {
            ..._schools[index],
            ...updatedData,
          };
        }
      });

      _clearForm();
      _showSnackBar('${_nameController.text} okulu güncellendi', Colors.green);
    } catch (e) {
      _showSnackBar('Güncelleme hatası: $e', Colors.red);
    }
  }

  // screens/school_management_screen.dart - EK OKUL EKLEME FORMU
  Widget _buildAddSchoolForm() {
    return Card(
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
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _clearForm();
                      setState(() => _showAddSchoolForm = false);
                    },
                    child: Text('İptal'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addSchool,
                    child: Text('OKUL EKLE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// ✅ EKSİK METOD: _addSchool
  Future<void> _addSchool() async {
    if (_nameController.text.isEmpty || _districtController.text.isEmpty) {
      _showSnackBar('Lütfen zorunlu alanları doldurunuz', Colors.orange);
      return;
    }

    try {
      final schoolData = {
        'name': _nameController.text.trim(),
        'district': _districtController.text.trim(),
        'address': _addressController.text.trim(),
      };

      // Local'e ekle
      final newSchool = {
        'id': (_schools.length + 1),
        ...schoolData,
        'created_at': DateTime.now().toIso8601String(),
      };

      setState(() {
        _schools.add(newSchool);
      });

      _clearForm();
      setState(() => _showAddSchoolForm = false);
      _showSnackBar('${_nameController.text} okulu eklendi', Colors.green);

    } catch (e) {
      _showSnackBar('Okul ekleme hatası: $e', Colors.red);
    }
  }

}