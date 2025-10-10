// screens/school_vehicle_form_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '/services/database_service.dart';
import '/services/auth_service.dart';
import '/utils/constants.dart';

class SchoolVehicleFormScreen extends StatefulWidget {
  @override
  State<SchoolVehicleFormScreen> createState() => _SchoolVehicleFormScreenState();
}

class _SchoolVehicleFormScreenState extends State<SchoolVehicleFormScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _modelYearController = TextEditingController();

  // Form controllers
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverPhoneController = TextEditingController();

  final TextEditingController _guideNameController = TextEditingController();
  final TextEditingController _guideAgeController = TextEditingController();

  // Date fields
  DateTime? _driverLicenseExpiry;
  DateTime? _srcCertificateExpiry;
  DateTime? _insuranceExpiry;
  DateTime? _inspectionExpiry;
  DateTime? _routePermitExpiry;
  DateTime? _gCertificateExpiry;
  DateTime? _fireExtinguisherExpiry;

  // Photos
  String? _driverPhotoUrl;
  String? _vehiclePhotoUrl;
  bool _isSubmitting = false;
  String _transportType = 'private'; // BU SATIRI EKLE
  List<Map<String, dynamic>> _schools = [];
  List<String> _selectedSchoolIds = [];

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    try {
      final schools = await _dbService.getSchools();
      if (mounted) {
        setState(() {
          _schools = schools;
        });

        // Async olarak current user'ı al
        _setDefaultSchool();
      }
    } catch (e) {
      print('Okul yükleme hatası: $e');
    }
  }

  // AYRI BİR METOD OLUŞTUR:
  Future<void> _setDefaultSchool() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      final userSchool = currentUser?['department'];

      if (userSchool != null && _schools.isNotEmpty) {
        final school = _schools.firstWhere(
                (s) => s['name'] == userSchool,
            orElse: () => _schools.first
        );

        if (mounted) {
          setState(() {
            _selectedSchoolIds.add(school['id'].toString());
          });
        }
      }
    } catch (e) {
      print('Varsayılan okul ayarlama hatası: $e');
    }
  }

  // Taşıma türü seçimi ekle
  Widget _buildTransportTypeSection() {
    return _buildSection(
      'Taşıma Türü *',
      Icons.local_shipping,
      [
        Row(
          children: [
            Expanded(
              child: _buildTransportTypeRadio(
                'Özel Taşıma',
                'private',
                Icons.people,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildTransportTypeRadio(
                'Devlet Taşıması',
                'state',
                Icons.account_balance,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          _transportType == 'private'
              ? '• Rehber personel zorunlu\n• Araç yaş sınırı var (15 yıl)'
              : '• Rehber personel gerekmez\n• Araç yaş sınırı yok',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTransportTypeRadio(String title, String value, IconData icon) {
    return InkWell(
      onTap: () => setState(() => _transportType = value),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: _transportType == value ? Color(0xFF2196F3) : Colors.grey[300]!,
            width: _transportType == value ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: _transportType == value ? Color(0xFFE3F2FD) : Colors.white,
        ),
        child: Column(
          children: [
            Icon(icon, color: _transportType == value ? Color(0xFF2196F3) : Colors.grey),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _transportType == value ? Color(0xFF2196F3) : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Formda transport type section'ı ekle
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(),
          SizedBox(height: 20),
          _buildTransportTypeSection(),
          SizedBox(height: 20),
          _buildVehicleSection(),
          SizedBox(height: 20),
          _buildDriverSection(),
          SizedBox(height: 20),
          // SADECE ÖZEL TAŞIMA İÇİN REHBER BÖLÜMÜ
          if (_transportType == 'private') _buildGuideSection(),
          SizedBox(height: 20),
          _buildSchoolsSection(),
          SizedBox(height: 20),
          _buildDocumentsSection(),
          SizedBox(height: 20),
          _buildSubmitButton(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  // Validasyonda rehber koşulu
  bool _validateForm() {
    bool isValid = _plateController.text.isNotEmpty &&
        _modelController.text.isNotEmpty &&
        _modelYearController.text.isNotEmpty &&
        _capacityController.text.isNotEmpty &&
        _driverNameController.text.isNotEmpty &&
        _driverLicenseExpiry != null &&
        _srcCertificateExpiry != null &&
        _insuranceExpiry != null &&
        _inspectionExpiry != null &&
        _selectedSchoolIds.isNotEmpty;

    // SADECE ÖZEL TAŞIMA İÇİN REHBER ZORUNLU
    if (_transportType == 'private') {
      isValid = isValid &&
          _guideNameController.text.isNotEmpty &&
          _guideAgeController.text.isNotEmpty;
    }

    return isValid;
  }


  // school_vehicle_form_screen.dart - Okul seçimini güncelle
  Widget _buildSchoolsSection() {
    return _buildSection(
      'Taşıma Yapılacak Okullar *',
      Icons.school,
      [
        Text(
          'Bu aracın taşıma yapacağı okulları seçin (Çoklu seçim yapabilirsiniz):',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 12),

        // Toplu İşlem Butonları
        Card(
          elevation: 1,
          child: ListTile(
            leading: Icon(Icons.select_all, color: Color(0xFF2196F3)),
            title: Text('Toplu İşlem'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: _selectAllSchools,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text('Tümünü Seç', style: TextStyle(fontSize: 12)),
                ),
                SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _deselectAllSchools,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text('Hepsini Kaldır', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 12),

        // Seçilen Okul Bilgisi
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _selectedSchoolIds.isEmpty ? Colors.orange[50] : Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _selectedSchoolIds.isEmpty ? Icons.warning : Icons.check_circle,
                color: _selectedSchoolIds.isEmpty ? Colors.orange : Colors.blue,
                size: 16,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedSchoolIds.isEmpty
                      ? 'Lütfen en az bir okul seçin'
                      : '${_selectedSchoolIds.length} okul seçildi',
                  style: TextStyle(
                    color: _selectedSchoolIds.isEmpty ? Colors.orange[700] : Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12),

        // Okul Listesi - Açılır Kutu
        Card(
          elevation: 2,
          child: ExpansionTile(
            title: Text(
              'Okul Listesi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${_schools.length} okul - ${_selectedSchoolIds.length} seçili'),
            leading: Icon(Icons.school, color: Color(0xFF2196F3)),
            initiallyExpanded: true,
            children: [
              if (_schools.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Column(
                  children: _schools.map((school) => _buildSchoolCheckbox(school)).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSchoolCheckbox(Map<String, dynamic> school) {
    final isSelected = _selectedSchoolIds.contains(school['id']);

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (selected) {
          setState(() {
            if (selected == true) {
              _selectedSchoolIds.add(school['id']);
            } else {
              _selectedSchoolIds.remove(school['id']);
            }
          });
        },
        title: Text(school['name']),
        subtitle: Text(school['district']),
        secondary: Icon(Icons.school, color: Color(0xFF2196F3)),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Yeni Servis Aracı Kaydı'),
        backgroundColor: Color(0xFFE3F2FD),
      ),
      body: _isSubmitting ? _buildLoading() : _buildForm(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Kayıt yapılıyor...'),
        ],
      ),
    );
  }



  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Araç bilgilerini eksiksiz doldurun. Kayıtlar ilçe onayına gönderilecektir.',
                style: TextStyle(fontSize: 14, color: Colors.blue[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSection() {
    return _buildSection(
      'Araç Bilgileri',
      Icons.directions_bus,
      [
        _buildTextField('Plaka *', _plateController),
        SizedBox(height: 12),
        _buildTextField('Model *', _modelController),
        SizedBox(height: 12),
        _buildTextField('Model Yılı *', _modelYearController,
            hint: '2023',
            keyboardType: TextInputType.number
        ),
        SizedBox(height: 12),
        _buildTextField('Kapasite *', _capacityController, keyboardType: TextInputType.number),
      ],
    );
  }



  Widget _buildDriverSection() {
    return _buildSection(
      'Sürücü Bilgileri',
      Icons.person,
      [
        _buildTextField('Sürücü Adı Soyadı *', _driverNameController, hint: 'Mehmet Demir'),
        SizedBox(height: 12),
        _buildTextField('Sürücü Telefonu', _driverPhoneController, hint: '0555 123 4567'),
        SizedBox(height: 12),
        _buildPhotoField('Sürücü Fotoğrafı *', _driverPhotoUrl, _pickDriverPhoto),
        SizedBox(height: 12),
        _buildDateFieldWithLabel( // DEĞİŞTİ
            'Ehliyet Geçerlilik Tarihi *',
            _driverLicenseExpiry,
                (date) {
              setState(() => _driverLicenseExpiry = date);
            }
        ),
        SizedBox(height: 12),
        _buildDateFieldWithLabel( // DEĞİŞTİ
            'SRC Belge Geçerlilik Tarihi *',
            _srcCertificateExpiry,
                (date) {
              setState(() => _srcCertificateExpiry = date);
            }
        ),
      ],
    );
  }

  Widget _buildDocumentsSection() {
    return _buildSection(
      'Evrak Geçerlilik Tarihleri',
      Icons.description,
      [
        _buildDateFieldWithLabel( // DEĞİŞTİ
            'Sigorta Bitiş Tarihi *',
            _insuranceExpiry,
                (date) {
              setState(() => _insuranceExpiry = date);
            }
        ),
        SizedBox(height: 12),
        _buildDateFieldWithLabel( // DEĞİŞTİ
            'Muayene Bitiş Tarihi *',
            _inspectionExpiry,
                (date) {
              setState(() => _inspectionExpiry = date);
            }
        ),
        SizedBox(height: 12),
        _buildDateFieldWithLabel( // DEĞİŞTİ
            'Güzergah İzin Belgesi Bitiş',
            _routePermitExpiry,
                (date) {
              setState(() => _routePermitExpiry = date);
            }
        ),
        SizedBox(height: 12),
        _buildDateFieldWithLabel( // DEĞİŞTİ
            'G Belgesi Bitiş Tarihi',
            _gCertificateExpiry,
                (date) {
              setState(() => _gCertificateExpiry = date);
            }
        ),
        // YANGIN TÜPÜ KALDIRILDI - SADECE DENETİM İÇİN
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Color(0xFF2196F3)),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {String? hint, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      keyboardType: keyboardType,
    );
  }

  // ALTERNATİF: Daha güzel date field
  Widget _buildDateFieldWithLabel(String label, DateTime? selectedDate, ValueChanged<DateTime> onDateSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: ListTile(
            leading: Icon(Icons.calendar_today, color: Color(0xFF2196F3)),
            title: Text(
              selectedDate != null
                  ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                  : 'Tarih seçin...',
              style: TextStyle(
                color: selectedDate != null ? Colors.black : Colors.grey[500],
              ),
            ),
            trailing: selectedDate != null ? _buildDateStatus(selectedDate) : null,
            onTap: () => _selectDate(context, selectedDate, onDateSelected),
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDateStatus(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    Color color;
    String text;

    if (date.isBefore(now)) {
      color = Colors.red;
      text = 'SÜRESİ DOLMUŞ';
    } else if (difference <= 30) {
      color = Colors.orange;
      text = '$difference gün';
    } else if (difference <= 90) {
      color = Colors.yellow[700]!;
      text = '$difference gün';
    } else {
      color = Colors.green;
      text = '$difference gün';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPhotoField(String label, String? photoUrl, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: photoUrl != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(photoUrl, fit: BoxFit.cover),
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, size: 40, color: Colors.grey[400]),
                SizedBox(height: 8),
                Text('Fotoğraf Seç', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isValid = _validateForm();

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isValid ? _submitForm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isValid ? Color(0xFF2196F3) : Colors.grey[400],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          'KAYDET VE ONAYA GÖNDER',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }



  Future<void> _selectDate(BuildContext context, DateTime? initialDate, ValueChanged<DateTime> onDateSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Future<void> _pickDriverPhoto() async {
    // TODO: Implement photo upload to Supabase Storage
    _showSnackBar('Fotoğraf yükleme özelliği yakında eklenecek');
  }

  Future<void> _pickVehiclePhoto() async {
    // TODO: Implement photo upload to Supabase Storage
    _showSnackBar('Fotoğraf yükleme özelliği yakında eklenecek');
  }

  Future<void> _submitForm() async {
    if (!_validateForm() || _selectedSchoolIds.isEmpty) {
      _showSnackBar('Lütfen zorunlu alanları ve okulları seçiniz', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _dbService.createVehicle(
        plate: _plateController.text,
        model: _modelController.text,
        modelYear: int.tryParse(_modelYearController.text) ?? 2023,
        capacity: int.parse(_capacityController.text),
        driverName: _driverNameController.text,
        transportType: _transportType, // ARTIK TANIMLI
        driverPhone: _driverPhoneController.text.isEmpty ? null : _driverPhoneController.text,
        driverLicenseExpiry: _driverLicenseExpiry,
        srcCertificateExpiry: _srcCertificateExpiry,
        insuranceExpiry: _insuranceExpiry,
        inspectionExpiry: _inspectionExpiry,
        routePermitExpiry: _routePermitExpiry,
        gCertificateExpiry: _gCertificateExpiry,
        driverPhotoUrl: _driverPhotoUrl,
        schoolIds: _selectedSchoolIds,
      );

      _showSnackBar('Araç kaydı başarıyla oluşturuldu! İlçe onayına gönderildi.', Colors.green);

      Navigator.pop(context, true);

    } catch (e) {
      _showSnackBar('Kayıt sırasında hata oluştu: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildGuideSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rehber Bilgileri',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _guideNameController,
          decoration: InputDecoration(
            labelText: 'Rehber Adı Soyadı',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _guideAgeController,
          decoration: InputDecoration(
            labelText: 'Rehber Yaşı',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: 16),
      ],
    );
  }

  // Don't forget to dispose the controllers
  @override
  void dispose() {
    _guideNameController.dispose();
    _guideAgeController.dispose();
    super.dispose();
  }


// Toplu işlem metodları
  void _selectAllSchools() {
    setState(() {
      _selectedSchoolIds = _schools.map((school) => school['id'].toString()).toList();
    });
    _showSnackBar('Tüm okullar seçildi');
  }

  void _deselectAllSchools() {
    setState(() {
      _selectedSchoolIds.clear();
    });
    _showSnackBar('Tüm okullar kaldırıldı');
  }  void _clearForm() {
    _plateController.clear();
    _modelController.clear();
    _capacityController.clear();
    _driverNameController.clear();
    _driverPhoneController.clear();

    setState(() {
      _driverLicenseExpiry = null;
      _srcCertificateExpiry = null;
      _insuranceExpiry = null;
      _inspectionExpiry = null;
      _routePermitExpiry = null;
      _gCertificateExpiry = null;
      _fireExtinguisherExpiry = null;
      _driverPhotoUrl = null;
      _vehiclePhotoUrl = null;
    });
  }

  void _showSnackBar(String message, [Color color = Colors.blue]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }
}