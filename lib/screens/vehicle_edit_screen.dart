//vehicle_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/database_service.dart';
import '/utils/constants.dart';
import '/screens/driver_edit_screen.dart';
import '/screens/attendant_edit_screen.dart';
import '/screens/documents_edit_screen.dart';

class VehicleEditScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final Map<String, dynamic>? driverData;
  final Map<String, dynamic>? attendantData;
  final Map<String, dynamic>? documentsData;

  const VehicleEditScreen({
    Key? key,
    required this.vehicle,
    this.driverData,
    this.attendantData,
    this.documentsData,
  }) : super(key: key);


  @override
  _VehicleEditScreenState createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends State<VehicleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client; // EKLE

  // Sadece araç bilgileri için controller'lar
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _modelYearController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  String? _selectedTransportType;
  DateTime? _selectedLastMaintenanceDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadVehicleCompleteData(); // YENİ METOD
  }

// Tam araç verisini yükle
  Future<void> _loadVehicleCompleteData() async {
    try {
      final completeData = await _dbService.getVehicleCompleteData(widget.vehicle['id']);

      setState(() {
        // Burada state değişkenlerinizi güncelleyin
        // Örneğin: _driverData, _attendantData, _documentsData
      });

    } catch (e) {
      print('Tam araç verisi yükleme hatası: $e');
    }
  }

