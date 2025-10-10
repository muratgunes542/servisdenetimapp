// screens/vehicle_edit_screen.dart
import 'package:flutter/material.dart';
import '/services/database_service.dart';
import '/utils/constants.dart';

class VehicleEditScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const VehicleEditScreen({Key? key, required this.vehicle}) : super(key: key);

  @override
  State<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends State<VehicleEditScreen> {
  final DatabaseService _dbService = DatabaseService();

  // Form controllers
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _modelYearController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverPhoneController = TextEditingController();

  // Rehber personel controllers
  final TextEditingController _guideNameController = TextEditingController();
  final TextEditingController _guideAgeController = TextEditingController();



  // Taşıma türü ve tarihler
  String _transportType = 'private'; // 'private' veya 'state'
  DateTime? _driverLicenseExpiry;
  DateTime? _srcCertificateExpiry;
  DateTime? _insuranceExpiry;
  DateTime? _inspectionExpiry;
  DateTime? _routePermitExpiry;
  DateTime? _gCertificateExpiry;

  // Rehber personel durumu
  bool _hasReflectiveVest = false;
  bool _hasWarningLights = false;

  String? _guidePhotoUrl;

  bool _isSubmitting = false;
  String? _driverPhotoUrl;
  List<String> _selectedSchoolIds = [];
  List<Map<String, dynamic>> _schools = [];


  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadSchools(); // BU SATIRI EKLE
  }


  // Okulları yükle
  Future<void> _loadSchools() async {
    try {
      final schools = await _dbService.getSchools();
      setState(() {
        _schools = schools;
      });
    } catch (e) {
      print('Okul yükleme hatası: $e');
    }
  }

  void _initializeForm() {
    final vehicle = widget.vehicle;

    // Temel bilgiler
    _plateController.text = vehicle['plate'] ?? '';
    _modelController.text = vehicle['model'] ?? '';
    _capacityController.text = vehicle['capacity']?.toString() ?? '';
    _driverNameController.text = vehicle['driver_name'] ?? '';
    _driverPhoneController.text = vehicle['driver_phone'] ?? '';
    _driverPhotoUrl = vehicle['driver_photo_url']; // BU SATIRI EKLE

    // Taşıma türü
    _transportType = vehicle['transport_type'] ?? 'private';

    // Tarihler
    if (vehicle['driver_license_expiry'] != null) {
      _driverLicenseExpiry = DateTime.parse(vehicle['driver_license_expiry']);
    }
    if (vehicle['src_certificate_expiry'] != null) {
      _srcCertificateExpiry = DateTime.parse(vehicle['src_certificate_expiry']);
    }
    if (vehicle['insurance_expiry'] != null) {
      _insuranceExpiry = DateTime.parse(vehicle['insurance_expiry']);
    }
    if (vehicle['inspection_expiry'] != null) {
      _inspectionExpiry = DateTime.parse(vehicle['inspection_expiry']);
    }
    if (vehicle['route_permit_expiry'] != null) {
      _routePermitExpiry = DateTime.parse(vehicle['route_permit_expiry']);
    }
    if (vehicle['g_certificate_expiry'] != null) {
      _gCertificateExpiry = DateTime.parse(vehicle['g_certificate_expiry']);
    }

    // Mevcut okulları yükle
    _loadVehicleSchools(); // BU SATIRI EKLE
  }

  // Aracın bağlı olduğu okulları yükle
  Future<void> _loadVehicleSchools() async {
    try {
      final vehicleSchools = await _dbService.getVehicleSchools(widget.vehicle['id']);
      setState(() {
        _selectedSchoolIds = vehicleSchools
            .map((vs) => vs['schools']['id'].toString())
            .toList();
      });
    } catch (e) {
      print('Araç okulları yükleme hatası: $e');
    }
  }

  // Okul seçim bölümünü ekle
  // vehicle_edit_screen.dart - Okul seçim bölümünü güncelle
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

        // Açılır Kutu - Tümünü Seç/Hepsini Kaldır
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

        // Seçilen Okul Sayısı
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Text(
                '${_selectedSchoolIds.length} okul seçildi',
                style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        SizedBox(height: 12),

        // Okul Listesi - Açılır Kutu
        ExpansionTile(
          title: Text(
            'Okul Listesi (${_schools.length} okul)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(_selectedSchoolIds.isEmpty ? 'Hiç okul seçilmedi' : '${_selectedSchoolIds.length} okul seçildi'),
          leading: Icon(Icons.list, color: Color(0xFF2196F3)),
          initiallyExpanded: true,
          children: [
            if (_schools.isEmpty)
              Padding(
                padding: EdgeInsets.all(16),
                child: Text('Yükleniyor...', style: TextStyle(color: Colors.grey)),
              )
            else
              Column(
                children: _schools.map((school) => _buildSchoolCheckbox(school)).toList(),
              ),
          ],
        ),

        // Hızlı Filtre Butonları
        SizedBox(height: 12),
        Text('Hızlı Filtre:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickFilterChip('Üsküdar', 'Üsküdar'),
            _buildQuickFilterChip('Kadıköy', 'Kadıköy'),
            _buildQuickFilterChip('Beşiktaş', 'Beşiktaş'),
            _buildQuickFilterChip('Ataşehir', 'Ataşehir'),
          ],
        ),
      ],
    );
  }

