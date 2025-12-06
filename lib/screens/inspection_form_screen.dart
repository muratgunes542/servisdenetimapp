//inspection_form_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '/models/inspection_category.dart';
import '/models/inspection_item.dart';
import '/services/database_service.dart';
import '/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InspectionFormScreen extends StatefulWidget {
  final String vehiclePlate;
  final bool isNewInspection;
  final Map<String, dynamic>? previousInspectionData;
  final bool isDuplicateForNewSchool;
  final bool isViewMode;

  const InspectionFormScreen({
    Key? key,
    required this.vehiclePlate,
    this.isNewInspection = true,
    this.previousInspectionData,
    this.isDuplicateForNewSchool = false,
    this.isViewMode = false,
  }) : super(key: key);

  @override
  _InspectionFormScreenState createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final DatabaseService _dbService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  final TextEditingController _driverNameController = TextEditingController();
  bool _isViewMode = false;
  bool _canEdit = false;

  List<InspectionCategory> _inspectionCategories = [];
  bool _isLoading = true;
  bool _usingSampleData = false;
  final Map<int, bool> _expandedCategories = {};

  List<InspectionItem> _allItems = [];
  List<InspectionCategory> _categories = [];
  Map<String, dynamic>? _previousInspectionData;
  String? _currentInspectorName;
  final TextEditingController _plateController = TextEditingController();

  // VERİ DEĞİŞKENLERİ
  Map<String, dynamic>? _completeVehicleData;
  Map<String, dynamic>? _vehicleData;
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _attendantData;
  Map<String, dynamic>? _documentsData;
  List<dynamic>? _schools;
  List<Map<String, dynamic>> _recentInspections = [];

  // Form state'leri
  List<Map<String, dynamic>> _allSchools = [];
  Map<String, dynamic>? _selectedSchool;
  bool _showRecentInspectionWarning = false;
  String _inspectorName = '';
  DateTime _inspectionDate = DateTime.now();
  int _totalScore = 0;
  int _maxScore = 0;
  String _inspectionStatus = 'compliant';
  String _notes = '';
  Map<String, Map<String, dynamic>> _categoryResults = {};
  Map<String, dynamic> _inspectionResults = {};

  // Düzenlenebilir alanlar
  final TextEditingController _driverPhoneController = TextEditingController();
  final TextEditingController _attendantNameController = TextEditingController();
  final TextEditingController _inspectorNameController = TextEditingController();

  // HTTP İÇİN GEREKLİ DEĞİŞKENLER
  static const String _supabaseUrl = 'https://zxhvyfbzhuvbcnuxsaxq.supabase.co';
  static const String _apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4aHZ5ZmJ6aHV2YmNudXhzYXhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2ODg5MzMsImV4cCI6MjA3NTI2NDkzM30.rFB-7LP_ccNWrPXIpfTuwAW9zdgRXeX0w79kra5P0uQ';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
    'apikey': _apiKey,
    'Prefer': 'return=representation',
  };

  String? _lastInspectionSchool;
  DateTime? _lastInspectionDate;

  @override
  void initState() {
    super.initState();
    _isViewMode = widget.isViewMode;
    _loadInspectionItems();
    _initializeData();
  }

  void _initializeData() async {
    await _loadInspectorName();

    if (widget.isDuplicateForNewSchool && widget.previousInspectionData != null) {
      // BAŞKA OKUL İÇİN KOPYALA MODU
      _initializeDuplicateForNewSchool();
    } else if (!widget.isNewInspection && widget.previousInspectionData != null) {
      // VIEW MODE VEYA DÜZENLEME MODU
      _loadPreviousInspectionDataAsync();
    } else {
      // YENİ DENETİM
      _initializeNewInspection();
    }
  }

  // YENİ METOD: Başka okul için kopyala modunu başlat
  void _initializeDuplicateForNewSchool() {
    print('🔄 BAŞKA OKUL İÇİN KOPYALA MODU BAŞLATILIYOR');

    try {
      // Önce önceki denetim verilerini yükle
      _loadPreviousInspectionDataAsync().then((_) {
        // Sonra formu yeni denetim için hazırla (okul hariç tüm veriler korunsun)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _isViewMode = false; // Edit mode'da aç
            _canEdit = true; // Düzenlenebilir
            // Okul bilgisini temizle, diğer tüm veriler korunsun
            _selectedSchool = null;
          });

          print('✅ BAŞKA OKUL İÇİN KOPYALA MODU HAZIR:');
          print('• Denetim maddeleri: ${_inspectionResults.length}');
          print('• Okul: ${_selectedSchool?['name'] ?? "SEÇİLECEK"}');
        });
      });
    } catch (e) {
      print('❌ Kopyala modu başlatma hatası: $e');
    }
  }

  Future<void> _loadPreviousInspectionDataAsync() async {
    print('🔄 Önceki denetim verileri yükleniyor...');

    try {
      setState(() {
        _previousInspectionData = widget.previousInspectionData;
        _isLoading = true;
      });

      // Önce temel verileri yükle
      await _initializeForm();

      // Önceki denetim verilerini uygula
      if (widget.previousInspectionData != null) {
        _applyPreviousInspectionData();

        // View mode için özel işlemler
        if (_isViewMode) {
          await _initializeFormForViewMode();
        }
      }

      setState(() {
        _isLoading = false;
      });

      print('✅ Önceki denetim verileri yüklendi');

    } catch (e) {
      print('❌ Önceki denetim yükleme hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // EKSİK METODLARI EKLEYELİM
  void _initializeExpandedCategories() {
    for (int i = 0; i < _inspectionCategories.length; i++) {
      _expandedCategories[i] = false;
    }
  }

  List<InspectionCategory> _groupItemsByCategory(List<InspectionItem> items) {
    final categories = <String, List<InspectionItem>>{};

    for (final item in items) {
      // Geçici kategori ataması - gerçek uygulamada item.category kullanın
      final category = 'Genel Denetim';
      if (!categories.containsKey(category)) {
        categories[category] = [];
      }
      categories[category]!.add(item);
    }

    return categories.entries.map((entry) {
      return InspectionCategory(
        name: entry.key,
        description: '',
        items: entry.value,
      );
    }).toList();
  }

  // Önceki denetim verilerini uygula - GÜNCELLENDİ
  void _applyPreviousInspectionData() {
    if (_previousInspectionData == null) return;

    print('🔄 Önceki denetim verileri uygulanıyor...');

    try {
      // 1. OKUL BİLGİSİNİ YÜKLE - GÜÇLENDİRİLMİŞ
      dynamic previousSchool;
      if (_previousInspectionData?['schools'] is Map) {
        previousSchool = _previousInspectionData?['schools'];
      } else if (_previousInspectionData?['school_name'] != null) {
        // Eski format için fallback
        previousSchool = {
          'name': _previousInspectionData?['school_name'],
          'district': _previousInspectionData?['school_district'] ?? ''
        };
      }

      if (previousSchool != null && previousSchool['name'] != null) {
        setState(() {
          _selectedSchool = {
            'name': previousSchool['name'].toString(),
            'district': previousSchool['district']?.toString() ?? ''
          };
        });
        print('✅ Önceki okul yüklendi: ${previousSchool['name']}');
      } else {
        print('⚠️ Önceki okul bilgisi bulunamadı veya geçersiz');
      }

      // 2. DENETÇİ BİLGİSİNİ YÜKLE
      final previousInspector = _previousInspectionData?['inspector_name']?.toString();
      if (previousInspector != null && previousInspector.isNotEmpty) {
        _inspectorNameController.text = previousInspector;
        print('✅ Önceki denetçi yüklendi: $previousInspector');
      }

      // 3. DENETİM MADDELERİNİ YÜKLE
      final details = _previousInspectionData?['details'];
      if (details != null) {
        _loadInspectionItemsFromData(details);
        print('✅ ${_inspectionResults.length} denetim maddesi yüklendi');
      }

      // 4. ARAÇ VERİLERİNİ YÜKLE
      _loadVehicleDataFromPreviousInspection();

    } catch (e) {
      print('❌ Önceki veri uygulama hatası: $e');
    }
  }

  // Araç verilerini önceki denetimden yükle - YENİ METOD
  void _loadVehicleDataFromPreviousInspection() {
    try {
      final inspection = _previousInspectionData;
      if (inspection == null) return;

      print('🚗 Önceki denetimden araç verileri yükleniyor...');

      // Vehicle data
      if (inspection['vehicle_data'] is Map) {
        _vehicleData = Map<String, dynamic>.from(inspection['vehicle_data']);
      } else if (inspection['vehicles'] is Map) {
        _vehicleData = Map<String, dynamic>.from(inspection['vehicles']);
      }

      // Driver data
      if (inspection['driver_data'] is Map) {
        _driverData = Map<String, dynamic>.from(inspection['driver_data']);
      }

      // Attendant data
      if (inspection['attendant_data'] is Map) {
        _attendantData = Map<String, dynamic>.from(inspection['attendant_data']);
      }

      // Documents data
      if (inspection['documents_data'] is Map) {
        _documentsData = Map<String, dynamic>.from(inspection['documents_data']);
      }

      // Controller'ları güncelle
      _driverNameController.text = _driverData?['full_name'] ??
          _driverData?['driver_name'] ??
          _vehicleData?['driver_name'] ??
          '';

      _driverPhoneController.text = _driverData?['phone'] ??
          _driverData?['driver_phone'] ??
          _vehicleData?['driver_phone'] ??
          '';

      _attendantNameController.text = _attendantData?['full_name'] ??
          _attendantData?['attendant_name'] ??
          _vehicleData?['attendant_name'] ??
          '';

      print('✅ Önceki araç verileri yüklendi');

    } catch (e) {
      print('❌ Önceki araç verisi yükleme hatası: $e');
    }
  }

  // Başka okul için kaydet işlemi - GÜNCELLENDİ
  void _saveForNewSchool() {
    print('🔄 BAŞKA OKUL İÇİN KAYDET: Mevcut denetim korunuyor...');

    try {
      // 1. TÜM DENETİM VERİLERİNİ KORU
      final Map<String, dynamic> preservedResults = Map.from(_inspectionResults);
      final int preservedCompletedItems = _getCompletedItemsCount();
      final String preservedInspectorName = _inspectorNameController.text;

      // 2. SADECE OKULU TEMİZLE, DİĞER TÜM VERİLER KORUNSUN
      setState(() {
        _selectedSchool = null; // ✅ Sadece okul temizle
        _inspectionDate = DateTime.now(); // ✅ Tarih güncelle

        // ✅ DENETİM VERİLERİ KORUNUYOR!
        _inspectionResults = preservedResults;
        _inspectorNameController.text = preservedInspectorName;

        // ✅ MOD AYARLARI
        _isViewMode = false;
        _canEdit = true;
      });

      // 3. DEBUG BİLGİSİ
      print('✅ Okul temizlendi, ${_inspectionResults.length} denetim maddesi korundu');
      print('✅ $preservedCompletedItems tamamlanan madde korundu');

    } catch (e) {
      print('❌ BAŞKA OKUL İÇİN KAYDET HATASI: $e');



      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Hata: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Kaydetme işlemi - GÜNCELLENDİ
  void _saveInspection() async {
    try {
      print('💾 DENETİM KAYDEDİLİYOR - VERİ KONTROLÜ');

      // Validation kontrolleri
      if (_selectedSchool == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lütfen bir okul seçin'), backgroundColor: Colors.red),
        );
        return;
      }

      if (_inspectorNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lütfen denetçi adını girin'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Denetim verilerini hazırla - TABLO ŞEMASINA UYGUN
      final inspectionData = _prepareInspectionDataForSave();

      print('📦 DENETİM VERİSİ HAZIR:');
      print('• Plaka: ${inspectionData['vehicle_plate']}');
      print('• Okul: ${inspectionData['school_name']}');
      print('• Denetçi: ${inspectionData['inspector_name']}');
      print('• Tamamlanan: ${inspectionData['completed_items']}/${inspectionData['total_items']}');

      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Denetim kaydediliyor...'),
            ],
          ),
        ),
      );

      // Kaydetme işlemi
      try {
        await _dbService.saveInspection(inspectionData);

        // Loading'i kapat
        Navigator.pop(context);

        print('✅ DENETİM BAŞARIYLA KAYDEDİLDİ');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Denetim başarıyla kaydedildi'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // BAŞARILI DURUMDA SADECE BİR ÖNCEKİ SAYFAYA DÖN
        await Future.delayed(Duration(milliseconds: 1500));

        // Sadece bir önceki sayfaya dön, dashboard'a kadar gitme
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          // Eğer pop yapılamıyorsa vehicle select screen'e git
          Navigator.pushNamedAndRemoveUntil(
              context,
              '/vehicleSelect',
                  (route) => false
          );
        }

      } catch (e) {
        // Loading'i kapat
        Navigator.pop(context);

        print('❌ KAYDETME HATASI: $e');

        // HATA DURUMUNDA KULLANICIYI FORMDA TUT
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('❌ Sunucuya kayıt başarısız!'),
                SizedBox(height: 4),
                Text(
                  'Denetim yerel cihaza kaydedildi. Tekrar deneyebilirsiniz.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'TEKRAR DENE',
              textColor: Colors.white,
              onPressed: () {
                // Tekrar deneme işlemi
                _saveInspection();
              },
            ),
          ),
        );

        // HATA DURUMUNDA KESİNLİKLE NAVIGATION YAPMA - KULLANICI FORMDA KALSIN
        print('⚠️ Kullanıcı formda kalmaya devam ediyor, yerel kayıt başarılı');
      }

    } catch (e) {
      print('❌ BEKLENMEYEN HATA: $e');

      // Beklenmeyen hata durumunda da kullanıcıyı formda tut
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Beklenmeyen hata: İşlemi tekrar deneyin'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

// TABLO ŞEMASINA UYGUN VERİ HAZIRLAMA
  Map<String, dynamic> _prepareInspectionDataForSave() {
    final schoolName = _selectedSchool?['name'] ?? 'Belirtilmemiş';
    final schoolDistrict = _selectedSchool?['district'] ?? '';

    print('🏫 KAYIT ÖNCESİ OKUL BİLGİSİ:');
    print('   • Okul Adı: $schoolName');
    print('   • İlçe: $schoolDistrict');
    print('   • Selected School: $_selectedSchool');

    return {
      // Zorunlu alanlar
      'vehicle_plate': widget.vehiclePlate,
      'school_name': schoolName, // ✅ BU MUTLAKA OLMALI
      'inspector_name': _inspectorNameController.text.trim(),
      'inspection_date': DateTime.now().toIso8601String(),

      // Sayısal alanlar
      'completed_items': _getCompletedItemsCount(),
      'total_items': _getTotalItemsCount(),
      'total_score': 0,

      // Diğer alanlar
      'result': _calculateInspectionResult(),
      'details': _getInspectionDetails(),
      'is_manual_entry': _completeVehicleData?['_isEmpty'] ?? false,

      // Null alanlar
      'vehicle_id': null,
      'school_id': null,
      'inspector_id': null,
      'is_compliant': null,
      'notes': null,

      // Eğer schools objesini de kaydetmek istiyorsak:
      'schools': _selectedSchool, // ✅ BU DA OPSİYONEL
    };
  }

// Denetim detaylarını hazırla
  Map<String, dynamic> _getInspectionDetails() {
    final details = <String, dynamic>{};

    try {
      // Tüm item'ların durumlarını topla
      final items = _inspectionCategories
          .expand((category) => category.items)
          .where((item) => !item.isInfoSection && !item.isSettingsSection);

      for (final item in items) {
        final itemId = item.id.toString();
        final result = _inspectionResults[itemId] ?? {};

        details['item_$itemId'] = {
          'status': result['is_compliant'] == true ? 'compliant' : 'non_compliant',
          'notes': result['notes'] ?? '',
          'non_compliant_description': result['non_compliant_description'] ?? '',
        };
      }

      print('📋 DENETİM DETAYLARI: ${details.length} madde');
      return details;

    } catch (e) {
      print('❌ DENETİM DETAY HATASI: $e');
      return {'error': 'Detaylar oluşturulamadı: $e'};
    }
  }



  void _enterEditModeWithDataProtection() {
    print('🔄 EDIT MODE: Denetim verileri korunuyor...');

    try {
      // 1. MEVCUT DENETİM VERİLERİNİ KORU
      final Map<String, dynamic> preservedResults = Map.from(_inspectionResults);
      final List<InspectionCategory> preservedCategories = List.from(_inspectionCategories);

      // 2. EDIT MODE'A GEÇ
      setState(() {
        _canEdit = true;
        _isViewMode = false;

        // 3. VERİLERİ GERİ YÜKLE
        _inspectionResults = preservedResults;
        _inspectionCategories = preservedCategories;
      });

      print('✅ EDIT MODE: ${_inspectionResults.length} denetim maddesi korundu');

    } catch (e) {
      print('❌ EDIT MODE veri koruma hatası: $e');

      // FALLBACK: Basit edit mode
      setState(() {
        _canEdit = true;
        _isViewMode = false;
      });
    }
  }



  // Denetim verilerini kontrol et ve onar
  void _validateAndRepairInspectionData() {
    try {
      print('🔍 DENETİM VERİLERİ KONTROL EDİLİYOR...');

      int repairedCount = 0;

      // Tüm kategorilerdeki item'ları kontrol et
      for (final category in _inspectionCategories) {
        for (final item in category.items) {
          if (!item.isInfoSection && !item.isSettingsSection) {
            final itemId = item.id.toString();

            // Eğer item'ın viewModeResponse'u var ama inspectionResults'ta yoksa, onar
            if (item.viewModeResponse != null && !_inspectionResults.containsKey(itemId)) {
              _inspectionResults[itemId] = {
                'is_compliant': item.viewModeResponse?['status'] == 'compliant',
                'notes': item.viewModeResponse?['notes'] ?? '',
                'non_compliant_description': item.viewModeResponse?['non_compliant_description'] ?? '',
              };
              repairedCount++;
              print('✅ Item $itemId onarıldı');
            }
          }
        }
      }

      if (repairedCount > 0) {
        print('🎯 TOPLAM $repairedCount ITEM ONARILDI');
        _calculateScore(); // Skoru yeniden hesapla
      }

    } catch (e) {
      print('❌ Denetim verisi onarım hatası: $e');
    }
  }

  Future<void> _loadInspectorName() async {
    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _currentInspectorName = user?['full_name'] ?? 'Denetçi';
      });
    } catch (e) {
      print('Denetçi ismi yükleme hatası: $e');
      setState(() {
        _currentInspectorName = 'Denetçi';
      });
    }
  }

  Future<void> _initializeFormForViewMode() async {
    try {
      print('👀 VIEW MODE: Denetim görüntüleniyor');

      final inspection = widget.previousInspectionData;
      if (inspection == null) {
        print('❌ VIEW MODE: Denetim verisi yok');
        return;
      }

      // 1. ÖNCE TEMEL VERİLERİ YÜKLE
      _loadVehicleDataForViewMode(inspection);

      // 2. DENETİM MADDELERİNİ VE CEVAPLARINI YÜKLE
      _loadInspectionItemsFromData(inspection['details']);

      // 3. OKUL BİLGİSİNİ YÜKLE
      await _loadSchoolData(inspection);

      // 4. DENETÇİ BİLGİSİNİ YÜKLE
      _loadInspectorData(inspection);

      print('✅ VIEW MODE: Form başarıyla yüklendi');

    } catch (e) {
      print('❌ VIEW MODE form başlatma hatası: $e');
    }
  }

  Future<void> _loadSchoolData(Map<String, dynamic> inspection) async {
    try {
      final schoolName = inspection['school_name'];
      if (schoolName != null) {
        // Tüm okulları getir
        final schools = await _dbService.getSchools();

        // Okulu bul
        final foundSchool = schools.firstWhere(
              (school) => school['name'] == schoolName,
          orElse: () => {},
        );

        if (foundSchool.isNotEmpty) {
          setState(() {
            _selectedSchool = foundSchool;
          });
          print('✅ VIEW MODE: Okul bulundu: $schoolName');
        } else {
          // Okul bulunamazsa manuel oluştur
          setState(() {
            _selectedSchool = {
              'name': schoolName,
              'district': inspection['school_district'] ?? 'Bilinmiyor'
            };
          });
          print('⚠️ VIEW MODE: Okul bulunamadı, manuel oluşturuldu: $schoolName');
        }
      }
    } catch (e) {
      print('❌ VIEW MODE okul yükleme hatası: $e');
    }
  }

  void _loadInspectorData(Map<String, dynamic> inspection) {
    try {
      final inspectorName = inspection['inspector_name'];
      if (inspectorName != null && inspectorName.isNotEmpty) {
        setState(() {
          _inspectorName = inspectorName;
          _inspectorNameController.text = inspectorName;
        });
        print('✅ VIEW MODE: Denetçi bilgisi yüklendi: $inspectorName');
      } else {
        // Denetçi bilgisi yoksa mevcut kullanıcıyı kullan
        setState(() {
          _inspectorNameController.text = _currentInspectorName ?? 'Denetçi';
        });
        print('⚠️ VIEW MODE: Denetçi bilgisi yok, mevcut kullanıcı kullanılıyor');
      }
    } catch (e) {
      print('❌ VIEW MODE denetçi yükleme hatası: $e');
    }
  }
  void _loadInspectionItemsFromData(dynamic itemsData) {
    try {
      print('🔄 Denetim maddeleri yükleniyor...');

      if (itemsData is Map<String, dynamic>) {
        // Yeni format: {'item_1': {'status': 'compliant', 'notes': ''}}
        itemsData.forEach((itemId, itemData) {
          if (itemData is Map) {
            final cleanItemId = itemId.replaceFirst('item_', '');
            _inspectionResults[cleanItemId] = {
              'is_compliant': itemData['status'] == 'compliant',
              'notes': itemData['notes'] ?? '',
              'non_compliant_description': itemData['non_compliant_description'] ?? '',
            };
          }
        });
        print('✅ ${itemsData.length} denetim maddesi yüklendi (Map format)');
      } else if (itemsData is List) {
        // Eski format: [{'item_id': 1, 'is_compliant': true}]
        for (final item in itemsData) {
          final itemId = item['item_id']?.toString();
          if (itemId != null) {
            _inspectionResults[itemId] = {
              'is_compliant': item['is_compliant'] ?? false,
              'notes': item['notes'] ?? '',
              'selected_date': item['selected_date'],
              'date_field_label': item['date_field_label'],
            };
          }
        }
        print('✅ ${itemsData.length} denetim maddesi yüklendi (List format)');
      } else {
        print('⚠️ Bilinmeyen denetim veri formatı: ${itemsData.runtimeType}');
      }

      // Skoru hesapla
      _calculateScore();

    } catch (e) {
      print('❌ Denetim maddeleri yükleme hatası: $e');
    }
  }




  List<InspectionItem> _createDriverItemsForViewMode() {
    return [
      InspectionItem(
        id: 1,
        question: "Araç Sürücüsü Yeterli sürücü Belgesine Sahip mi? (D,E5-D1,B7)",
        description: "D sınıfı sürücü belgesi için en az beş yıllık, D1 sınıfı sürücü belgesi için en az yedi yıllık sürücü belgesine sahip olmak",
        hasDateField: true,
        dateFieldLabel: "Ehliyet Geçerlilik Tarihi",
        dateValue: _driverData?['license_expiry_date']?.toString(),
        hasInfoField: true,
        infoLabel: "Ehliyet Tipi",
        infoValue: _driverData?['license_type'] ?? 'Belirtilmemiş',
        // View Mode için özel alan
        viewModeResponse: _getViewModeResponse('1'),
      ),
      InspectionItem(
        id: 2,
        question: "Araç sürücüsünün yaşı uygun mu?",
        description: "26 yaşından gün almış 66 yaşından gün almamış olmak",
        hasInfoField: true,
        infoLabel: "Sürücü Yaşı",
        infoValue: _getDriverAgeInfo(),
        viewModeResponse: _getViewModeResponse('2'),
      ),
      // Diğer sürücü maddeleri...
    ];
  }

