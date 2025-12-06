import 'package:flutter/material.dart';
import '/services/database_service.dart';
import '/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';



class AttendantEditScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final Map<String, dynamic>? attendantData;

  const AttendantEditScreen({
    Key? key,
    required this.vehicle,
    this.attendantData,
  }) : super(key: key);

  @override
  _AttendantEditScreenState createState() => _AttendantEditScreenState();
}

class _AttendantEditScreenState extends State<AttendantEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client; // EKLE

  final TextEditingController _nameController = TextEditingController();
  DateTime? _birthDate;
  bool _hasReflectiveVest = false;
  bool _hasWarningLights = false;
  bool _isSubmitting = false;


  @override
  void initState() {
    super.initState();
    _initializeForm();
    // Widget'dan gelen data yoksa database'den yükle
    if (widget.attendantData == null || widget.attendantData!.isEmpty) {
      _loadAttendantData();
    }
  }

  Future<void> _loadAttendantData() async {
    try {
      print('🔄 Rehber verisi yükleniyor: ${widget.vehicle['id']}');
      final data = await _dbService.getAttendantByVehicleId(widget.vehicle['id']);

      if (data != null && mounted) {
        print('✅ Rehber verisi bulundu: $data');
        setState(() {
          _initializeFormWithData(data);
        });
      } else {
        print('ℹ️ Rehber verisi bulunamadı, form boş başlatılıyor');
      }
    } catch (e) {
      print('❌ Rehber verisi yükleme hatası: $e');
    }
  }

  void _initializeFormWithData(Map<String, dynamic> data) {
    _nameController.text = data['full_name'] ?? '';

    if (data['birth_date'] != null) {
      try {
        _birthDate = DateTime.parse(data['birth_date']);
      } catch (e) {
        print('❌ Doğum tarihi parse hatası: ${data['birth_date']}');
      }
    }

    _hasReflectiveVest = data['has_reflective_vest'] ?? false;
    _hasWarningLights = data['has_warning_lights'] ?? false;

    print('🎛️ Form verileri yüklendi:');
    print('• Ad: ${_nameController.text}');
    print('• Doğum Tarihi: $_birthDate');
    print('• Yelek: $_hasReflectiveVest');
    print('• Işıklar: $_hasWarningLights');
  }

  void _initializeForm() {
    if (widget.attendantData != null && widget.attendantData!.isNotEmpty) {
      _initializeFormWithData(widget.attendantData!);
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _birthDate) {
      setState(() => _birthDate = picked);
    }
  }

  String? _calculateAge() {
    if (_birthDate == null) return null;

    final now = DateTime.now();
    int age = now.year - _birthDate!.year;

    if (now.month < _birthDate!.month ||
        (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
      age--;
    }

    return '$age yaşında';
  }

  // attendant_edit_screen.dart - Doğrudan kontrol

  Future<void> _saveAttendant() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        final attendantData = {
          'vehicle_id': widget.vehicle['id'],
          'full_name': _nameController.text.trim(),
          'birth_date': _birthDate?.toIso8601String(),
          'has_reflective_vest': _hasReflectiveVest,
          'has_warning_lights': _hasWarningLights,
        };

        print('💾 Rehber kaydediliyor: $attendantData');

        // KAYDET
        await _dbService.saveAttendant(attendantData);

        // DEBUG: HEMEN DOĞRUDAN KONTROL ET
        final directCheck = await _supabase
            .from('vehicles')
            .select('attendant_name, attendant_birth_date, has_reflective_vest, has_warning_lights')
            .eq('id', widget.vehicle['id'])
            .single();

        print('✅ DOĞRUDAN KONTROL (VEHICLES TABLOSU):');
        print('• attendant_name: ${directCheck['attendant_name']}');
        print('• attendant_birth_date: ${directCheck['attendant_birth_date']}');
        print('• has_reflective_vest: ${directCheck['has_reflective_vest']}');
        print('• has_warning_lights: ${directCheck['has_warning_lights']}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rehber bilgileri başarıyla kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);

      } catch (e) {
        print('❌ Rehber kaydetme hatası: $e');
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
        title: Text('Rehber Personel Bilgileri'),
        backgroundColor: Color(0xFF4CAF50),
        actions: [
          if (_isSubmitting)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveAttendant,
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
              // Rehber Adı
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Rehber Adı Soyadı *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.accessible),
                  hintText: 'Rehber personelin adı soyadı',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Rehber adı zorunludur';
                  }
                  if (value.length < 2) {
                    return 'Geçerli bir ad girin';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              // Doğum Tarihi
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doğum Tarihi *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: _selectBirthDate,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: _birthDate != null ? Color(0xFF4CAF50) : Colors.grey[600]),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _birthDate != null
                                  ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                                  : 'Doğum tarihi seçin...',
                              style: TextStyle(
                                color: _birthDate != null ? Colors.black : Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (_birthDate != null) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Color(0xFF4CAF50).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _calculateAge()!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_birthDate != null) ...[
                    SizedBox(height: 8),
                    Text(
                      'Yaş kontrolü: 22-61 yaş aralığında olmalıdır',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 20),

              // Ekipmanlar
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zorunlu Ekipmanlar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Rehber personelin taşıması gereken ekipmanlar',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Reflektif Yelek
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'Reflektif Yelek',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'TS EN ISO 20471 standartlarına uygun sarı renkli yelek',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _hasReflectiveVest,
                          onChanged: (value) {
                            setState(() => _hasReflectiveVest = value);
                          },
                          secondary: Icon(
                            Icons.security,
                            color: _hasReflectiveVest ? Color(0xFF4CAF50) : Colors.grey,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),

                      // Yardımcı Işıklar
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'Yardımcı Işıklar',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Işıklı çubuk, dur-geç levhası vb. uyarı ekipmanları',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _hasWarningLights,
                          onChanged: (value) {
                            setState(() => _hasWarningLights = value);
                          },
                          secondary: Icon(
                            Icons.flash_on,
                            color: _hasWarningLights ? Color(0xFF4CAF50) : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Kaydet Butonu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveAttendant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4CAF50),
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
                    'REHBER BİLGİLERİNİ KAYDET',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Bilgi Notu
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rehber personel öğrencilerin güvenli iniş-binişinden sorumludur',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
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
          CircularProgressIndicator(color: Color(0xFF4CAF50)),
          SizedBox(height: 16),
          Text(
            'Rehber bilgileri kaydediliyor...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

}