// Sürücü düzenleme ekranına geçiş
  void _openDriverEdit() async {
    try {
      // Önce güncel verileri yükle
      final driverData = await _dbService.getDriverByVehicleId(widget.vehicle['id']);

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverEditScreen(
            vehicle: widget.vehicle,
            driverData: driverData ?? {}, // Null kontrolü
          ),
        ),
      );

      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sürücü bilgileri güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
        // Verileri yeniden yükle
        _loadVehicleCompleteData();
      }
    } catch (e) {
      print('Sürücü düzenleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sürücü bilgileri yüklenirken hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
// İlgili verileri yükle
  Future<void> _loadRelatedData() async {
    try {
      final completeData = await _dbService.getVehicleCompleteData(widget.vehicle['id']);

      setState(() {
        // Burada driverData, attendantData, documentsData state değişkenleri olmalı
        // Veya doğrudan ilgili edit screen'lere geçmeli
      });

    } catch (e) {
      print('İlgili veriler yüklenirken hata: $e');
    }
  }


// Rehber düzenleme ekranına geçiş - DÜZELTTİ
  // vehicle_edit_screen.dart - Doğrudan veri yükleme

  void _openAttendantEdit() async {
    try {
      print('🔄 Rehber verisi doğrudan yükleniyor: ${widget.vehicle['id']}');

      // DOĞRUDAN VEHICLES TABLOSUNDAN AL
      final directData = await _supabase
          .from('vehicles')
          .select('attendant_name, attendant_birth_date, has_reflective_vest, has_warning_lights')
          .eq('id', widget.vehicle['id'])
          .single();

      // MANUEL MAPPING
      final attendantData = {
        'full_name': directData['attendant_name'],
        'birth_date': directData['attendant_birth_date'],
        'has_reflective_vest': directData['has_reflective_vest'] ?? false,
        'has_warning_lights': directData['has_warning_lights'] ?? false,
      };

      print('🔍 DOĞRUDAN REHBER VERİSİ: $attendantData');

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AttendantEditScreen(
            vehicle: widget.vehicle,
            attendantData: attendantData,
          ),
        ),
      );

      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rehber bilgileri güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Rehber düzenleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rehber bilgileri yüklenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  void _openDocumentsEdit() async {
    final documentsData = await _dbService.getDocumentsByVehicleId(widget.vehicle['id']);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentsEditScreen(
          vehicle: widget.vehicle,
          documentsData: documentsData,
        ),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Belge bilgileri güncellendi'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _validateInitialValues() {
    // Taşıma türü geçerli değilse varsayılan değer ata
    if (_selectedTransportType != 'private' && _selectedTransportType != 'public') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedTransportType = 'private'; // Varsayılan değer
        });
      });
    }
  }

  void _initializeForm() {
    final vehicle = widget.vehicle;

    _plateController.text = vehicle['plate'] ?? '';
    _modelController.text = vehicle['model'] ?? '';
    _modelYearController.text = vehicle['model_year']?.toString() ?? '';
    _capacityController.text = vehicle['capacity']?.toString() ?? '';
    _selectedTransportType = vehicle['transport_type'] ?? 'private';

    // Bakım tarihi
    if (vehicle['last_maintenance_date'] != null) {
      try {
        _selectedLastMaintenanceDate = DateTime.parse(vehicle['last_maintenance_date']);
      } catch (e) {
        print('Bakım tarihi parse hatası: $e');
      }
    }
  }

  Widget _buildModelYearField() {
    return TextFormField(
      controller: _modelYearController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Model Yılı *',
        border: OutlineInputBorder(),
        hintText: '2023',
        prefixIcon: Icon(Icons.calendar_today),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Model yılı zorunludur';
        }
        final year = int.tryParse(value);
        if (year == null || year < 1990 || year > DateTime.now().year + 1) {
          return 'Geçerli bir model yılı girin (1990-${DateTime.now().year + 1})';
        }
        return null;
      },
    );
  }

  Widget _buildMaintenanceDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son Bakım Tarihi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: _selectMaintenanceDate,
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
                  _selectedLastMaintenanceDate != null
                      ? '${_selectedLastMaintenanceDate!.day}/${_selectedLastMaintenanceDate!.month}/${_selectedLastMaintenanceDate!.year}'
                      : 'Tarih seçin...',
                  style: TextStyle(
                    color: _selectedLastMaintenanceDate != null ? Colors.black : Colors.grey,
                  ),
                ),
                Spacer(),
                if (_selectedLastMaintenanceDate != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Kayıtlı',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectMaintenanceDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedLastMaintenanceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedLastMaintenanceDate) {
      setState(() {
        _selectedLastMaintenanceDate = picked;
      });
    }
  }

  Future<void> _saveVehicle() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final vehicleData = {
          'plate': _plateController.text.trim().toUpperCase(),
          'model': _modelController.text.trim(),
          'model_year': int.parse(_modelYearController.text),
          'capacity': int.parse(_capacityController.text),
          'transport_type': _selectedTransportType ?? 'private',
          'last_maintenance_date': _selectedLastMaintenanceDate?.toIso8601String(),
        };

        await _dbService.updateVehicle(widget.vehicle['id'], vehicleData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Araç başarıyla güncellendi'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } catch (e) {
        print('Araç kaydetme hatası: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Araç kaydedilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }



  Widget _buildManagementCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Araç Yönetimi'),
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
              onPressed: _saveVehicle,
              tooltip: 'Araç Bilgilerini Kaydet',
            ),
        ],
      ),
      body: _isSubmitting
          ? _buildLoading()
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Araç Bilgileri Kartı
            Card(
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_bus, color: Color(0xFF2196F3)),
                        SizedBox(width: 8),
                        Text(
                          'Araç Bilgileri',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Plaka
                          TextFormField(
                            controller: _plateController,
                            decoration: InputDecoration(
                              labelText: 'Plaka *',
                              border: OutlineInputBorder(),
                              hintText: '34 ABC 123',
                              prefixIcon: Icon(Icons.confirmation_number),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Plaka zorunludur';
                              }
                              if (value.length < 5) {
                                return 'Geçerli bir plaka girin';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // Model
                          TextFormField(
                            controller: _modelController,
                            decoration: InputDecoration(
                              labelText: 'Araç Modeli *',
                              border: OutlineInputBorder(),
                              hintText: 'Mercedes Sprinter',
                              prefixIcon: Icon(Icons.directions_bus),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Model zorunludur';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // Model Yılı
                          _buildModelYearField(),
                          SizedBox(height: 16),

                          // Kapasite
                          TextFormField(
                            controller: _capacityController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Öğrenci Kapasitesi *',
                              border: OutlineInputBorder(),
                              hintText: '20',
                              prefixIcon: Icon(Icons.people),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Kapasite zorunludur';
                              }
                              final capacity = int.tryParse(value);
                              if (capacity == null || capacity <= 0) {
                                return 'Geçerli bir kapasite girin';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // Taşıma Türü
                          DropdownButtonFormField<String>(
                            value: _selectedTransportType,
                            decoration: InputDecoration(
                              labelText: 'Taşıma Türü *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.transfer_within_a_station),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: 'private', // BU DEĞER _selectedTransportType ile AYNI OLMALI
                                child: Text('Özel Taşıma'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'public', // BU DEĞER _selectedTransportType ile AYNI OLMALI
                                child: Text('Devlet Taşıması'),
                              ),
                            ],
                            onChanged: (String? newValue) { // String? tipini belirtin
                              setState(() {
                                _selectedTransportType = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Taşıma türü seçin';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // Bakım Tarihi
                          _buildMaintenanceDateField(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Yönetim Kartları
            Text(
              'Diğer Bilgiler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Aşağıdaki bölümlerden ilgili bilgileri düzenleyebilirsiniz',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),

            // Sürücü Bilgileri Kartı
            _buildManagementCard(
              'Sürücü Bilgileri',
              'Ehliyet, SRC belgesi, kişisel bilgiler',
              Icons.person,
              Color(0xFF2196F3),
              _openDriverEdit,
            ),
            SizedBox(height: 12),

            // Rehber Bilgileri Kartı
            if (_selectedTransportType == 'private')
              _buildManagementCard(
                'Rehber Personel Bilgileri',
                'Rehber personel bilgileri ve ekipmanlar',
                Icons.accessible,
                Color(0xFF4CAF50),
                _openAttendantEdit,
              ),
            if (_selectedTransportType == 'private') SizedBox(height: 12),

            // Belge Bilgileri Kartı
            _buildManagementCard(
              'Araç Belgeleri',
              'Sigorta, muayene, yangın tüpü ve diğer belgeler',
              Icons.description,
              Color(0xFFFF9800),
              _openDocumentsEdit,
            ),

            SizedBox(height: 24),

            // Ana Kaydet Butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveVehicle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2196F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  'ARAÇ BİLGİLERİNİ KAYDET',
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