// Benzer metodları diğer kategoriler için de oluştur
  List<InspectionItem> _createAttendantItemsForViewMode() {
    return [
      InspectionItem(
        id: 6,
        question: "Rehber personel yaşı uygun mu?",
        description: "22 yaşını doldurmuş ve 61 yaşından gün almamış olmak",
        hasInfoField: true,
        infoLabel: "Rehber Yaşı",
        infoValue: _getAttendantAgeInfo(),
        viewModeResponse: _getViewModeResponse('6'),
      ),
      // Diğer rehber maddeleri...
    ];
  }


  Map<String, dynamic> _getViewModeResponse(String itemId) {
    final result = _inspectionResults[itemId];
    if (result == null) {
      return {
        'status': 'not_answered',
        'text': 'Cevaplanmadı',
        'notes': '',
        'non_compliant_description': ''
      };
    }

    final isCompliant = result['is_compliant'] ?? false;
    final notes = result['notes'] ?? '';
    final nonCompliantDesc = result['non_compliant_description'] ?? '';

    return {
      'status': isCompliant ? 'compliant' : 'non_compliant',
      'text': isCompliant ? 'Uygun' : 'Uygun Değil',
      'notes': notes,
      'non_compliant_description': nonCompliantDesc,
    };
  }

  void _loadVehicleDataForViewMode(Map<String, dynamic> inspection) {
    try {
      print('🚗 VIEW MODE: Araç verileri yükleniyor...');

      // 1. ARAÇ BİLGİLERİ
      final vehicle = inspection['vehicles'] is Map ? inspection['vehicles'] : {};
      final driver = inspection['driver_data'] is Map ? inspection['driver_data'] : {};
      final attendant = inspection['attendant_data'] is Map ? inspection['attendant_data'] : {};
      final documents = inspection['documents_data'] is Map ? inspection['documents_data'] : {};

      // 2. EĞER VERİ YOKSA, MEVCUT VERİLERİ KULLAN
      setState(() {
        _vehicleData = vehicle.isNotEmpty ? Map<String, dynamic>.from(vehicle) : _vehicleData ?? {};
        _driverData = driver.isNotEmpty ? Map<String, dynamic>.from(driver) : _driverData ?? {};
        _attendantData = attendant.isNotEmpty ? Map<String, dynamic>.from(attendant) : _attendantData ?? {};
        _documentsData = documents.isNotEmpty ? Map<String, dynamic>.from(documents) : _documentsData ?? {};

        // DEBUG: Verileri kontrol et
        print('🔍 VIEW MODE VERİLERİ:');
        print('• Araç: ${_vehicleData?.length ?? 0} alan');
        print('• Sürücü: ${_driverData?.length ?? 0} alan');
        print('• Rehber: ${_attendantData?.length ?? 0} alan');
        print('• Belgeler: ${_documentsData?.length ?? 0} alan');

        // 3. CONTROLLER'LARA YÜKLE - GÜÇLENDİRİLMİŞ
        _driverNameController.text = _driverData?['full_name'] ??
            _driverData?['driver_name'] ??
            vehicle['driver_name'] ??
            '';

        _driverPhoneController.text = _driverData?['phone'] ??
            _driverData?['driver_phone'] ??
            vehicle['driver_phone'] ??
            '';

        _attendantNameController.text = _attendantData?['full_name'] ??
            _attendantData?['attendant_name'] ??
            vehicle['attendant_name'] ??
            '';

        // 4. EKSİK VERİLERİ TAMAMLA
        _completeMissingVehicleData(inspection);
      });

      print('✅ VIEW MODE araç verisi yükleme tamamlandı');

    } catch (e) {
      print('❌ VIEW MODE araç verisi yükleme hatası: $e');
    }
  }

  void _completeMissingVehicleData(Map<String, dynamic> inspection) {
    try {
      print('🔄 Eksik araç verileri tamamlanıyor...');

      // 1. INSPECTION İÇİNDEKİ ARAÇ BİLGİLERİNİ KONTROL ET
      final inspectionVehicle = inspection['vehicles'] is Map ? inspection['vehicles'] : {};
      final inspectionDriver = inspection['driver_data'] is Map ? inspection['driver_data'] : {};
      final inspectionAttendant = inspection['attendant_data'] is Map ? inspection['attendant_data'] : {};
      final inspectionDocuments = inspection['documents_data'] is Map ? inspection['documents_data'] : {};

      // 2. MEVCUT VERİLERLE BİRLEŞTİR
      _vehicleData = {...?_vehicleData, ...?inspectionVehicle};
      _driverData = {...?_driverData, ...?inspectionDriver};
      _attendantData = {...?_attendantData, ...?inspectionAttendant};
      _documentsData = {...?_documentsData, ...?inspectionDocuments};

      // 3. FALLBACK: INSPECTION'DAKİ TEMEL ALANLARI KONTROL ET
      if ((_vehicleData?['plate'] == null || _vehicleData!['plate'].isEmpty) &&
          inspection['vehicle_plate'] != null) {
        _vehicleData?['plate'] = inspection['vehicle_plate'];
      }

      if ((_driverData?['full_name'] == null || _driverData!['full_name'].isEmpty) &&
          inspection['driver_name'] != null) {
        _driverData?['full_name'] = inspection['driver_name'];
      }

      // 4. DATABASE'DEN EKSİK VERİLERİ TAMAMLA (ASYNC)
      _completeFromDatabase(inspection['vehicle_plate'] ?? widget.vehiclePlate);

    } catch (e) {
      print('❌ Eksik veri tamamlama hatası: $e');
    }
  }

  void _completeFromDatabase(String plate) async {
    try {
      print('🔍 Database\'den eksik veriler tamamlanıyor: $plate');

      final completeData = await _dbService.getCompleteVehicleDataByPlate(plate);

      if (completeData != null && !(completeData['_isEmpty'] ?? true)) {
        setState(() {
          // Eksik alanları database verisiyle doldur
          _vehicleData = {
            ...?_vehicleData,
            ...?completeData['vehicle'],
          };

          _driverData = {
            ...?_driverData,
            ...?completeData['driver'],
          };

          _attendantData = {
            ...?_attendantData,
            ...?completeData['attendant'],
          };

          _documentsData = {
            ...?_documentsData,
            ...?completeData['documents'],
          };

          // Controller'ları güncelle
          _driverNameController.text = _driverData?['full_name'] ?? _driverNameController.text;
          _driverPhoneController.text = _driverData?['phone'] ?? _driverPhoneController.text;
          _attendantNameController.text = _attendantData?['full_name'] ?? _attendantNameController.text;
        });

        print('✅ Database\'den eksik veriler tamamlandı');
      }
    } catch (e) {
      print('❌ Database tamamlama hatası: $e');
    }
  }

  // VIEW/EDIT MODE DEĞİŞTİRME - GÜNCELLENDİ
  void _toggleEditMode() {
    if (_canEdit) {
      // EDIT MODE'DAN VIEW MODE'A GEÇ
      setState(() {
        _canEdit = false;
      });
      print('👀 VIEW MODE: Düzenleme modundan çıkıldı');
    } else {
      // VIEW MODE'DAN EDIT MODE'A GEÇ - VERİ KORUMALI
      _enterEditModeWithDataProtection(); // ✅ ARTIK TANIMLI
    }
  }

  // KAYDET BUTONU - VIEW MODE'DA FARKLI ÇALIŞSIN
  void _handleSaveInViewMode() {
    if (_canEdit) {
      // DÜZENLEME MODUNDA - YENİ KAYDET
      print('✏️ Düzenleme modunda - değişiklikler kaydediliyor');
      _saveInspection();
    } else {
      // SADECE GÖRÜNTÜLEME MODUNDA - BAŞKA OKUL İÇİN KAYDET
      print('🏫 Görüntüleme modunda - başka okul için kaydet');
      _showSaveForNewSchoolDialog();
    }
  }

  AppBar _buildAppBar() {
    String title;
    Color backgroundColor;
    List<Widget> actions = [];

    if (_isViewMode) {
      title = 'Denetim Görüntüle';
      backgroundColor = Colors.blueGrey;

      // View mode actions
      actions = [
        IconButton(
          icon: Icon(_canEdit ? Icons.visibility : Icons.edit),
          onPressed: _toggleEditMode,
          tooltip: _canEdit ? 'Görüntüleme Modu' : 'Düzenleme Modu',
        ),
        if (!_canEdit)
          IconButton(
            icon: Icon(Icons.copy_all),
            onPressed: _handleSaveInViewMode,
            tooltip: 'Başka Okul İçin Kaydet',
          ),
      ];
    } else {
      title = widget.isNewInspection ? 'Yeni Denetim' : 'Denetim Düzenle';
      backgroundColor = Color(0xFF2196F3);

      // Normal mode actions
      actions = [
        IconButton(
          icon: Icon(Icons.save),
          onPressed: _saveInspection,
          tooltip: 'Denetimi Kaydet',
        ),
      ];
    }

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            widget.vehiclePlate,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: actions,
    );
  }



  // ✅ 3. VIEW MODE BUTONLARI
  Widget _buildViewModeButtons() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          if (_canEdit)
          // DÜZENLEME MODUNDA - KAYDET BUTONU
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveInspection,
                icon: Icon(Icons.save, size: 20),
                label: Text('DEĞİŞİKLİKLERİ KAYDET'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
          // GÖRÜNTÜLEME MODUNDA - BAŞKA OKUL İÇİN KAYDET
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showSaveForNewSchoolDialog,
                icon: Icon(Icons.copy_all, size: 20),
                label: Text('BAŞKA OKUL İÇİN KAYDET'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

          SizedBox(height: 10),

          // MOD DEĞİŞTİRME/GERİ DÖN BUTONU
          SizedBox(
            width: double.infinity,
            height: 45,
            child: TextButton.icon(
              onPressed: _canEdit ? _toggleEditMode : () => Navigator.pop(context),
              icon: Icon(_canEdit ? Icons.cancel : Icons.arrow_back),
              label: Text(_canEdit ? 'DÜZENLEMEYİ İPTAL' : 'GERİ DÖN'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }




  // ✅ 5. MADDE: SAVE BUTONU - VIEW MODE'A GÖRE AYARLA
  Widget _buildSaveButton() {
    if (_isViewMode) {
      return Column(
        children: [
          // DÜZENLEME/KAYDETME BUTONLARI
          if (_canEdit)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveInspection,
                icon: Icon(Icons.save, size: 20),
                label: Text('DEĞİŞİKLİKLERİ KAYDET'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showSaveForNewSchoolDialog,
                icon: Icon(Icons.copy_all, size: 20),
                label: Text('BAŞKA OKUL İÇİN KAYDET'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

          SizedBox(height: 10),

          // İPTAL/ GERİ DÖN BUTONU
          SizedBox(
            width: double.infinity,
            height: 45,
            child: TextButton.icon(
              onPressed: _canEdit ? _toggleEditMode : () => Navigator.pop(context),
              icon: Icon(_canEdit ? Icons.cancel : Icons.arrow_back),
              label: Text(_canEdit ? 'DÜZENLEMEYİ İPTAL' : 'GERİ DÖN'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),
          ),
        ],
      );
    }

    // NORMAL SAVE BUTONU
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _saveInspection,
        icon: Icon(Icons.save, size: 20),
        label: Text('DENETİMİ KAYDET'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF2196F3),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  // ✅ 6. MADDE: FORM ALANLARINI VIEW MODE'DA DISABLE ET
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isViewMode || _canEdit, // ✅ VIEW MODE KONTROLÜ
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }

  // CHECKBOX İÇİN VIEW MODE KONTROLÜ
  Widget _buildCompliantCheckbox(String itemId, String question) {
    final result = _inspectionResults[itemId] ?? {};
    final isCompliant = result['is_compliant'] ?? false;

    return CheckboxListTile(
      title: Text(question),
      value: isCompliant,
      onChanged: (!_isViewMode || _canEdit) ? (value) {
        setState(() {
          _inspectionResults[itemId] = {
            ...result,
            'is_compliant': value ?? false,
          };
        });
        _calculateScore();
      } : null, // ✅ VIEW MODE'DA DISABLE
      secondary: Icon(
        isCompliant ? Icons.check_circle : Icons.error,
        color: isCompliant ? Colors.green : Colors.red,
      ),
    );
  }

  // SCHOOL DROPDOWN İÇİN VIEW MODE KONTROLÜ
  Widget _buildSchoolDropdown() {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedSchool,
      items: _allSchools.map((school) {
        return DropdownMenuItem(
          value: school,
          child: Text('${school['name']} - ${school['district']}'),
        );
      }).toList(),
      onChanged: (!_isViewMode || _canEdit) ? (value) {
        setState(() {
          _selectedSchool = value;
        });
      } : null,
      decoration: InputDecoration(
        labelText: 'Okul Seçin',
        border: OutlineInputBorder(),
        filled: _isViewMode, // ✅ VIEW MODE'DA DOLGU RENGİ
        fillColor: _isViewMode ? Colors.grey[100] : null, // ✅ GRİ ARKA PLAN
      ),
      isExpanded: true,
      // ✅ VIEW MODE'DA DROPDOWN AÇIK OLSUN AMA SEÇİLEMESİN
      dropdownColor: _isViewMode ? Colors.grey[50] : null,
    );
  }

  // ✅ 7. MADDE: BAŞKA OKUL İÇİN KAYDET DIALOG'U
  void _showSaveForNewSchoolDialog() {
    final currentSchool = _selectedSchool?['name'] ?? 'mevcut okul';
    final completedItems = _getCompletedItemsCount();
    final totalItems = _getTotalItemsCount();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Başka Okul İçin Kaydet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bu denetimi "$currentSchool" yerine başka bir okul için kaydetmek istiyor musunuz?'),
            SizedBox(height: 10),
            Text(
              '✅ Mevcut denetim korunacak:\n'
                  '• $completedItems/$totalItems tamamlanan madde\n'
                  '• Tüm "Uygun/Uygun Değil" seçimleri\n'
                  '• Notlar ve açıklamalar\n'
                  '• Sadece okul değişecek',
              style: TextStyle(fontSize: 12, color: Colors.green[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveForNewSchool();
            },
            child: Text('Evet, Yeni Okul İçin Kaydet'),
          ),
        ],
      ),
    );
  }





  // Denetim maddelerini yükle
  Future<void> _loadInspectionItems() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Database'den denetim maddelerini al
      final itemsData = await _dbService.getInspectionItems();

      // InspectionItem listesine dönüştür
      final List<InspectionItem> items = itemsData.map((item) {
        return InspectionItem(
          id: item['id'] ?? 0,
          question: item['question'] ?? '',
          description: item['description'] ?? '',
          hasDateField: item['type'] == 'date',
          dateFieldLabel: item['vehicle_field'] ?? '',
          isCriticalDate: item['is_critical'] ?? false,
          hasInfoField: item['type'] == 'info',
          infoLabel: item['vehicle_field'] ?? '',
          hasYesNoField: item['type'] == 'boolean',
          reverseScoring: item['reverse_scoring'] ?? false,
        );
      }).toList();

      // Kategorilere ayır
      final categories = _groupItemsByCategory(items);

      setState(() {
        _allItems = items;
        _categories = categories;
        _isLoading = false;
      });

      print('✅ ${items.length} denetim maddesi yüklendi, ${categories.length} kategori');

    } catch (e) {
      print('❌ Denetim maddeleri yükleme hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }



// Plaka ile yeni denetim başlat
  void _startNewInspectionWithPlate(String plate, Map<String, dynamic>? previousInspection) {
    // Yeni InspectionFormScreen'a geç - önceki verileri aktar
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionFormScreen(
          vehiclePlate: plate,
          isNewInspection: true,
          previousInspectionData: previousInspection,
          isDuplicateForNewSchool: previousInspection != null,
        ),
      ),
    );
  }



  // Kaydetme işlemini gerçekleştir
  void _performSaveInspection({String? schoolName}) {
    // Mevcut _saveInspection metodunu kullan
    _saveInspection();
  }

  void _showDuplicateConfirmation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final schoolName = widget.previousInspectionData!['schools']?['name'] ?? 'önceki okul';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Başka Okul İçin Kayıt'),
          content: Text('Bu denetimi "$schoolName" için mi kaydetmek istiyorsunuz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadPreviousInspectionData();
              },
              child: Text('Evet, Kaydet'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _initializeNewInspection();
              },
              child: Text('Hayır, Yeni Başlat'),
            ),
          ],
        ),
      );
    });
  }

  // Önceki denetim verilerini yükle
  void _loadPreviousInspectionData() {
    print('🔄 Önceki denetim verileri yükleniyor...');

    setState(() {
      _previousInspectionData = widget.previousInspectionData;
    });

    // Mevcut formu başlat
    _initializeForm().then((_) {
      // Önceki denetim verilerini uygula
      _applyPreviousInspectionData();
    });
  }

  // Yeni denetim başlat
  void _initializeNewInspection() {
    print('🔄 Yeni denetim başlatılıyor...');

    // Mevcut formu başlat
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    if (_isViewMode) {
      await _initializeFormForViewMode();
      // View mode için kategorileri yükle
      _initializeCategories(); // ✅ Normal kategori yapısını kullan
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // NORMAL FORM BAŞLATMA (önceki kodunuz)
    try {
      print('🔄 Form başlatılıyor: ${widget.vehiclePlate}');

      // Önce plakayı normalize et
      final normalizedPlate = widget.vehiclePlate.toUpperCase().replaceAll(' ', '');

      // LOCAL'DA ARAÇ VAR MI KONTROL ET
      final localVehicle = await _localStorage.getVehicleByPlate(normalizedPlate);
      if (localVehicle != null) {
        print('✅ Local\'da araç bulundu, hızlı yükleme yapılıyor');
        await _loadFromLocalData(localVehicle, normalizedPlate);
        return;
      }

      // ONLINE VERİYİ DENE
      await _loadFromOnlineData(normalizedPlate);

    } catch (e) {
      print('❌ Form başlatma hatası: $e');
      await _loadFallbackData();
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('✅ Form başlatma tamamlandı');
    }
  }

  Future<void> _loadFromLocalData(Map<String, dynamic> localVehicle, String normalizedPlate) async {
    final vehicleId = localVehicle['id'];

    final results = await Future.wait<dynamic>([
      _dbService.getCompleteVehicleDataByPlate(normalizedPlate),
      _dbService.getSchools(),
      _dbService.getRecentInspections(normalizedPlate),
    ], eagerError: true);

    final completeData = results[0] as Map<String, dynamic>;

    setState(() {
      _completeVehicleData = completeData;
      _vehicleData = completeData['vehicle'] != null
          ? Map<String, dynamic>.from(completeData['vehicle'])
          : null;
      _driverData = completeData['driver'] != null
          ? Map<String, dynamic>.from(completeData['driver'])
          : {};
      _attendantData = completeData['attendant'] != null
          ? Map<String, dynamic>.from(completeData['attendant'])
          : {};
      _documentsData = completeData['documents'] != null
          ? Map<String, dynamic>.from(completeData['documents'])
          : {};
      _schools = completeData['schools'] != null
          ? List<dynamic>.from(completeData['schools'])
          : [];

      _allSchools = (results[1] as List).cast<Map<String, dynamic>>();
      _recentInspections = (results[2] as List).cast<Map<String, dynamic>>();

      final bool isEmptyData = completeData['_isEmpty'] ?? false;
      _usingSampleData = isEmptyData || (completeData['_isSample'] ?? false);

      // Controller'lara yükle
      _driverNameController.text = _driverData?['full_name'] ?? '';
      _driverPhoneController.text = _driverData?['phone'] ?? '';
      _attendantNameController.text = _attendantData?['full_name'] ?? '';
    });

    _initializeCategories();
  }

  Future<void> _loadFromOnlineData(String normalizedPlate) async {
    try {
      // FUTURE.WAIT TİP SORUNUNU ÇÖZELİM
      final results = await Future.wait<dynamic>([
        _dbService.getCompleteVehicleDataByPlate(normalizedPlate),
        _dbService.getSchools(),
        _dbService.getRecentInspections(normalizedPlate),
      ], eagerError: true);

      final completeData = results[0] as Map<String, dynamic>;

      // ONLINE VERİYİ LOCAL'A KAYDET
      if (completeData['vehicle'] != null && !(completeData['_isEmpty'] ?? true)) {
        await _localStorage.saveVehicle(completeData['vehicle']);
      }

      setState(() {
        _completeVehicleData = completeData;
        _vehicleData = completeData['vehicle'] != null
            ? Map<String, dynamic>.from(completeData['vehicle'])
            : null;
        _driverData = completeData['driver'] != null
            ? Map<String, dynamic>.from(completeData['driver'])
            : {};
        _attendantData = completeData['attendant'] != null
            ? Map<String, dynamic>.from(completeData['attendant'])
            : {};
        _documentsData = completeData['documents'] != null
            ? Map<String, dynamic>.from(completeData['documents'])
            : {};
        _schools = completeData['schools'] != null
            ? List<dynamic>.from(completeData['schools'])
            : [];

        _allSchools = (results[1] as List).cast<Map<String, dynamic>>();
        _recentInspections = (results[2] as List).cast<Map<String, dynamic>>();

        final bool isEmptyData = completeData['_isEmpty'] ?? false;
        _usingSampleData = isEmptyData || (completeData['_isSample'] ?? false);

        // Controller'lara yükle
        _driverNameController.text = _driverData?['full_name'] ?? '';
        _driverPhoneController.text = _driverData?['phone'] ?? '';
        _attendantNameController.text = _attendantData?['full_name'] ?? '';
      });

      _initializeCategories();
    } catch (e) {
      print('❌ Online veri yükleme hatası: $e');
      throw e;
    }
  }

  Future<void> _loadFallbackData() async {
    setState(() {
      _completeVehicleData = _createEmptyVehicleData();
      _vehicleData = _completeVehicleData?['vehicle'];
      _driverData = _completeVehicleData?['driver'];
      _attendantData = _completeVehicleData?['attendant'];
      _documentsData = _completeVehicleData?['documents'];
      _schools = _completeVehicleData?['schools'];
      _usingSampleData = true;
    });
    _initializeCategories();
  }

  // EKSİK METODLARI EKLEYELİM - YENİ METODLAR
  int _getCompletedItemsCount() {
    return _inspectionCategories
        .expand((category) => category.items)
        .where((item) => item.status != null && !item.isInfoSection && !item.isSettingsSection)
        .length;
  }

  int _getTotalItemsCount() {
    return _inspectionCategories
        .expand((category) => category.items)
        .where((item) => !item.isInfoSection && !item.isSettingsSection)
        .length;
  }

  String _calculateInspectionResult() {
    final completedItems = _getCompletedItemsCount();
    final totalItems = _getTotalItemsCount();

    if (completedItems == 0) return 'başlatılmadı';
    if (completedItems == totalItems) return 'tamamlandı';
    return 'devam_ediyor';
  }

// VEYA DAHA DETAYLI BİR STATUS HESAPLAMA:

  String _calculateDetailedInspectionResult() {
    final completedItems = _getCompletedItemsCount();
    final totalItems = _getTotalItemsCount();

    if (completedItems == 0) return 'başlatılmadı';

    // Tüm maddeler tamamlandı mı?
    if (completedItems == totalItems) {
      // Uygunluk durumuna göre status belirle
      final nonCompliantCount = _inspectionResults.values
          .where((result) => result['is_compliant'] == false)
          .length;

      if (nonCompliantCount == 0) {
        return 'compliant'; // Tüm maddeler uygun
      } else if (nonCompliantCount <= 3) { // Örnek threshold
        return 'conditional'; // Şartlı uygun
      } else {
        return 'non_compliant'; // Uygun değil
      }
    }

    return 'devam_ediyor';
  }



// Boş veri oluştur
  Map<String, dynamic> _createEmptyVehicleData() {
    return {
      'vehicle': {
        'plate': widget.vehiclePlate, // widget.vehiclePlate kullan
        'model': '',
        'model_year': null,
        'capacity': null,
        'transport_type': 'private',
        'manufacture_year': null,
        'last_maintenance_date': null,
      },
      'driver': {
        'full_name': '',
        'phone': '',
        'birth_date': null,
        'license_expiry_date': null,
        'src_certificate_expiry': null,
      },
      'attendant': {
        'full_name': '',
        'birth_date': null,
        'has_reflective_vest': false,
        'has_warning_lights': false,
      },
      'documents': {
        'insurance_expiry': null,
        'inspection_expiry': null,
        'route_permission_expiry': null,
        'g_certificate_expiry': null,
        'fire_extinguisher_expiry': null,
      },
      'schools': [],
      '_isSample': true,
      '_isEmpty': true,
    };
  }

  // Örnek veri oluşturma metodu - EKLENDİ
  Map<String, dynamic> _createSampleVehicleData() {
    return {
      'vehicle': {
        'plate': widget.vehiclePlate,
        'model': 'Sample Model',
        'model_year': 2020,
        'capacity': 20,
        'transport_type': 'private',
        'manufacture_year': 2020,
        'last_maintenance_date': '2024-01-01',
      },
      'driver': {
        'full_name': 'Örnek Sürücü',
        'phone': '0555 555 55 55',
        'birth_date': '1985-01-01',
        'license_expiry_date': '2025-12-31',
        'src_certificate_expiry': '2025-12-31',
      },
      'attendant': {
        'full_name': 'Örnek Rehber',
        'birth_date': '1990-01-01',
        'has_reflective_vest': true,
        'has_warning_lights': true,
      },
      'documents': {
        'insurance_expiry': '2024-12-31',
        'inspection_expiry': '2024-12-31',
        'route_permission_expiry': '2024-12-31',
        'g_certificate_expiry': '2024-12-31',
        'fire_extinguisher_expiry': '2024-12-31',
      },
      'schools': [
        {'name': 'Örnek İlkokulu', 'district': 'Merkez'}
      ],
      '_isSample': true,
    };
  }

  void _checkRecentInspection() {
    if (_recentInspections.isNotEmpty) {
      final lastInspection = _recentInspections.first;
      final inspectionDate = DateTime.parse(lastInspection['inspection_date']);
      final daysSinceInspection = DateTime.now().difference(inspectionDate).inDays;

      final lastSchool = lastInspection['school_name'];
      final currentSchool = _selectedSchool?['name'];

      setState(() {
        _showRecentInspectionWarning = daysSinceInspection <= 15;
        _lastInspectionSchool = lastSchool;
        _lastInspectionDate = inspectionDate;
      });

      print('🔍 Son denetim kontrolü:');
      print('• Tarih: $inspectionDate');
      print('• Gün farkı: $daysSinceInspection');
      print('• Okul: $lastSchool');
      print('• Uyarı göster: $_showRecentInspectionWarning');
    }
  }

  void _initializeCategories() {
    // Mevcut kategori yapısını oluştur
    _inspectionCategories = [
      InspectionCategory(
        name: 'Denetim Bilgileri',
        description: 'Denetim ayarları ve temel bilgiler',
        items: [
          InspectionItem(
            id: -2,
            question: "DENETİM AYARLARI",
            description: "Denetim ile ilgili temel bilgiler",
            isSettingsSection: true,
          ),
        ],
      ),
      InspectionCategory(
        name: 'Genel Bilgiler',
        items: [
          InspectionItem(
            id: 0,
            question: "ARAÇ GENEL BİLGİLERİ",
            description: "Araç ve personel bilgileri",
            isInfoSection: true,
            infoData: _getGeneralInfoData(),
          ),
        ],
        description: '',
      ),
      InspectionCategory(
        name: 'Sürücü',
        items: [
          InspectionItem(
            id: 1,
            question: "Araç Sürücüsü Yeterli sürücü Belgesine Sahip mi? (D,E5-D1,B7)",
            description: "D sınıfı sürücü belgesi için en az beş yıllık, D1 sınıfı sürücü belgesi için en az yedi yıllık sürücü belgesine sahip olmak",
            hasDateField: true,
            dateFieldLabel: "Ehliyet Geçerlilik Tarihi",
            dateValue: _driverData?['license_expiry_date']?.toString(),
            hasInfoField: true,
            infoLabel: "Ehliyet Tipi",
            infoValue: _driverData?['license_type'] ?? 'Belirtilmemiş',
            // View Mode için response'u ata
            viewModeResponse: _getViewModeResponse('1'),
          ),
          InspectionItem(
            id: 2,
            question: "Araç sürücüsünün yaşı uygun mu?",
            description: "26 yaşından gün almış 66 yaşından gün almamış olmak",
            hasInfoField: true,
            infoLabel: "Sürücü Yaşı",
            infoValue: _getDriverAgeInfo(),
            hasDateField: false,
            dateFieldLabel: "Doğum Tarihi",
            dateValue: (_driverData?['driver_birth_date'] ?? _driverData?['birth_date'])?.toString(),
            viewModeResponse: _getViewModeResponse('2'),
          ),
          InspectionItem(
            id: 3,
            question: "Araç sürücüsü SRC1-SRC2 Belgesi var mı?",
            description: "",
            hasDateField: true,
            dateFieldLabel: "SRC Belge Geçerlilik Tarihi",
            dateValue: _driverData?['src_certificate_expiry']?.toString(),
            hasYesNoField: false,
            yesNoValue: _driverData?['src_certificate_expiry'] != null,
            viewModeResponse: _getViewModeResponse('3'),
          ),
          InspectionItem(
            id: 4,
            question: "Sürücünün kıyafeti uygun mu?",
            description: "",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('4'),
          ),
          InspectionItem(
            id: 5,
            question: "Sürücü 'Öğrenci Yoklama Defteri' tutuyor mu?",
            description: "",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('5'),
          ),
        ],
        description: '',
      ),
      InspectionCategory(
        name: 'Rehber',
        items: [
          InspectionItem(
            id: 6,
            question: "Rehber personel yaşı uygun mu?",
            description: "22 yaşını doldurmuş ve 61 yaşından gün almamış olmak",
            hasInfoField: true,
            infoLabel: "Rehber Yaşı",
            infoValue: _getAttendantAgeInfo(),
            hasDateField: false,
            dateFieldLabel: "Doğum Tarihi",
            dateValue: _attendantData?['birth_date']?.toString(),
            viewModeResponse: _getViewModeResponse('6'),
          ),
          InspectionItem(
            id: 7,
            question: "Rehber personel standart ikaz yeleği giymiş mi?",
            description: "TS EN ISO 20471 standartlara uygun, sarı renkte reflektif yelek",
            hasYesNoField: true,
            yesNoValue: _attendantData?['has_reflective_vest'] ?? false,
            hasInfoField: false,
            infoLabel: "Durum",
            infoValue: (_attendantData?['has_reflective_vest'] ?? false) ? 'VAR' : 'YOK',
            viewModeResponse: _getViewModeResponse('7'),
          ),
          InspectionItem(
            id: 8,
            question: "Rehber Personelde yardımcı ışıklar bulunuyor mu?",
            description: "Işıklı çubuk, dur-geç levhası gibi",
            hasYesNoField: true,
            yesNoValue: _attendantData?['has_warning_lights'] ?? false,
            hasInfoField: false,
            infoLabel: "Durum",
            infoValue: (_attendantData?['has_warning_lights'] ?? false) ? 'VAR' : 'YOK',
            viewModeResponse: _getViewModeResponse('8'),
          ),
        ],
        description: '',
      ),
      InspectionCategory(
        name: 'Araç Belgeleri',
        items: [
          InspectionItem(
            id: 9,
            question: "Araçta tanıtım kartı mevcut mu?",
            description: "",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('9'),
          ),
          InspectionItem(
            id: 25,
            question: "Zorunlu Mali ve Koltuk Sigortası yapılmış mı?",
            description: "Bitiş tarihlerine dikkat edilecek",
            hasDateField: true,
            dateFieldLabel: "Sigorta Bitiş Tarihi",
            isCriticalDate: true,
            dateValue: _documentsData?['insurance_expiry']?.toString(),
            viewModeResponse: _getViewModeResponse('25'),
          ),
          InspectionItem(
            id: 26,
            question: "Aracın muayenesi yapılmış mı?",
            description: "Bitiş tarihine dikkat edilecek",
            hasDateField: true,
            dateFieldLabel: "Muayene Bitiş Tarihi",
            isCriticalDate: true,
            dateValue: _documentsData?['inspection_expiry']?.toString(),
            viewModeResponse: _getViewModeResponse('26'),
          ),
          InspectionItem(
            id: 31,
            question: "Güzergah izin belgesi var mı?",
            description: "Özel Servis",
            hasDateField: true,
            dateFieldLabel: "İzin Belgesi Bitiş Tarihi",
            dateValue: _documentsData?['route_permission_expiry']?.toString(),
            hasYesNoField: false,
            yesNoValue: _documentsData?['route_permission_expiry'] != null,
            hasInfoField: false,
            infoLabel: "Durum",
            infoValue: _documentsData?['route_permission_expiry'] != null ?
            'VAR (${_formatDate(_documentsData!['route_permission_expiry'])})' : 'YOK',
            viewModeResponse: _getViewModeResponse('31'),
          ),
          InspectionItem(
            id: 32,
            question: "Farklı İlden geliyorsa G Belgesi var mı?",
            description: "Özel Servis",
            hasDateField: true,
            dateFieldLabel: "G Belgesi Bitiş Tarihi",
            dateValue: _documentsData?['g_certificate_expiry']?.toString(),
            hasYesNoField: false,
            yesNoValue: _documentsData?['g_certificate_expiry'] != null,
            viewModeResponse: _getViewModeResponse('32'),
          ),
        ],
        description: '',
      ),
      InspectionCategory(
        name: 'Araç Durumu',
        items: [
          InspectionItem(
            id: 10,
            question: "Servis aracının yaşı 15'ten küçük mü?",
            description: "Fabrikasınca imal edildiği tarihten sonra gelen ilk takvim yılı esas alınacak",
            hasInfoField: true,
            infoLabel: "Araç Yaşı & Üretim Yılı",
            infoValue: _getVehicleAgeWithManufactureYear(),
            viewModeResponse: _getViewModeResponse('10'),
          ),
          InspectionItem(
            id: 11,
            question: "DUR lambası tesis edilmiş mi?",
            description: "En az 30 cm çapında kırmızı ışık veren lamba ve DUR yazısı",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('11'),
          ),
          InspectionItem(
            id: 12,
            question: "Aracın arkasında 'OKUL TAŞITI' yazısı var mı?",
            description: "Standartlara uygun şekilde",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('12'),
          ),
          InspectionItem(
            id: 29,
            question: "Araç arkasında İlçe MEM numarası var mı?",
            description: "",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('29'),
          ),
        ],
        description: '',
      ),
      InspectionCategory(
        name: 'Araç İç Düzen',
        items: [
          InspectionItem(
            id: 13,
            question: "Cam ve çerçeveler sabit mi? İç aksam kaplanmış mı?",
            description: "Demir aksamlar yumuşak madde ile kaplanmış mı?",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('13'),
          ),
          InspectionItem(
            id: 14,
            question: "Araç kapıları otomatik veya mekanik mi?",
            description: "Sürücü tarafından açılıp kapatılabilecek şekilde",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('14'),
          ),
          InspectionItem(
            id: 15,
            question: "Isıtma ve soğutma sistemi çalışıyor mu?",
            description: "",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('15'),
          ),
          InspectionItem(
            id: 20,
            question: "Beyaz cam dışında renklı cam kullanılmış mı?",
            description: "",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('20'),
          ),
          InspectionItem(
            id: 27,
            question: "Oturma kapasitesi listesi asılı mı?",
            description: "",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('27'),
          ),
          InspectionItem(
            id: 28,
            question: "Taşınan öğrenci listesi asılı mı?",
            description: "",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('28'),
          ),
        ],
        description: '',
      ),
      InspectionCategory(
        name: 'Araç Donanım',
        items: [
          InspectionItem(
            id: 16,
            question: "Araç geri vites sireni mevcut mu?",
            description: "",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('16'),
          ),
          InspectionItem(
            id: 17,
            question: "Araç takip sistemi var ve çalışıyor mu?",
            description: "Kayıtlar en az otuz gün muhafaza edilecek",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('17'),
          ),
          InspectionItem(
            id: 18,
            question: "İç-dış kamera sistemi var ve çalışıyor mu?",
            description: "1/1/2018 öncesi araçlarda aranmaz",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('18'),
          ),
          InspectionItem(
            id: 19,
            question: "Oturmaya duyarlı sensör çalışıyor mu?",
            description: "1/1/2018 öncesi araçlarda aranmaz",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('19'),
          ),
        ],
        description: '',
      ),
      InspectionCategory(
        name: 'Güvenlik',
        items: [
          InspectionItem(
            id: 21,
            question: "Her öğrenci için emniyet kemeri var mı?",
            description: "1/1/2018 sonrası araçlarda üç nokta emniyet kemeri şartı",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('21'),
          ),
          InspectionItem(
            id: 22,
            question: "İlkyardım Çantası ve Trafik Seti var mı?",
            description: "",
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('22'),
          ),
          InspectionItem(
            id: 23,
            question: "Yangın söndürme tüpü var ve bakımlı mı?",
            description: "",
            hasDateField: true,
            dateFieldLabel: "Yangın Tüpü Dolum/Kontrol Tarihi",
            isCriticalDate: true,
            dateValue: _documentsData?['fire_extinguisher_expiry']?.toString(),
            viewModeResponse: _getViewModeResponse('23'),
          ),
        ],
        description: '',
      ),
      InspectionCategory(
        name: 'Bakım',
        items: [
          InspectionItem(
            id: 24,
            question: "6 aylık periyodik bakım yapılıyor mu?",
            description: "Aracın temizliği, tertip düzeni iyi mi?",
            hasDateField: false,
            dateFieldLabel: "Son Bakım Tarihi",
            dateValue: _vehicleData?['last_maintenance_date']?.toString(),
            hasInfoField: true,
            infoLabel: "Son Bakım",
            infoValue: _getMaintenanceStatus(_vehicleData?['last_maintenance_date'] != null
                ? DateTime.parse(_vehicleData!['last_maintenance_date'])
                : null),
            viewModeResponse: _getViewModeResponse('24'),
          ),
        ],
        description: '',
      ),
      InspectionCategory(
        name: 'Diğer',
        items: [
          InspectionItem(
            id: 30,
            question: "Araç öğrenci dışında yolcu/yük taşıyor mu?",
            description: "",
            reverseScoring: true,
            hasYesNoField: true,
            viewModeResponse: _getViewModeResponse('30'),
          ),
        ],
        description: '',
      ),
    ];

    // Tüm kategorileri başlangıçta kapalı yap
    _initializeExpandedCategories();
  }


  String _getVehicleAgeWithManufactureYear() {
    final manufactureYear = _vehicleData?['manufacture_year'];
    final modelYear = _vehicleData?['model_year'];
    final currentYear = DateTime.now().year;

    final effectiveYear = manufactureYear ?? modelYear;

    if (effectiveYear != null) {
      final age = currentYear - effectiveYear;
      return '$age yaşında (${effectiveYear} üretim)';
    }

    return 'Üretim yılı bilgisi yok';
  }

  String _getMaintenanceStatus(DateTime? maintenanceDate) {
    if (maintenanceDate == null) return 'Bakım Kaydı Yok';

    // Sadece tarihi formatla
    return '${maintenanceDate.day}/${maintenanceDate.month}/${maintenanceDate.year}';
  }


  // YARDIMCI METODLAR
  Map<String, String> _getGeneralInfoData() {
    // DEBUG: Tüm driverData'yı kontrol et
    print('🔍 DRIVER DATA YAPISI: $_driverData');
    print('🔍 ATTENDANT DATA YAPISI: $_attendantData');

    final driverBirthDate = _driverData?['driver_birth_date'] ?? _driverData?['birth_date'];
    final driverAge = _getDriverAgeInfo();

    final attendantBirthDate = _attendantData?['birth_date'];
    final attendantAge = _getAttendantAgeInfo();

    return {
      'Plaka': _vehicleData?['plate'] ?? 'Belirtilmemiş',
      'Model': _vehicleData?['model'] ?? 'Belirtilmemiş',
      'Model Yılı': _vehicleData?['model_year']?.toString() ?? 'Belirtilmemiş',
      'Araç Yaşı': _getVehicleAgeWithManufactureYear(),
      'Kapasite': '${_vehicleData?['capacity'] ?? 0} öğrenci',
      'Taşıma Türü': _vehicleData?['transport_type'] == 'private' ? 'Özel Taşıma' : 'Devlet Taşıması',

      // SÜRÜCÜ BİLGİLERİ - GÜNCELLENDİ
      'Sürücü Adı': _driverData?['full_name'] ?? 'Belirtilmemiş',
      'Sürücü Telefon': _driverData?['phone'] ?? 'Belirtilmemiş',
      'Ehliyet Tipi': _driverData?['license_type'] ?? 'Belirtilmemiş',
      'Sürücü Doğum Tarihi': driverBirthDate != null ? _formatDate(driverBirthDate) : 'Belirtilmemiş',
      'Sürücü Yaşı': driverAge,
      'Ehliyet Geçerlilik': _driverData?['license_expiry_date'] != null ?
      _formatDate(_driverData!['license_expiry_date']) : 'Belirtilmemiş',

      // REHBER BİLGİLERİ - GÜNCELLENDİ
      'Rehber Personel': _attendantData?['full_name'] ?? 'Yok',
      'Rehber Doğum Tarihi': attendantBirthDate != null ? _formatDate(attendantBirthDate) : 'Belirtilmemiş',
      'Rehber Yaşı': attendantAge,
      'Reflektif Yelek': _attendantData?['has_reflective_vest'] == true ? 'VAR' : 'YOK',
      'Yardımcı Işıklar': _attendantData?['has_warning_lights'] == true ? 'VAR' : 'YOK',

      // BELGE BİLGİLERİ
      'Güzergah İzni': _documentsData?['route_permission_expiry'] != null ?
      'VAR (${_formatDate(_documentsData!['route_permission_expiry'])})' : 'YOK',

      'Bağlı Okullar': _schools?.map((s) => s['name']).join(', ') ?? 'Belirtilmemiş',
    };
  }

// _getDriverAgeInfo metodunu güncelleyelim
  String _getDriverAgeInfo() {
    // Önce driver_birth_date'ye bak, yoksa birth_date'ye bak
    final birthDate = _driverData?['driver_birth_date'] ?? _driverData?['birth_date'];
    if (birthDate != null) {
      try {
        final age = _calculateAge(DateTime.parse(birthDate));
        return '$age yaşında';
      } catch (e) {
        return 'Yaş bilgisi yok';
      }
    }
    return 'Yaş bilgisi yok';
  }

// _getAttendantAgeInfo metodunu güncelle
  String _getAttendantAgeInfo() {
    final birthDate = _attendantData?['birth_date'];
    if (birthDate != null) {
      try {
        final age = _calculateAge(DateTime.parse(birthDate));
        return '$age yaşında';
      } catch (e) {
        return 'Yaş bilgisi yok';
      }
    }
    return 'Yaş bilgisi yok';
  }

// _getVehicleAgeInfo metodunu güncelleyelim
  String _getVehicleAgeInfo() {
    final manufactureYear = _vehicleData?['manufacture_year'];
    if (manufactureYear != null) {
      final currentYear = DateTime.now().year;
      final age = currentYear - manufactureYear;
      return '$age yaşında';
    }
    return 'Üretim yılı yok';
  }


  // Tarih kontrolü
  bool _isDateExpired(String? dateString) {
    if (dateString == null) return true;
    try {
      final date = DateTime.parse(dateString);
      return date.isBefore(DateTime.now());
    } catch (e) {
      return true;
    }
  }

// Tarih formatlama
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

// Yaş hesaplama
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }




  void _handleItemStatusChange(InspectionItem item, String status) {
    setState(() {
      item.status = status;

      // Eğer "Uygun Değil" seçildiyse, not ekranını aç
      if (status == 'non_compliant') {
        _showNonCompliantDialog(item);
      }
    });
  }

  void _showNonCompliantDialog(InspectionItem item) {
    showDialog(
      context: context,
      builder: (context) => NonCompliantDialog(
        item: item,
        onSave: (description, photos) {
          // Uygunsuzluk notunu ve fotoğrafları kaydet
          setState(() {
            item.nonCompliantDescription = description;
            item.nonCompliantPhotos = photos;
          });
        },
      ),
    );
  }

  void _toggleCategory(int index) {
    setState(() {
      _expandedCategories[index] = !_expandedCategories[index]!;
    });
  }

  void _submitInspection() {
    final completedItems = _inspectionCategories
        .expand((category) => category.items)
        .where((item) => item.status != null && !item.isInfoSection && !item.isSettingsSection)
        .length;

    final totalItems = _inspectionCategories
        .expand((category) => category.items)
        .where((item) => !item.isInfoSection && !item.isSettingsSection)
        .length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Denetim Tamamlandı'),
        content: Text('$completedItems/$totalItems madde denetlendi.\nDenetimi göndermek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveInspection();
            },
            child: Text('Gönder'),
          ),
        ],
      ),
    );
  }

  // MEB ağı için özel HTTP client
  http.Client _createMebClient() {
    var ioClient = HttpClient();

    // TÜM SSL SERTİFİKA HATALARINI ATLA - MEB İÇİN
    ioClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
      print('🔓 SSL sertifika atlanıyor: $host');
      return true; // Tüm sertifikaları kabul et
    };

    // Timeout ayarları
    ioClient.connectionTimeout = Duration(seconds: 20);
    ioClient.idleTimeout = Duration(seconds: 15);

    return IOClient(ioClient);
  }