// Gelişmiş Okul Checkbox
  Widget _buildSchoolCheckbox(Map<String, dynamic> school) {
    final isSelected = _selectedSchoolIds.contains(school['id'].toString());
    final district = school['district'] ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 1,
      color: isSelected ? Colors.blue[50] : Colors.white,
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (selected) {
          setState(() {
            if (selected == true) {
              _selectedSchoolIds.add(school['id'].toString());
            } else {
              _selectedSchoolIds.remove(school['id'].toString());
            }
          });
        },
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              school['name'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Color(0xFF2196F3) : Colors.black,
              ),
            ),
            SizedBox(height: 2),
            Text(
              district,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.blue[600] : Colors.grey[600],
              ),
            ),
          ],
        ),
        secondary: Icon(
          Icons.school,
          color: isSelected ? Color(0xFF2196F3) : Colors.grey,
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

// Hızlı Filtre Chip
  Widget _buildQuickFilterChip(String label, String district) {
    final schoolsInDistrict = _schools.where((s) => s['district'] == district).toList();
    final selectedInDistrict = _selectedSchoolIds.where((id) {
      final school = _schools.firstWhere((s) => s['id'].toString() == id, orElse: () => {});
      return school['district'] == district;
    }).length;

    return FilterChip(
      label: Text('$label ($selectedInDistrict/${schoolsInDistrict.length})'),
      selected: selectedInDistrict > 0,
      onSelected: (selected) {
        if (selected) {
          // Bu ilçedeki tüm okulları seç
          setState(() {
            for (final school in schoolsInDistrict) {
              final schoolId = school['id'].toString();
              if (!_selectedSchoolIds.contains(schoolId)) {
                _selectedSchoolIds.add(schoolId);
              }
            }
          });
        } else {
          // Bu ilçedeki tüm okulları kaldır
          setState(() {
            for (final school in schoolsInDistrict) {
              final schoolId = school['id'].toString();
              _selectedSchoolIds.remove(schoolId);
            }
          });
        }
      },
      selectedColor: Color(0xFF2196F3),
      checkmarkColor: Colors.white,
    );
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
  }
  // Forma okul bölümünü ekle
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTransportTypeSection(),
          SizedBox(height: 20),
          _buildVehicleSection(),
          SizedBox(height: 20),
          _buildDriverSection(),
          SizedBox(height: 20),
          if (_transportType == 'private') _buildGuideSection(),
          SizedBox(height: 20),
          _buildSchoolsSection(), // BU SATIRI EKLE
          SizedBox(height: 20),
          _buildDocumentsSection(),
          SizedBox(height: 20),
          _buildSubmitButton(),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Araç Düzenle'),
        backgroundColor: Color(0xFFE3F2FD),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _isSubmitting ? null : _submitForm,
          ),
        ],
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
          Text('Kaydediliyor...'),
        ],
      ),
    );
  }



  Widget _buildTransportTypeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Taşıma Türü *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTransportTypeRadio(
                    'Özel Taşıma',
                    'private',
                    Icons.people,
                    'Okul servisi, özel taşımacılık',
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildTransportTypeRadio(
                    'Devlet Taşıması',
                    'state',
                    Icons.account_balance,
                    'Resmi kurum taşımacılığı',
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
        ),
      ),
    );
  }

  Widget _buildTransportTypeRadio(String title, String value, IconData icon, String description) {
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
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
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
        _buildTextField('Sürücü Adı Soyadı *', _driverNameController),
        SizedBox(height: 12),
        _buildTextField('Sürücü Telefonu', _driverPhoneController),
        SizedBox(height: 12),
        _buildPhotoField('Sürücü Fotoğrafı', _driverPhotoUrl, _pickDriverPhoto), // BU SATIRI EKLE
        SizedBox(height: 12),
        _buildDateFieldWithLabel(
            'Ehliyet Geçerlilik Tarihi *',
            _driverLicenseExpiry,
                (date) => setState(() => _driverLicenseExpiry = date)
        ),
        SizedBox(height: 12),
        _buildDateFieldWithLabel(
            'SRC Belge Geçerlilik Tarihi *',
            _srcCertificateExpiry,
                (date) => setState(() => _srcCertificateExpiry = date)
        ),
      ],
    );
  }

  Future<void> _pickDriverPhoto() async {
    _showSnackBar('Şoför fotoğrafı yükleme yakında eklenecek');
  }


  Widget _buildGuideSection() {
    return _buildSection(
      'Rehber Personel Bilgileri *',
      Icons.accessible,
      [
        _buildTextField('Rehber Adı Soyadı *', _guideNameController),
        SizedBox(height: 12),
        _buildTextField('Rehber Yaşı *', _guideAgeController, keyboardType: TextInputType.number),
        SizedBox(height: 12),
        _buildPhotoField('Rehber Fotoğrafı', _guidePhotoUrl, _pickGuidePhoto),
        SizedBox(height: 12),

      ],
    );
  }

  Widget _buildDocumentsSection() {
    return _buildSection(
      'Evrak Geçerlilik Tarihleri',
      Icons.description,
      [
        _buildDateFieldWithLabel(
            'Sigorta Bitiş Tarihi *',
            _insuranceExpiry,
                (date) => setState(() => _insuranceExpiry = date)
        ),
        SizedBox(height: 12),
        _buildDateFieldWithLabel(
            'Muayene Bitiş Tarihi *',
            _inspectionExpiry,
                (date) => setState(() => _inspectionExpiry = date)
        ),
        SizedBox(height: 12),
        _buildDateFieldWithLabel(
            'Güzergah İzin Belgesi Bitiş',
            _routePermitExpiry,
                (date) => setState(() => _routePermitExpiry = date)
        ),
        SizedBox(height: 12),
        _buildDateFieldWithLabel(
            'G Belgesi Bitiş Tarihi',
            _gCertificateExpiry,
                (date) => setState(() => _gCertificateExpiry = date)
        ),
      ],
    );
  }

  // Diğer widget metodları (buildSection, buildTextField, buildDateFieldWithLabel, buildPhotoField)
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
  // Bunlar SchoolVehicleFormScreen'deki gibi olacak, kopyala-yapıştır yapabilirsin

  Widget _buildSubmitButton() {
    final isValid = _validateForm();

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isValid ? _submitForm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isValid ? Colors.green : Colors.grey[400],
        ),
        child: Text(
          'DEĞİŞİKLİKLERİ KAYDET',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  // vehicle_edit_screen.dart - en alta bu metodları ekle:
// Diğer widget metodları (SchoolVehicleFormScreen'den kopyala)


  Widget _buildDateField(DateTime? selectedDate, ValueChanged<DateTime> onDateSelected) {
    return InkWell(
      onTap: () => _selectDate(context, selectedDate, onDateSelected),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
            SizedBox(width: 12),
            Text(
              selectedDate != null
                  ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                  : 'Tarih Seçin',
              style: TextStyle(
                color: selectedDate != null ? Colors.black : Colors.grey[600],
              ),
            ),
            Spacer(),
            if (selectedDate != null)
              _buildDateStatus(selectedDate),
          ],
        ),
      ),
    );
  }


