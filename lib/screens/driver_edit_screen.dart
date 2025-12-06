//driver_edit_screen.dart
import 'package:flutter/material.dart';
import '/services/database_service.dart';
import '/utils/constants.dart';

class DriverEditScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final Map<String, dynamic>? driverData;

  const DriverEditScreen({
    Key? key,
    required this.vehicle,
    this.driverData,
  }) : super(key: key);

  @override
  _DriverEditScreenState createState() => _DriverEditScreenState();
}

class _DriverEditScreenState extends State<DriverEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();

  DateTime? _birthDate;
  DateTime? _licenseExpiry;
  DateTime? _srcCertificateExpiry;
  String? _selectedLicenseType;
  String? _driverPhotoUrl;
  bool _isSubmitting = false;

  final List<String> _licenseTypes = ['B', 'C', 'D', 'D1', 'E', 'B7', 'E5'];

  @override
  void initState() {
    super.initState();
    _initializeForm();
    // Widget'dan gelen data yoksa database'den yükle
    if (widget.driverData == null) {
      _loadDriverData();
    }
  }

  Future<void> _loadDriverData() async {
    try {
      final data = await DatabaseService().getDriverByVehicleId(widget.vehicle['id']);
      if (data != null && mounted) {
        setState(() {
          _initializeFormWithData(data);
        });
      }
    } catch (e) {
      print('Sürücü verisi yükleme hatası: $e');
    }
  }

  void _initializeFormWithData(Map<String, dynamic> data) {
    _nameController.text = data['full_name'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _licenseNumberController.text = data['license_number'] ?? '';
    _selectedLicenseType = data['license_type'] ?? 'D';

    if (data['birth_date'] != null) {
      _birthDate = DateTime.parse(data['birth_date']);
    }
    if (data['license_expiry_date'] != null) {
      _licenseExpiry = DateTime.parse(data['license_expiry_date']);
    }
    if (data['src_certificate_expiry'] != null) {
      _srcCertificateExpiry = DateTime.parse(data['src_certificate_expiry']);
    }
  }

  Future<void> _loadData() async {
    try {
      final data = await _dbService.getDriverByVehicleId(widget.vehicle['id']);
      if (data != null) {
        setState(() {
          // Verileri form alanlarına yükle
        });
      }
    } catch (e) {
      print('Veri yükleme hatası: $e');
    }
  }

  void _initializeForm() {
    if (widget.driverData != null) {
      _nameController.text = widget.driverData!['full_name'] ?? '';
      _phoneController.text = widget.driverData!['phone'] ?? '';
      _licenseNumberController.text = widget.driverData!['license_number'] ?? '';
      _selectedLicenseType = widget.driverData!['license_type'] ?? 'D';

      if (widget.driverData!['birth_date'] != null) {
        _birthDate = DateTime.parse(widget.driverData!['birth_date']);
      }
      if (widget.driverData!['license_expiry_date'] != null) {
        _licenseExpiry = DateTime.parse(widget.driverData!['license_expiry_date']);
      }
      if (widget.driverData!['src_certificate_expiry'] != null) {
        _srcCertificateExpiry = DateTime.parse(widget.driverData!['src_certificate_expiry']);
      }

      _driverPhotoUrl = widget.driverData!['photo_url'];
    }
  }

  // Doğum tarihi seçimi - DÜZELTİLDİ
  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1980), // 1980 varsayılan
      firstDate: DateTime(1900), // 1900'dan itibaren
      lastDate: DateTime.now(), // Bugüne kadar
    );

    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  // Ehliyet geçerlilik tarihi - DÜZELTİLDİ
  Future<void> _selectLicenseExpiry() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiry ?? DateTime.now().add(Duration(days: 365)), // 1 yıl sonrası
      firstDate: DateTime(2000), // 2000'den itibaren
      lastDate: DateTime(2100), // 2100'e kadar
    );

    if (picked != null) {
      setState(() => _licenseExpiry = picked);
    }
  }

  // SRC belge geçerlilik tarihi - DÜZELTİLDİ
  Future<void> _selectSrcCertificateExpiry() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _srcCertificateExpiry ?? DateTime.now().add(Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _srcCertificateExpiry = picked);
    }
  }

  // Tarih alanı widget'ı - DÜZELTİLDİ (doğum tarihi için yaş gösterimi)
  Widget _buildDateField(String label, DateTime? selectedDate, VoidCallback onTap, {bool isExpiryDate = false}) {
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
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600]),
                SizedBox(width: 12),
                Text(
                  selectedDate != null
                      ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                      : 'Tarih seçin...',
                  style: TextStyle(
                    color: selectedDate != null ? Colors.black : Colors.grey,
                  ),
                ),
                Spacer(),
                if (selectedDate != null)
                  _buildDateStatus(selectedDate, isExpiryDate),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Tarih durumu widget'ı - DÜZELTİLDİ (doğum tarihi için yaş gösterimi)
  Widget _buildDateStatus(DateTime date, bool isExpiryDate) {
    if (!isExpiryDate) {
      // Doğum tarihi için yaş gösterimi
      final age = _calculateAge(date);
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$age yaşında',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      );
    }

    // Geçerlilik tarihleri için süre kontrolü
    final now = DateTime.now();
    final isExpired = date.isBefore(now);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isExpired ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isExpired ? 'SÜRESİ DOLMUŞ' : 'GEÇERLİ',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isExpired ? Colors.red : Colors.green,
        ),
      ),
    );
  }

  // Yaş hesaplama - DÜZELTİLDİ
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _saveDriver() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        final driverData = {
          'vehicle_id': widget.vehicle['id'],
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'license_number': _licenseNumberController.text.trim(),
          'license_type': _selectedLicenseType,
          'birth_date': _birthDate?.toIso8601String(),
          'license_expiry_date': _licenseExpiry?.toIso8601String(),
          'src_certificate_expiry': _srcCertificateExpiry?.toIso8601String(),
          'photo_url': _driverPhotoUrl,
        };

        await _dbService.saveDriver(driverData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sürücü bilgileri başarıyla kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kayıt hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sürücü Bilgileri'),
        backgroundColor: Color(0xFF2196F3),
        actions: [
          if (_isSubmitting)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveDriver,
            ),
        ],
      ),
      body: _isSubmitting
          ? _buildLoading()
          : Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Sürücü Adı
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Sürücü Adı Soyadı *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Sürücü adı zorunludur';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Telefon
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              SizedBox(height: 16),

              // Doğum Tarihi - isExpiryDate: false
              _buildDateField(
                'Doğum Tarihi *',
                _birthDate,
                _selectBirthDate,
                isExpiryDate: false,
              ),
              SizedBox(height: 16),

              // Ehliyet Tipi
              DropdownButtonFormField<String>(
                value: _selectedLicenseType,
                decoration: InputDecoration(
                  labelText: 'Ehliyet Tipi *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.drive_eta),
                ),
                items: _licenseTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text('$type Sınıfı'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLicenseType = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Ehliyet tipi seçin';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Ehliyet Numarası
              TextFormField(
                controller: _licenseNumberController,
                decoration: InputDecoration(
                  labelText: 'Ehliyet Numarası',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              SizedBox(height: 16),

              // Ehliyet Geçerlilik Tarihi - isExpiryDate: true
              _buildDateField(
                'Ehliyet Geçerlilik Tarihi *',
                _licenseExpiry,
                _selectLicenseExpiry,
                isExpiryDate: true,
              ),
              SizedBox(height: 16),

              // SRC Belge Geçerlilik Tarihi - isExpiryDate: true
              _buildDateField(
                'SRC Belge Geçerlilik Tarihi *',
                _srcCertificateExpiry,
                _selectSrcCertificateExpiry,
                isExpiryDate: true,
              ),
              SizedBox(height: 24),

              // Kaydet Butonu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2196F3),
                  ),
                  child: Text(
                    'KAYDET',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
}