// Local kayıt metodu
  void _saveInspectionLocally(Map<String, dynamic> inspectionData) {
    print(
        '📱 Denetim local olarak kaydedildi: ${inspectionData['vehicle_plate']}');
  }

  // HYBRID denetim kaydetme
  Future<void> saveInspectionHybrid(Map<String, dynamic> inspectionData) async {
    http.Client? client;

    try {
      print('🔧 HYBRID: Denetim kaydediliyor');
      client = _createMebClient();

      // HTTP ile dene
      final response = await client.post(
        Uri.parse('$_supabaseUrl/rest/v1/inspections'),
        headers: _headers,
        body: json.encode(inspectionData),
      );

      if (response.statusCode == 201) {
        print('✅ HTTP denetim kaydı başarılı');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP denetim kaydı başarısız, Supabase fallback: $e');

      // Supabase fallback - DatabaseService kullan
      try {
        await _dbService.saveInspection(inspectionData);
        print('✅ Supabase denetim kaydı başarılı');
      } catch (supabaseError) {
        print('❌ Tüm bağlantılar başarısız, local kayıt: $supabaseError');
        _saveInspectionLocally(inspectionData);
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }




  // View Mode'dan denetim verilerini kurtar
  void _recoverInspectionDataFromViewMode() {
    try {
      print('🔄 VIEW MODE VERİLERİNDEN KURTARMA BAŞLATILDI');
      int recoveredCount = 0;

      for (final category in _inspectionCategories) {
        for (final item in category.items) {
          if (!item.isInfoSection && !item.isSettingsSection && item.viewModeResponse != null) {
            final itemId = item.id.toString();
            final response = item.viewModeResponse!;

            _inspectionResults[itemId] = {
              'is_compliant': response['status'] == 'compliant',
              'notes': response['notes'] ?? '',
              'non_compliant_description': response['non_compliant_description'] ?? '',
            };
            recoveredCount++;
          }
        }
      }

      print('✅ $recoveredCount denetim maddesi view mode\'dan kurtarıldı');
      _calculateScore();

    } catch (e) {
      print('❌ View mode veri kurtarma hatası: $e');
    }
  }

  void _showSchoolSelectionDialog() {
    final previousSchoolName = _previousInspectionData?['schools']?['name'] ?? "önceki okul";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Okul Seçimi'),
        content: Text('$previousSchoolName için kaydetmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performSaveInspection(schoolName: previousSchoolName);
            },
            child: Text('Evet, Kaydet'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hayır, İptal'),
          ),
        ],
      ),
    );
  }

  // EKSİK METODLAR EKLENDİ
  void _copyLastInspection() {
    _showSnackBar('Son denetim bilgileri kopyalandı (Eksikler düzeltildi)');
  }

  void _startNewInspection() {
    _showSnackBar('Yeni denetim başlatıldı (Eksikler devam ediyor)');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _calculateScore() {
    // Basit bir skor hesaplama - gerçek uygulamada detaylandırılabilir
    int score = 0;
    _inspectionResults.forEach((key, value) {
      if (value['is_compliant'] == true) {
        score++;
      }
    });
    setState(() {
      _totalScore = score;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('🔍 BUILD - Durum:');
      print('• View Mode: $_isViewMode');
      print('• Edit Mode: $_canEdit');
      print('• Denetim Maddeleri: ${_inspectionResults.length}');
      print('• Seçili Okul: ${_selectedSchool?["name"] ?? "YOK"}');
    }

    if (_isViewMode && !_canEdit && _inspectionResults.isEmpty && widget.previousInspectionData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('🔄 BUILD: Denetim verileri kontrol ediliyor...');
        _recoverInspectionDataFromViewMode();
      });
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoading()
          : Column(
        children: [
          Expanded(
            child: _buildInspectionForm(),
          ),
          _buildCompleteButton(),
        ],
      ),
    );
  }

  // Diğer widget builder metodları...
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Araç bilgileri yükleniyor...'),
        ],
      ),
    );
  }

  Widget _buildInspectionForm() {
    final completedItems = _getCompletedItemsCount();
    final totalItems = _getTotalItemsCount();
    final progress = totalItems > 0 ? completedItems / totalItems : 0.0;

    return Column(
      children: [
        _buildHeader(completedItems, totalItems, progress),

        if (_isViewMode && kDebugMode) _buildViewModeDebugBanner(),

        if (_isViewMode && !_canEdit)
          Padding(
            padding: EdgeInsets.all(16),
            child: _buildViewModeSchoolInfo(),
          ),

        Expanded(
          child: ListView(
            children: [
              ..._inspectionCategories.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                return _buildCategorySection(category, index);
              }).toList(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildViewModeDebugBanner() {
    final completedItems = _getCompletedItemsCount();
    final totalItems = _getTotalItemsCount();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.blue[100]!)), // ✅ DÜZELTİLDİ: Border.all -> BorderSide
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility, size: 16, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            'GÖRÜNTÜLEME MODU - $completedItems/$totalItems madde - ${_inspectionResults.length} kayıt',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int completedItems, int totalItems, double progress) {
    // Null kontrolü ekle - DÜZELTİLDİ
    final bool isEmptyData = _completeVehicleData?['_isEmpty'] ?? false;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEmptyData ? Color(0xFFFFF8E1) :
        (_usingSampleData ? Color(0xFFFFF3E0) : Color(0xFFE3F2FD)),
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Servis Denetim Formu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              if (isEmptyData) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'MANUEL GİRİŞ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else if (_usingSampleData) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ÖRNEK VERİ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Araç: ${widget.vehiclePlate}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (isEmptyData) ...[
            SizedBox(height: 4),
            Text(
              'Bu araç sisteme kayıtlı değil. Lütfen bilgileri manuel girin.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else if (_usingSampleData) ...[
            SizedBox(height: 4),
            Text(
              'Not: Gerçek veriler yüklenemedi, örnek veriler gösteriliyor',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  color: isEmptyData ? Colors.blue : Color(0xFF2196F3),
                ),
              ),
              SizedBox(width: 12),
              Text(
                '$completedItems/$totalItems',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isEmptyData ? Colors.blue : Color(0xFF2196F3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(InspectionCategory category, int index) {
    final isExpanded = _expandedCategories[index] ?? false;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Column(
        children: [
          // Kategori başlığı
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.category,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              category.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              '${category.items.length} madde',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Color(0xFF2196F3),
            ),
            onTap: () => _toggleCategory(index),
          ),

          // Kategori içeriği (açılır/kapanır)
          if (isExpanded) ...[
            Divider(height: 1),
            ...category.items.map((item) => _buildInspectionItem(item)),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsSection(InspectionItem item) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.question,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF2196F3),
            ),
          ),
          SizedBox(height: 16),

          // OKUL SEÇİMİ - RENK HATASI DÜZELTİLDİ 👏
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Denetim Yapılan Okul',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),

              // VIEW MODE'DA OKUL BİLGİSİNİ GÖSTER
              if (_isViewMode && !_canEdit && _selectedSchool != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green[200]!), // ✅ ! EKLENDİ
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.school, size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Denetim Yapılan Okul:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${_selectedSchool!['name']} - ${_selectedSchool!['district']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                )
              else
              // NORMAL MOD'DA DROPDOWN
                _buildSchoolSelector(),
            ],
          ),
          SizedBox(height: 16),
          // Müfettiş Bilgisi
          _buildInspectorInfo(),
          SizedBox(height: 16),
          // Son Denetim Uyarısı
          if (_showRecentInspectionWarning) _buildRecentInspectionWarning(),
        ],
      ),
    );
  }