// EKSİK METOD: _selectDate
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

  bool _validateForm() {
    bool isValid = _plateController.text.isNotEmpty &&
        _modelController.text.isNotEmpty &&
        _modelYearController.text.isNotEmpty &&
        _capacityController.text.isNotEmpty &&
        _driverNameController.text.isNotEmpty &&
        _driverLicenseExpiry != null &&
        _srcCertificateExpiry != null &&
        _insuranceExpiry != null &&
        _inspectionExpiry != null;

    // Özel taşıma için rehber personel zorunlu
    if (_transportType == 'private') {
      isValid = isValid &&
          _guideNameController.text.isNotEmpty &&
          _guideAgeController.text.isNotEmpty;
    }

    // Okul seçimi zorunlu
    isValid = isValid && _selectedSchoolIds.isNotEmpty;

    return isValid;
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) {
      _showSnackBar('Lütfen zorunlu alanları doldurunuz', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // widget.vehicle['id'] integer geliyor, string'e çevir
      final vehicleId = widget.vehicle['id'].toString();

      await _dbService.updateVehicle(
        vehicleId: vehicleId,
        plate: _plateController.text,
        model: _modelController.text,
        modelYear: int.tryParse(_modelYearController.text) ?? 2023, // BU SATIRI EKLE
        capacity: int.parse(_capacityController.text),
        driverName: _driverNameController.text,
        transportType: _transportType,
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

      _showSnackBar('Araç bilgileri başarıyla güncellendi!', Colors.green);
      Navigator.pop(context, true);

    } catch (e) {
      _showSnackBar('Güncelleme hatası: $e', Colors.red);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }


  Future<void> _pickGuidePhoto() async {
    _showSnackBar('Rehber fotoğrafı yükleme yakında eklenecek');
  }

  void _showSnackBar(String message, [Color color = Colors.blue]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}