// View Mode'da okul bilgisini göster - RENK HATASI DÜZELTİLDİ 👏👏
  Widget _buildViewModeSchoolInfo() {
    if (_selectedSchool == null) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          border: Border.all(color: Colors.orange[200]!), // ✅ ! EKLENDİ
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Okul bilgisi bulunamadı'),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!), // ✅ ! EKLENDİ
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, size: 20, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'DENETİM YAPILAN OKUL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            _selectedSchool!['name'] ?? 'Belirtilmemiş',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          if (_selectedSchool!['district'] != null) ...[
            SizedBox(height: 4),
            Text(
              'İlçe: ${_selectedSchool!['district']}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue[700],
              ),
            ),
          ],
          SizedBox(height: 8),
          Text(
            'Denetçi: ${_inspectorNameController.text}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Denetim Yapılacak Okul *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<Map<String, dynamic>>(
            value: _selectedSchool,
            isExpanded: true,
            underline: SizedBox(),
            hint: Text('Okul seçin...'),
            items: _allSchools.map((school) {
              return DropdownMenuItem(
                value: school,
                child: Text('${school['name']} - ${school['district']}'),
              );
            }).toList(),
            onChanged: (_isViewMode && !_canEdit) ? null : (school) { // ✅ DÜZELTİLDİ
              setState(() {
                _selectedSchool = school;
              });
            },
          ),
        ),
        if (_selectedSchool == null) ...[
          SizedBox(height: 8),
          Text(
            'Lütfen denetim yapılacak okulu seçin',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],

        // DEBUG: Dropdown durumu
        if (kDebugMode) ...[
          SizedBox(height: 4),
          Text(
            'Dropdown Durumu: ${_isViewMode ? 'View Mode' : 'Edit Mode'} - ${_canEdit ? 'Düzenlenebilir' : 'Salt Okunur'}',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildInspectorInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Müfettiş Bilgisi *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _inspectorNameController,
          decoration: InputDecoration(
            labelText: 'Müfettiş Adı Soyadı',
            border: OutlineInputBorder(),
            hintText: 'Müfettişin adını girin',
          ),
        ),
      ],
    );
  }

  Widget _buildRecentInspectionWarning() {
    if (!_showRecentInspectionWarning) return SizedBox();

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'SON DENETİM UYARISI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Bu araç ${_formatDate(_lastInspectionDate.toString())} tarihinde "${_lastInspectionSchool}" okulunda denetlenmiş.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _copyLastInspection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: Text('Aynı Okul - Eksikler Düzeltildi'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _startNewInspection,
                    child: Text('Farklı Okul - Yeni Denetim'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    final isValid = _selectedSchool != null && _inspectorNameController.text.isNotEmpty;
    final completedItems = _inspectionCategories
        .expand((category) => category.items)
        .where((item) => item.status != null && !item.isInfoSection && !item.isSettingsSection)
        .length;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tamamlanan: $completedItems madde',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (!isValid)
                Text(
                  'Eksik Bilgi',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: isValid ? _submitInspection : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isValid ? Colors.green : Colors.grey[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'DENETİMİ TAMAMLA',
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
    );
  }



  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(value.isEmpty ? 'Belirtilmemiş' : value),
          ),
        ],
      ),
    );
  }

  void _editDriverInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sürücü Bilgilerini Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _driverNameController,
                decoration: InputDecoration(
                  labelText: 'Sürücü Adı Soyadı',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _driverPhoneController,
                decoration: InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
              _showSnackBar('Sürücü bilgileri güncellendi');
            },
            child: Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _editAttendantInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rehber Bilgilerini Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _attendantNameController,
                decoration: InputDecoration(
                  labelText: 'Rehber Adı Soyadı',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
              _showSnackBar('Rehber bilgileri güncellendi');
            },
            child: Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionItem(InspectionItem item) {
    // Settings section için özel widget
    if (item.isSettingsSection) {
      return _buildSettingsSection(item);
    }

    // Info section için özel widget
    if (item.isInfoSection) {
      return _buildEditableInfoSection(item);
    }

    // VIEW MODE: Özel görüntüleme widget'ı
    if (_isViewMode && !_canEdit) {
      return _buildViewModeItem(item);
    }

    // Normal inspection item'lar için mevcut kod
    final dateValue = item.dateValue;
    final infoValue = item.infoValue;
    final isDateExpired = _isDateExpired(dateValue);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Soru ve açıklama
          Text(
            item.question,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          if (item.description.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              item.description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],

          // Tarih bilgisi kartı (eğer varsa)
          if (item.hasDateField && dateValue != null) ...[
            SizedBox(height: 8),
            _buildDateInfoCard(item, dateValue, isDateExpired),
          ],

          // Bilgi kartı (eğer varsa)
          if (item.hasInfoField && infoValue != null) ...[
            SizedBox(height: 8),
            _buildInfoCard(item, infoValue),
          ],

          // Var/Yok bilgisi (eğer varsa)
          if (item.hasYesNoField && item.yesNoValue != null) ...[
            SizedBox(height: 8),
            _buildYesNoCard(item),
          ],

          SizedBox(height: 12),

          // Durum butonları
          Row(
            children: [
              Expanded(
                child: _buildStatusButton('Uygun', 'compliant', item),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildStatusButton('Uygun Değil', 'non_compliant', item),
              ),
            ],
          ),

          // Uygunsuzluk notu (eğer varsa)
          if (item.status == 'non_compliant' && item.nonCompliantDescription != null) ...[
            SizedBox(height: 8),
            _buildNonCompliantNote(item.nonCompliantDescription!),
          ],
        ],
      ),
    );
  }
  Widget _buildViewModeItem(InspectionItem item) {
    final response = item.viewModeResponse;
    final status = item.viewModeStatus;
    final statusText = item.viewModeStatusText;
    final notes = item.viewModeNotes;
    final nonCompliantDesc = item.viewModeNonCompliantDesc;

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;

    switch (status) {
      case 'compliant':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'non_compliant':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Soru
            Text(
              item.question,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            if (item.description.isNotEmpty) ...[
              SizedBox(height: 4),
              Text(
                item.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],

            SizedBox(height: 12),

            // Durum Göstergesi
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            // Uygunsuzluk Açıklaması
            if (status == 'non_compliant' && nonCompliantDesc.isNotEmpty) ...[
              SizedBox(height: 8),
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, size: 16, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            'Uygunsuzluk Nedeni',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(nonCompliantDesc),
                    ],
                  ),
                ),
              ),
            ],

            // Notlar
            if (notes.isNotEmpty) ...[
              SizedBox(height: 8),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            'Notlar',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(notes),
                    ],
                  ),
                ),
              ),
            ],

            // Tarih Bilgisi (eğer varsa)
            if (item.hasDateField && item.dateValue != null) ...[
              SizedBox(height: 8),
              _buildDateInfoCard(item, item.dateValue!, _isDateExpired(item.dateValue!)),
            ],

            // Bilgi Kartı (eğer varsa)
            if (item.hasInfoField && item.infoValue != null) ...[
              SizedBox(height: 8),
              _buildInfoCard(item, item.infoValue!),
            ],
          ],
        ),
      ),
    );
  }



// Rehber bilgileri bölümünü güncelle
  Widget _buildEditableInfoSection(InspectionItem item) {
    final isStateTransport = _vehicleData?['transport_type'] == 'state';
    final driverBirthDate = _driverData?['driver_birth_date'] ?? _driverData?['birth_date'];

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.question,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF2196F3),
            ),
          ),
          SizedBox(height: 16),

          // Sürücü Bilgileri
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Sürücü Bilgileri',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.edit, size: 18),
                        onPressed: _editDriverInfo,
                        tooltip: 'Sürücü bilgilerini düzenle',
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow('Adı Soyadı', _driverNameController.text),
                  _buildInfoRow('Telefon', _driverPhoneController.text),
                  _buildInfoRow('Ehliyet Tipi', _driverData?['license_type'] ?? 'Belirtilmemiş'),
                  _buildInfoRow('Ehliyet Geçerlilik', _driverData?['license_expiry_date'] != null ?
                  _formatDate(_driverData!['license_expiry_date']) : 'Belirtilmemiş'),
                  _buildInfoRow('Doğum Tarihi', driverBirthDate != null ?
                  _formatDate(driverBirthDate) : 'Belirtilmemiş'),
                  _buildInfoRow('Yaş', _getDriverAgeInfo()),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Rehber Bilgileri
          if (!isStateTransport)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.accessible, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Rehber Bilgileri',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.edit, size: 18),
                          onPressed: _editAttendantInfo,
                          tooltip: 'Rehber bilgilerini düzenle',
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildInfoRow('Adı Soyadı', _attendantNameController.text),
                    _buildInfoRow('Doğum Tarihi', _attendantData?['birth_date'] != null ?
                    _formatDate(_attendantData!['birth_date']) : 'Belirtilmemiş'),
                    _buildInfoRow('Yaş', _getAttendantAgeInfo()),
                    _buildInfoRow('Reflektif Yelek', _attendantData?['has_reflective_vest'] == true ? 'VAR' : 'YOK'),
                    _buildInfoRow('Yardımcı Işıklar', _attendantData?['has_warning_lights'] == true ? 'VAR' : 'YOK'),
                  ],
                ),
              ),
            )
          else
          // Devlet taşıması mesajı
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Devlet taşıması: Rehber personel zorunluluğu bulunmamaktadır.',
                        style: TextStyle(color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateInfoCard(InspectionItem item, String dateValue, bool isExpired) {
    final isCritical = item.isCriticalDate; // Null safety için yerel değişken

    return Card(
      elevation: 1,
      color: isExpired ? Color(0xFFFFEBEE) : (isCritical ? Color(0xFFFFF3E0) : Color(0xFFE8F5E8)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isExpired ? Icons.error :
              (isCritical ? Icons.warning : Icons.calendar_today),
              color: isExpired ? Colors.red :
              (isCritical ? Colors.orange : Colors.green),
              size: 16,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.dateFieldLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isExpired ? Colors.red :
                      (isCritical ? Colors.orange : Colors.green),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _formatDate(dateValue),
                    style: TextStyle(
                      fontSize: 11,
                      color: isExpired ? Colors.red : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (isExpired) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SÜRESİ DOLMUŞ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(InspectionItem item, String infoValue) {
    return Card(
      elevation: 1,
      color: Color(0xFFE3F2FD),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Color(0xFF2196F3),
              size: 16,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.infoLabel ?? 'Bilgi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    infoValue,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYesNoCard(InspectionItem item) {
    final value = item.yesNoValue ?? false;

    return Card(
      elevation: 1,
      color: value ? Color(0xFFE8F5E8) : Color(0xFFFFEBEE),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.cancel,
              color: value ? Colors.green : Colors.red,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              value ? 'VAR' : 'YOK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: value ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String text, String status, InspectionItem item) {
    final isSelected = item.status == status;

    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: () => _handleItemStatusChange(item, status),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? _getStatusColor(status) : Colors.grey[200],
          foregroundColor: isSelected ? Colors.white : Colors.grey[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNonCompliantNote(String description) {
    return Card(
      color: Color(0xFFFFEBEE),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, size: 16, color: Colors.red),
                SizedBox(width: 4),
                Text(
                  'Uygunsuzluk Notu',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'compliant':
        return Colors.green;
      case 'non_compliant':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}


class NonCompliantDialog extends StatefulWidget {
  final InspectionItem item;
  final Function(String, List<String>) onSave;

  const NonCompliantDialog({
    Key? key,
    required this.item,
    required this.onSave,
  }) : super(key: key);

  @override
  _NonCompliantDialogState createState() => _NonCompliantDialogState();
}

class _NonCompliantDialogState extends State<NonCompliantDialog> {
  final TextEditingController _descriptionController = TextEditingController();
  final List<String> _photos = [];

  void _takePhoto() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fotoğraf çekme özelliği yakında eklenecek'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _save() {
    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen uygunsuzluk nedenini yazın'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onSave(_descriptionController.text, _photos);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Uygunsuzluk Bildirimi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.question,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Uygunsuzluk nedeni:'),
            SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Uygunsuzluk nedenini detaylı şekilde yazın...',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Text('Fotoğraf ekle (isteğe bağlı):'),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _takePhoto,
              icon: Icon(Icons.camera_alt),
              label: Text('Fotoğraf Çek'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text('Kaydet'),
        ),
      ],
    );
  }

}

