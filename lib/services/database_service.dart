// database_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/utils/constants.dart';
import '/services/local_storage_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalStorageService _localStorage = LocalStorageService();

  String get baseUrl => Constants.supabaseUrl;

  static const String _supabaseUrl = 'https://zxhvyfbzhuvbcnuxsaxq.supabase.co';
  static const String _apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4aHZ5ZmJ6aHV2YmNudXhzYXhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2ODg5MzMsImV4cCI6MjA3NTI2NDkzM30.rFB-7LP_ccNWrPXIpfTuwAW9zdgRXeX0w79kra5P0uQ';

  static Map<String, String> get _headers =>
      {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'apikey': _apiKey,
        'Prefer': 'return=representation',
      };

  // MEB AĞI İÇİN GELİŞTİRİLMİŞ HTTP CLIENT
  static http.Client _createMebClient() {
    var ioClient = HttpClient();

    // MEB AĞINDA TÜM SSL SERTİFİKALARINI ATLA - GELİŞTİRİLMİŞ
    ioClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
      print('🔓 SSL ATLANDI: $host:$port - ${cert.subject}');
      return true; // TÜM sertifikaları kabul et
    };

    // DNS ve timeout ayarları
    ioClient.connectionTimeout = Duration(seconds: 25);
    ioClient.idleTimeout = Duration(seconds: 20);

    // DNS çözümleme için özel ayarlar
    ioClient.findProxy = (uri) {
      return 'DIRECT';
    };

    return IOClient(ioClient);
  }

// Akıllı bağlantı metodunu güncelleyelim:
  Future<http.Client> _getHttpClient() async {
    try {
      print('🔍 Ağ türü tespit ediliyor...');

      // Platform hatası için try-catch
      try {
        final mebClient = _createMebClient();

        // Basit bir test yap
        final testResponse = await mebClient.get(
          Uri.parse('$_supabaseUrl/rest/v1/vehicles?select=count&limit=1'),
          headers: _headers,
        ).timeout(Duration(seconds: 12));

        if (testResponse.statusCode == 200) {
          print('✅ MEB ağı tespit edildi, özel client kullanılıyor');
          return mebClient;
        } else {
          print('⚠️ MEB test başarısız, standart client');
          mebClient.close();
          return http.Client();
        }
      } catch (e) {
        // Platform._version veya SSL hatası
        if (e.toString().contains('Platform._version') ||
            e.toString().contains('Unsupported operation') ||
            e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
          print('🔄 Platform/SSL hatası, standart HTTP client kullanılıyor');
          return http.Client();
        }
        print('⚠️ MEB client test hatası: $e');
        return http.Client();
      }
    } catch (e) {
      print('❌ Ağ tespit hatası: $e');
      return http.Client();
    }
  }

  // Local storage'ı başlat

  Future<void> init() async {
  if (kIsWeb) {
  print('🌐 WEB: LocalStorage atlanıyor');
  return; // ❌ Web'de local storage'ı komple atla
  }
  await _localStorage.init();
  }


  // HYBRID METODLAR

  Future<List<Map<String, dynamic>>> getAllVehicles() async {
    if (kIsWeb) {
      // Web'de sadece HTTP/Supabase kullan
      return _getVehiclesWeb();
    }
    try {
      print('🚗 HYBRID: Tüm araçlar getiriliyor...');

      // ÖNCE HTTP DENEYELİM
      try {
        final client = await _getHttpClient();
        final response = await client.get(
          Uri.parse('$_supabaseUrl/rest/v1/vehicles?select=*'),
          headers: _headers,
        ).timeout(Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final vehicles = List<Map<String, dynamic>>.from(data);
          print('✅ HTTP getAllVehicles başarılı: ${vehicles.length} araç');

          // LOCAL'A KAYDET
          for (final vehicle in vehicles) {
            await _localStorage.saveVehicle(vehicle);
          }

          return vehicles;
        }
      } catch (e) {
        print('❌ HTTP getAllVehicles başarısız: $e');
      }

      // SONRA LOCAL'A BAK
      final localVehicles = await _localStorage.getVehicles();
      if (localVehicles.isNotEmpty) {
        print('✅ Local getAllVehicles: ${localVehicles.length} araç');
        return localVehicles;
      }

      // EN SON SUPABASE FALLBACK
      print('🔄 Supabase getAllVehicles fallback kullanılıyor');
      final response = await _supabase.from('vehicles').select().order('plate');
      final vehicles = List<Map<String, dynamic>>.from(response);

      // LOCAL'A KAYDET
      for (final vehicle in vehicles) {
        await _localStorage.saveVehicle(vehicle);
      }

      return vehicles;

    } catch (e) {
      print('❌ Tüm getAllVehicles yöntemleri başarısız: $e');
      return [];
    }
  }


  Future<List<Map<String, dynamic>>> _getVehiclesWeb() async {
    try {
      final client = await _getHttpClient();
      final response = await client.get(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?select=*'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print('❌ Web vehicles hatası: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDashboardInspections() async {
    try {
      print('📊 HYBRID: Dashboard denetimleri getiriliyor...');

      final client = await _getHttpClient();

      try {
        // HTTP ile dene
        final response = await client.get(
          Uri.parse('$_supabaseUrl/rest/v1/inspections?select=*&order=inspection_date.desc&limit=10'),
          headers: _headers,
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('✅ HTTP getDashboardInspections: ${data.length} denetim');

          // DEBUG: İlk denetimin okul bilgisini kontrol et
          if (data.isNotEmpty) {
            print('🔍 İLK DENETİM OKUL BİLGİSİ:');
            print('   school_name: ${data.first['school_name']}');
            print('   schools: ${data.first['schools']}');
          }

          return data.cast<Map<String, dynamic>>();
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        print('❌ HTTP getDashboardInspections başarısız, Supabase fallback: $e');

        // Supabase fallback
        final response = await _supabase
            .from('inspections')
            .select()
            .order('inspection_date', ascending: false)
            .limit(10);

        // DEBUG: İlk denetimin okul bilgisini kontrol et
        if (response.isNotEmpty) {
          print('🔍 SUPABASE İLK DENETİM OKUL BİLGİSİ:');
          print('   school_name: ${response.first['school_name']}');
          print('   schools: ${response.first['schools']}');
        }

        return response;
      }
    } catch (e) {
      print('❌ Tüm bağlantı yöntemleri başarısız: $e');
      return [];
    }
  }



// getDashboardInspectionsWithDetails metodunu da güncelleyin:

  Future<List<Map<String, dynamic>>> getDashboardInspectionsWithDetails() async {
    try {
      print('🔄 HYBRID: Detaylı denetimler getiriliyor...');

      // İLİŞKİ OLMADAN doğrudan al
      final response = await _supabase
          .from('inspections')
          .select()
          .order('inspection_date', ascending: false)
          .limit(5);

      print('✅ Detaylı denetimler: ${response.length} kayıt');

      // Her denetim için ek bilgileri getir
      final enhancedInspections = await Future.wait(
          response.map((inspection) async {
            try {
              // Araç bilgilerini getir
              if (inspection['vehicle_plate'] != null) {
                final vehicleResponse = await _supabase
                    .from('vehicles')
                    .select('model, driver_name')
                    .eq('plate', inspection['vehicle_plate'])
                    .maybeSingle();

                inspection['vehicle_model'] = vehicleResponse?['model'];
                inspection['driver_name'] = vehicleResponse?['driver_name'];
              }

              // Okul bilgilerini getir (eğer school_name varsa)
              if (inspection['school_name'] != null) {
                inspection['schools'] = {
                  'name': inspection['school_name'],
                  'district': inspection['school_district'] ?? ''
                };
              }

              return inspection;
            } catch (e) {
              print('⚠️ Detay getirme hatası: $e');
              return inspection;
            }
          })
      );

      return enhancedInspections.cast<Map<String, dynamic>>();

    } catch (e) {
      print('❌ Detaylı denetim hatası: $e');

      // Basit sorgu ile deneyelim
      try {
        final fallback = await _supabase
            .from('inspections')
            .select()
            .order('inspection_date', ascending: false)
            .limit(5);

        return fallback.cast<Map<String, dynamic>>();
      } catch (fallbackError) {
        print('❌ Fallback de başarısız: $fallbackError');
        return [];
      }
    }
  }

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    try {
      print('🔍 Database\'de kullanıcı aranıyor: $email');

      // Direkt Supabase kullan - HTTP'yi atla
      final response = await _supabase
          .from('app_users')
          .select('*, schools(name, district)')
          .eq('email', email.toLowerCase())
          .maybeSingle();

      if (response != null) {
        print('✅ Supabase kullanıcı bulundu: $email');
        return response;
      } else {
        print('❌ Kullanıcı bulunamadı: $email');
        return null;
      }
    } catch (e) {
      print('❌ Kullanıcı arama hatası: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getCompleteVehicleData(String plate) async {
    http.Client? client;

    try {
      final normalizedPlate = _normalizePlate(plate);
      print('🔍 HYBRID: Tam araç verisi aranıyor: "$plate" -> "$normalizedPlate"');
      client = await _getHttpClient();

      final vehicleResponse = await client.get(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?plate=eq.$normalizedPlate&select=*'),
        headers: _headers,
      ).timeout(Duration(seconds: 15));

      if (vehicleResponse.statusCode == 200) {
        final List<dynamic> vehicleData = json.decode(vehicleResponse.body);
        if (vehicleData.isEmpty) {
          print('❌ HTTP: Araç bulunamadı');
          return _createEmptyVehicleData(plate);
        }

        final vehicle = vehicleData[0];
        final vehicleId = vehicle['id'];
        print('✅ HTTP: Araç bulundu: $vehicleId');

        // FUTURE.WAIT TİP SORUNUNU ÇÖZELİM
        final results = await Future.wait<dynamic>([
          _getDriverData(client, vehicleId),
          _getAttendantData(client, vehicleId),
          _getDocumentsData(client, vehicleId),
          getVehicleSchools(vehicleId), // Direkt metod çağır
        ], eagerError: true);

        return {
          'vehicle': vehicle,
          'driver': results[0] ?? {},
          'attendant': results[1] ?? {},
          'documents': results[2] ?? {},
          'schools': results[3] ?? [],
          '_isSample': false,
          '_isEmpty': false,
        };
      } else {
        throw Exception('HTTP ${vehicleResponse.statusCode}');
      }
    } catch (e) {
      print('❌ HTTP getCompleteVehicleData başarısız, Supabase fallback: $e');

      try {
        return await _getCompleteVehicleDataWithSupabase(plate);
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        return _createEmptyVehicleData(plate);
      }
    } finally {
      client?.close();
    }
  }

  Future<List<dynamic>> _getVehicleSchoolsFallback(dynamic vehicleId) async {
    try {
      // Önce local'dan dene
      final localVehicles = await _localStorage.getVehicles();
      final vehicle = localVehicles.firstWhere(
            (v) => v['id'] == vehicleId,
        orElse: () => {},
      );

      if (vehicle.isNotEmpty && vehicle['school_ids'] != null) {
        final schoolIds = List<String>.from(vehicle['school_ids']);
        final allSchools = await _localStorage.getSchools();
        final schools = allSchools.where((s) => schoolIds.contains(s['id']?.toString())).toList();

        return schools.map((school) => {
          'schools': school
        }).toList();
      }

      return [];
    } catch (e) {
      print('❌ Local vehicle schools hatası: $e');
      return [];
    }
  }

  // HTTP Yardımcı Metodları
  Future<Map<String, dynamic>> _getDriverData(http.Client client,
      dynamic vehicleId) async {
    try {
      final response = await client.get(
        Uri.parse(
            '$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId&select=driver_name,driver_phone,driver_license_type,driver_license_expiry,driver_birth_date,src_certificate_expiry'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final vehicle = data[0];
          return {
            'full_name': vehicle['driver_name'],
            'phone': vehicle['driver_phone'],
            'license_type': vehicle['driver_license_type'],
            'license_expiry_date': vehicle['driver_license_expiry'],
            'birth_date': vehicle['driver_birth_date'],
            'src_certificate_expiry': vehicle['src_certificate_expiry'],
          };
        }
      }
      return {};
    } catch (e) {
      print('❌ HTTP _getDriverData hatası: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getAttendantData(http.Client client,
      dynamic vehicleId) async {
    try {
      final response = await client.get(
        Uri.parse(
            '$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId&select=attendant_name,attendant_birth_date,has_reflective_vest,has_warning_lights'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final vehicle = data[0];
          return {
            'full_name': vehicle['attendant_name'],
            'birth_date': vehicle['attendant_birth_date'],
            'has_reflective_vest': vehicle['has_reflective_vest'] ?? false,
            'has_warning_lights': vehicle['has_warning_lights'] ?? false,
          };
        }
      }
      return {};
    } catch (e) {
      print('❌ HTTP _getAttendantData hatası: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getDocumentsData(http.Client client,
      dynamic vehicleId) async {
    try {
      final response = await client.get(
        Uri.parse(
            '$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId&select=insurance_expiry,inspection_expiry,route_permit_expiry,g_certificate_expiry,fire_extinguisher_expiry'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final vehicle = data[0];
          return {
            'insurance_expiry': vehicle['insurance_expiry'],
            'inspection_expiry': vehicle['inspection_expiry'],
            'route_permission_expiry': vehicle['route_permit_expiry'],
            'g_certificate_expiry': vehicle['g_certificate_expiry'],
            'fire_extinguisher_expiry': vehicle['fire_extinguisher_expiry'],
          };
        }
      }
      return {};
    } catch (e) {
      print('❌ HTTP _getDocumentsData hatası: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getVehicleSchools(int vehicleId) async {
    try {
      print('🏫 HYBRID: Araç okulları getiriliyor: $vehicleId');

      // 1. ÖNCE HTTP DENEYELİM
      try {
        final client = await _getHttpClient();
        final response = await client.get(
          Uri.parse('$_supabaseUrl/rest/v1/vehicle_schools?vehicle_id=eq.$vehicleId&select=*,schools(name,district)'),
          headers: _headers,
        ).timeout(Duration(seconds: 15));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('✅ HTTP getVehicleSchools başarılı: ${data.length} okul');
          return data.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        print('❌ HTTP getVehicleSchools başarısız: $e');
      }

      // 2. SONRA SUPABASE FALLBACK
      try {
        final response = await _supabase
            .from('vehicle_schools')
            .select('*, schools(name, district)')
            .eq('vehicle_id', vehicleId);

        print('✅ Supabase getVehicleSchools fallback: ${response.length} okul');
        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        print('❌ Supabase getVehicleSchools başarısız: $e');
      }

      // 3. EN SON LOCAL FALLBACK
      final localVehicles = await _localStorage.getVehicles();
      final vehicle = localVehicles.firstWhere(
            (v) => v['id'] == vehicleId,
        orElse: () => {},
      );

      if (vehicle.isNotEmpty && vehicle['school_ids'] != null) {
        final schoolIds = List<String>.from(vehicle['school_ids']);
        final allSchools = await _localStorage.getSchools();
        final schools = allSchools.where((s) => schoolIds.contains(s['id']?.toString())).toList();

        return schools.map((school) => {
          'schools': school
        }).toList();
      }

      return [];
    } catch (e) {
      print('❌ Tüm getVehicleSchools yöntemleri başarısız: $e');
      return [];
    }
  }

  // Supabase Fallback Metodları
  Future<Map<String, dynamic>> _getCompleteVehicleDataWithSupabase(
      String plate) async {
    try {
      final normalizedPlate = _normalizePlate(plate);
      print('🔄 Supabase: Tam araç verisi aranıyor: $normalizedPlate');

      final vehicleResponse = await _supabase
          .from('vehicles')
          .select()
          .eq('plate', normalizedPlate)
          .maybeSingle();

      if (vehicleResponse == null) {
        print('❌ Supabase: Araç bulunamadı');
        return _createEmptyVehicleData(plate);
      }

      final vehicleId = vehicleResponse['id'];
      print('✅ Supabase: Araç bulundu: $vehicleId');

      final results = await Future.wait([
        getDriverByVehicleId(vehicleId),
        getAttendantByVehicleId(vehicleId),
        getDocumentsByVehicleId(vehicleId),
        getVehicleSchools(vehicleId),
      ], eagerError: true);

      return {
        'vehicle': vehicleResponse,
        'driver': results[0] ?? {},
        'attendant': results[1] ?? {},
        'documents': results[2] ?? {},
        'schools': results[3] ?? [],
        '_isSample': false,
        '_isEmpty': false,
      };
    } catch (e) {
      print('❌ Supabase getCompleteVehicleData hatası: $e');
      return _createEmptyVehicleData(plate);
    }
  }

  // DİĞER METODLAR



  Future<List<Map<String, dynamic>>> getUserVehicles(String userId) async {
    http.Client? client;

    try {
      print('🔍 HYBRID: Kullanıcı araçları getiriliyor');
      client = await _getHttpClient();

      final response = await client.get(
        Uri.parse(
            '$_supabaseUrl/rest/v1/vehicles?select=*&created_by=eq.$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ HTTP getUserVehicles başarılı: ${data.length} araç');
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP getUserVehicles başarısız, Supabase fallback: $e');

      try {
        final response = await _supabase
            .from('vehicles')
            .select('*')
            .eq('created_by', userId)
            .order('created_at', ascending: false);

        print('✅ Supabase getUserVehicles fallback: ${response.length} araç');
        return response;
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        return [];
      }
    } finally {
      client?.close();
    }
  }

  Future<void> approveVehicle(String vehicleId, String approvedBy) async {
    http.Client? client;

    try {
      print('✅ HYBRID: Araç onaylanıyor: $vehicleId');
      client = _createMebClient();

      final response = await client.patch(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId'),
        headers: _headers,
        body: json.encode({
          'is_approved': true,
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'rejection_reason': null,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP approveVehicle başarılı: $vehicleId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP approveVehicle başarısız, Supabase fallback: $e');

      try {
        await _supabase
            .from('vehicles')
            .update({
          'is_approved': true,
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'rejection_reason': null,
        }).eq('id', vehicleId);
        print('✅ Supabase approveVehicle fallback: $vehicleId');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

  Future<void> rejectVehicle(String vehicleId, String rejectedBy,
      String reason) async {
    http.Client? client;

    try {
      print('❌🔄 HYBRID: Araç reddediliyor: $vehicleId');
      client = _createMebClient();

      final updateData = {
        'is_approved': false,
        'rejection_reason': reason,
        'approved_by': rejectedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await client.patch(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId'),
        headers: _headers,
        body: json.encode(updateData),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP rejectVehicle başarılı: $vehicleId');
        await _checkVehicleStatus(vehicleId);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP rejectVehicle başarısız, Supabase fallback: $e');

      try {
        await _supabase
            .from('vehicles')
            .update({
          'is_approved': false,
          'rejection_reason': reason,
          'approved_by': rejectedBy,
          'approved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', vehicleId);
        print('✅ Supabase rejectVehicle fallback: $vehicleId');
        await _checkVehicleStatus(vehicleId);
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

  Future<void> _checkVehicleStatus(String vehicleId) async {
    try {
      print('🔍 Aracın güncel durumu kontrol ediliyor: $vehicleId');

      final client = _createMebClient();
      final response = await client.get(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId&select=*'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final vehicle = data[0];
          print('🔍 ARACIN GÜNCEL DURUMU:');
          print('🔍 Plaka: ${vehicle['plate']}');
          print('🔍 is_approved: ${vehicle['is_approved']}');
          print('🔍 rejection_reason: ${vehicle['rejection_reason']}');
        }
      }
      client.close();
    } catch (e) {
      print('❌ Durum kontrol hatası: $e');
    }
  }

  Future<void> unapproveVehicle(String vehicleId, String userId) async {
    http.Client? client;

    try {
      print('↩️ HYBRID: Onay geri alınıyor: $vehicleId');
      client = _createMebClient();

      final response = await client.patch(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId'),
        headers: _headers,
        body: json.encode({
          'is_approved': false,
          'approved_by': null,
          'approved_at': null,
          'rejection_reason': null,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP unapproveVehicle başarılı: $vehicleId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP unapproveVehicle başarısız, Supabase fallback: $e');

      try {
        await _supabase
            .from('vehicles')
            .update({
          'is_approved': false,
          'approved_by': null,
          'approved_at': null,
          'rejection_reason': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', vehicleId);
        print('✅ Supabase unapproveVehicle fallback: $vehicleId');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

  Future<bool> checkPlateExists(String plate) async {
    http.Client? client;

    try {
      print('🔍 HYBRID: Plaka kontrol ediliyor: $plate');
      client = _createMebClient();

      final formattedPlate = plate.toUpperCase().trim();
      final response = await client.get(
        Uri.parse(
            '$_supabaseUrl/rest/v1/vehicles?plate=eq.$formattedPlate&select=plate'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final exists = data.isNotEmpty;
        print('🔍 Plaka kontrol sonucu: $exists');
        return exists;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP plaka kontrol başarısız, Supabase fallback: $e');

      try {
        final formattedPlate = plate.toUpperCase().trim();
        final response = await _supabase
            .from('vehicles')
            .select('plate')
            .eq('plate', formattedPlate);

        final exists = response.isNotEmpty;
        print('🔍 Supabase plaka kontrol sonucu: $exists');
        return exists;
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        return false;
      }
    } finally {
      client?.close();
    }
  }

  Future<Map<String, dynamic>> createVehicle({
    required String plate,
    required String model,
    required int modelYear,
    required int capacity,
    required String driverName,
    required String transportType,
    String? driverPhone,
    DateTime? driverLicenseExpiry,
    DateTime? srcCertificateExpiry,
    DateTime? insuranceExpiry,
    DateTime? inspectionExpiry,
    DateTime? routePermitExpiry,
    DateTime? gCertificateExpiry,
    String? driverPhotoUrl,
    List<String>? schoolIds,
  }) async {
    final plateExists = await checkPlateExists(plate);
    if (plateExists) {
      throw Exception(
          'Bu plakaya sahip bir araç zaten mevcut: ${plate.toUpperCase()}');
    }

    http.Client? client;

    try {
      print('🚗 HYBRID: Araç oluşturuluyor: $plate');
      client = _createMebClient();

      final vehicleData = {
        'plate': plate.toUpperCase().trim(),
        'model': model,
        'model_year': modelYear,
        'capacity': capacity,
        'driver_name': driverName,
        'driver_phone': driverPhone,
        'transport_type': transportType,
        'driver_license_expiry': driverLicenseExpiry?.toIso8601String(),
        'src_certificate_expiry': srcCertificateExpiry?.toIso8601String(),
        'insurance_expiry': insuranceExpiry?.toIso8601String(),
        'inspection_expiry': inspectionExpiry?.toIso8601String(),
        'route_permit_expiry': routePermitExpiry?.toIso8601String(),
        'g_certificate_expiry': gCertificateExpiry?.toIso8601String(),
        'driver_photo_url': driverPhotoUrl,
        'is_approved': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final vehicleResponse = await client.post(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles'),
        headers: _headers,
        body: json.encode(vehicleData),
      );

      if (vehicleResponse.statusCode == 201) {
        final List<dynamic> vehicleData = json.decode(vehicleResponse.body);
        final vehicle = vehicleData[0] as Map<String, dynamic>;
        final vehicleId = vehicle['id'];

        print('✅ HTTP createVehicle başarılı: $plate - ID: $vehicleId');

        if (schoolIds != null && schoolIds.isNotEmpty) {
          for (final schoolId in schoolIds) {
            await client.post(
              Uri.parse('$_supabaseUrl/rest/v1/vehicle_schools'),
              headers: _headers,
              body: json.encode({
                'vehicle_id': vehicleId,
                'school_id': int.parse(schoolId),
                'created_at': DateTime.now().toIso8601String(),
              }),
            );
          }
          print('✅ HTTP vehicle_schools başarılı: ${schoolIds
              .length} okul eklendi');
        }

        return vehicle;
      } else {
        throw Exception(
            'HTTP ${vehicleResponse.statusCode}: ${vehicleResponse.body}');
      }
    } catch (e) {
      print('❌ HTTP createVehicle başarısız, Supabase fallback: $e');

      try {
        return await _createVehicleWithSupabase(
          plate: plate,
          model: model,
          modelYear: modelYear,
          capacity: capacity,
          driverName: driverName,
          transportType: transportType,
          driverPhone: driverPhone,
          driverLicenseExpiry: driverLicenseExpiry,
          srcCertificateExpiry: srcCertificateExpiry,
          insuranceExpiry: insuranceExpiry,
          inspectionExpiry: inspectionExpiry,
          routePermitExpiry: routePermitExpiry,
          gCertificateExpiry: gCertificateExpiry,
          driverPhotoUrl: driverPhotoUrl,
          schoolIds: schoolIds,
        );
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

  Future<Map<String, dynamic>> _createVehicleWithSupabase({
    required String plate,
    required String model,
    required int modelYear,
    required int capacity,
    required String driverName,
    required String transportType,
    String? driverPhone,
    DateTime? driverLicenseExpiry,
    DateTime? srcCertificateExpiry,
    DateTime? insuranceExpiry,
    DateTime? inspectionExpiry,
    DateTime? routePermitExpiry,
    DateTime? gCertificateExpiry,
    String? driverPhotoUrl,
    List<String>? schoolIds,
  }) async {
    final vehicle = await _supabase
        .from('vehicles')
        .insert({
      'plate': plate.toUpperCase(),
      'model': model,
      'model_year': modelYear,
      'capacity': capacity,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'transport_type': transportType,
      'driver_license_expiry': driverLicenseExpiry?.toIso8601String(),
      'src_certificate_expiry': srcCertificateExpiry?.toIso8601String(),
      'insurance_expiry': insuranceExpiry?.toIso8601String(),
      'inspection_expiry': inspectionExpiry?.toIso8601String(),
      'route_permit_expiry': routePermitExpiry?.toIso8601String(),
      'g_certificate_expiry': gCertificateExpiry?.toIso8601String(),
      'driver_photo_url': driverPhotoUrl,
      'is_approved': false,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    if (schoolIds != null && schoolIds.isNotEmpty) {
      for (final schoolId in schoolIds) {
        await _supabase
            .from('vehicle_schools')
            .insert({
          'vehicle_id': vehicle['id'],
          'school_id': int.parse(schoolId),
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }

    print('✅ Supabase createVehicle fallback: $plate');
    return vehicle;
  }

  Future<void> debugVehicleTables(int vehicleId) async {
    try {
      print('🔍 DEBUG: Vehicle ID $vehicleId tablo kontrolleri...');

      final vehicleData = await _supabase
          .from('vehicles')
          .select('''
          id, plate,
          attendant_name,
          attendant_birth_date,
          has_reflective_vest,
          has_warning_lights,
          driver_name,
          driver_birth_date
        ''')
          .eq('id', vehicleId)
          .single();

      print('🚗 VEHICLES TABLOSU (HAM VERİ):');
      print('• attendant_name: ${vehicleData['attendant_name']}');
      print('• attendant_birth_date: ${vehicleData['attendant_birth_date']}');
      print('• has_reflective_vest: ${vehicleData['has_reflective_vest']}');
      print('• has_warning_lights: ${vehicleData['has_warning_lights']}');
      print('• driver_name: ${vehicleData['driver_name']}');
      print('• driver_birth_date: ${vehicleData['driver_birth_date']}');

      final driverData = await getDriverByVehicleId(vehicleId);
      print('• Sürücü - full_name: ${driverData?['full_name']}');

      final attendantData = await getAttendantByVehicleId(vehicleId);
      print('• Rehber - full_name: ${attendantData?['full_name']}');
    } catch (e) {
      print('❌ DEBUG hatası: $e');
    }
  }

  Future<void> saveDocuments(Map<String, dynamic> documentsData) async {
    try {
      final vehicleId = documentsData['vehicle_id'];

      try {
        final existingResponse = await _supabase
            .from('documents')
            .select()
            .eq('vehicle_id', vehicleId);

        if (existingResponse != null && existingResponse.isNotEmpty) {
          await _supabase
              .from('documents')
              .update(documentsData)
              .eq('vehicle_id', vehicleId);
        } else {
          await _supabase
              .from('documents')
              .insert(documentsData);
        }
      } catch (e) {
        print('Supabase belge kaydetme hatası: $e');
        throw e;
      }
    } catch (e) {
      print('Belge kaydetme hatası: $e');
      throw e;
    }
  }

  Future<void> updateVehicle(int vehicleId, Map<String, dynamic> data) async {
    try {
      await _supabase
          .from('vehicles')
          .update(data)
          .eq('id', vehicleId);
    } catch (e) {
      print('Araç güncelleme hatası: $e');
      throw e;
    }
  }

  Future<void> addVehicle(Map<String, dynamic> data) async {
    try {
      await _supabase
          .from('vehicles')
          .insert(data);
    } catch (e) {
      print('Araç ekleme hatası: $e');
      throw e;
    }
  }

  // DatabaseService - DEVAMI

  Future<void> createUser(Map<String, dynamic> userData) async {
    http.Client? client;

    try {
      print('🔄 HYBRID: Kullanıcı oluşturuluyor: ${userData['email']}');
      client = await _getHttpClient();

      final response = await client.post(
        Uri.parse('$_supabaseUrl/rest/v1/app_users'),
        headers: _headers,
        body: json.encode(userData),
      );

      if (response.statusCode == 201) {
        print('✅ HTTP createUser başarılı: ${userData['email']}');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP createUser başarısız, Supabase fallback: $e');

      try {
        await _supabase
            .from('app_users')
            .insert({
          'email': userData['email'],
          'full_name': userData['full_name'],
          'phone': userData['phone'],
          'user_type': userData['user_type'],
          'school_id': userData['school_id'],
          'is_active': userData['is_active'] ?? true,
          'department': userData['department'],
          'created_at': DateTime.now().toIso8601String(),
        });
        print('✅ Supabase createUser fallback: ${userData['email']}');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    http.Client? client;

    try {
      print('✏️ HYBRID: Kullanıcı güncelleniyor: $userId');
      client = await _getHttpClient();

      final String validUserId = _validateUserId(userId);

      final response = await client.patch(
        Uri.parse('$_supabaseUrl/rest/v1/app_users?id=eq.$validUserId'),
        headers: _headers,
        body: json.encode(updates),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP updateUser başarılı: $userId');
        return;
      } else {
        print('❌ HTTP updateUser hatası: ${response.statusCode} - ${response
            .body}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP updateUser başarısız, Supabase fallback: $e');

      try {
        final String validUserId = _validateUserId(userId);
        await _supabase
            .from('app_users')
            .update(updates)
            .eq('id', validUserId);
        print('✅ Supabase updateUser fallback: $userId');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');

        // Numeric fallback
        try {
          final int? numericId = int.tryParse(userId.toString());
          if (numericId != null) {
            await _supabase
                .from('app_users')
                .update(updates)
                .eq('id', numericId);
            print('✅ Supabase updateUser numeric fallback: $userId');
            return;
          }
        } catch (numericError) {
          print('❌ Numeric fallback da başarısız: $numericError');
        }
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

  Future<void> deleteUser(String userId) async {
    http.Client? client;

    try {
      print('🗑️ HYBRID: Kullanıcı siliniyor: $userId');
      client = await _getHttpClient();

      final String validUserId = _validateUserId(userId);

      final response = await client.delete(
        Uri.parse('$_supabaseUrl/rest/v1/app_users?id=eq.$validUserId'),
        headers: _headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP deleteUser başarılı: $userId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP deleteUser başarısız, Supabase fallback: $e');

      try {
        final String validUserId = _validateUserId(userId);
        await _supabase
            .from('app_users')
            .delete()
            .eq('id', validUserId);
        print('✅ Supabase deleteUser fallback: $userId');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

  Future<void> updateUserStatus(String userId, bool isActive) async {
    http.Client? client;

    try {
      print('🔧 HYBRID: Kullanıcı durumu güncelleniyor: $userId');
      client = await _getHttpClient();

      final response = await client.patch(
        Uri.parse('$_supabaseUrl/rest/v1/app_users?id=eq.${userId.toString()}'),
        headers: _headers,
        body: json.encode({
          'is_active': isActive,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP updateUserStatus başarılı: $userId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP updateUserStatus başarısız, Supabase fallback: $e');

      try {
        await _supabase
            .from('app_users')
            .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId.toString());
        print('✅ Supabase updateUserStatus fallback: $userId');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

  Future<List<Map<String, dynamic>>> getSchoolVehicles(String schoolId) async {
    http.Client? client;

    try {
      print('🚗 HYBRID: Okul araçları getiriliyor: $schoolId');
      client = await _getHttpClient();

      final response = await client.get(
        Uri.parse('$_supabaseUrl/rest/v1/vehicle_schools?school_id=eq.$schoolId&select=*,vehicles(*)'),
        headers: _headers,
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ HTTP getSchoolVehicles başarılı: ${data.length} araç');

        // Araç verilerini çıkar
        List<Map<String, dynamic>> vehicles = [];
        for (var item in data) {
          if (item['vehicles'] != null) {
            vehicles.add(item['vehicles']);
          }
        }
        return vehicles;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP getSchoolVehicles başarısız, Supabase fallback: $e');

      try {
        final response = await _supabase
            .from('vehicle_schools')
            .select('''
            vehicles (*)
          ''')
            .eq('school_id', schoolId);

        List<Map<String, dynamic>> vehicles = [];
        for (var item in response) {
          if (item['vehicles'] != null) {
            vehicles.add(item['vehicles']);
          }
        }

        print('✅ Supabase getSchoolVehicles fallback: ${vehicles.length} araç');
        return vehicles;
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        return [];
      }
    } finally {
      client?.close();
    }
  }

// OKUL İŞLEMLERİ - HYBRID
  Future<List<Map<String, dynamic>>> getSchools() async {
    http.Client? client;

    try {
      print('🏫 HYBRID: Okullar getiriliyor');
      client = await _getHttpClient();

      final response = await client.get(
        Uri.parse(
            '$_supabaseUrl/rest/v1/schools?select=name,district,id,address,is_active&order=name'),
        headers: _headers,
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ HTTP getSchools başarılı: ${data.length} okul');
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP getSchools başarısız, Supabase fallback: $e');

      try {
        final response = await _supabase
            .from('schools')
            .select('name, district, id, address, is_active')
            .order('name')
            .timeout(Duration(seconds: 10));

        print('✅ Supabase getSchools fallback: ${response.length} okul');
        return (response as List).cast<Map<String, dynamic>>();
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        return _getDemoSchools();
      }
    } finally {
      client?.close();
    }
  }

  Future<Map<String, dynamic>> createSchool({
    required String name,
    required String district,
    String? address,
  }) async {
    http.Client? client;

    try {
      print('🏫 HYBRID: Okul oluşturuluyor: $name');
      client = await _getHttpClient();

      final schoolData = {
        'name': name,
        'district': district,
        'address': address,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await client.post(
        Uri.parse('$_supabaseUrl/rest/v1/schools'),
        headers: _headers,
        body: json.encode(schoolData),
      );

      if (response.statusCode == 201) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ HTTP createSchool başarılı: $name');
        return data[0] as Map<String, dynamic>;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP createSchool başarısız, Supabase fallback: $e');

      try {
        final school = await _supabase
            .from('schools')
            .insert({
          'name': name,
          'district': district,
          'address': address,
          'created_at': DateTime.now().toIso8601String(),
        }).select().single();

        print('✅ Supabase createSchool fallback: $name');
        return school;
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

  Future<void> updateSchool(String schoolId,
      Map<String, dynamic> updateData) async {
    http.Client? client;

    try {
      print('✏️ HYBRID: Okul güncelleniyor: $schoolId');
      client = await _getHttpClient();

      final response = await client.patch(
        Uri.parse('$_supabaseUrl/rest/v1/schools?id=eq.${schoolId.toString()}'),
        headers: _headers,
        body: json.encode({
          ...updateData,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP updateSchool başarılı: $schoolId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP updateSchool başarısız, Supabase fallback: $e');

      try {
        await _supabase
            .from('schools')
            .update({
          ...updateData,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', schoolId.toString());
        print('✅ Supabase updateSchool fallback: $schoolId');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

  Future<void> deleteSchool(String schoolId) async {
    http.Client? client;

    try {
      print('🗑️ HYBRID: Okul siliniyor: $schoolId');
      client = await _getHttpClient();

      final response = await client.delete(
        Uri.parse('$_supabaseUrl/rest/v1/schools?id=eq.${schoolId.toString()}'),
        headers: _headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP deleteSchool başarılı: $schoolId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP deleteSchool başarısız, Supabase fallback: $e');

      try {
        await _supabase
            .from('schools')
            .delete()
            .eq('id', schoolId.toString());
        print('✅ Supabase deleteSchool fallback: $schoolId');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

// DENETİM İŞLEMLERİ - HYBRID
  Future<List<Map<String, dynamic>>> getInspectionItems() async {
    try {
      print('📋 HYBRID: Denetim maddeleri getiriliyor');

      // HARD-CODED denetim maddelerini döndür - database'e ihtiyaç yok
      final hardCodedItems = _getHardCodedInspectionItems();
      print('✅ Hard-coded denetim maddeleri yüklendi: ${hardCodedItems.length} madde');
      return hardCodedItems;

    } catch (e) {
      print('❌ Denetim maddeleri yükleme hatası: $e');
      return _getDefaultInspectionItems();
    }
  }

  List<Map<String, dynamic>> _getHardCodedInspectionItems() {
    return [
      {
        'id': 1,
        'question': "Araç Sürücüsü Yeterli sürücü Belgesine Sahip mi? (D,E5-D1,B7)",
        'description': "D sınıfı sürücü belgesi için en az beş yıllık, D1 sınıfı sürücü belgesi için en az yedi yıllık sürücü belgesine sahip olmak",
        'vehicle_field': 'driver_license_status',
        'type': 'boolean',
        'is_critical': true,
        'sort_order': 1,
      },
      {
        'id': 2,
        'question': "Araç sürücüsünün yaşı uygun mu?",
        'description': "26 yaşından gün almış 66 yaşından gün almamış olmak",
        'vehicle_field': 'driver_age_status',
        'type': 'boolean',
        'is_critical': true,
        'sort_order': 2,
      },
      // Diğer tüm maddeleri buraya ekleyebilirsin
      // Ama zaten _initializeCategories'da hepsi var
    ];
  }



  Future<List<Map<String, dynamic>>> getAllInspections() async {
    http.Client? client;

    try {
      print('🔄 HYBRID: Tüm denetimler getiriliyor...');
      client = await _getHttpClient();

      final response = await client.get(
        Uri.parse(
            '$_supabaseUrl/rest/v1/inspections?select=*&order=inspection_date.desc&limit=20'),
        headers: _headers,
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ HTTP getAllInspections başarılı: ${data.length} kayıt');

        // Araç bilgilerini getir
        final enhancedInspections = await Future.wait(
            (data as List).map((inspection) async {
              try {
                if (inspection['vehicle_plate'] != null) {
                  final vehicleResponse = await client!.get(
                    Uri.parse(
                        '$_supabaseUrl/rest/v1/vehicles?plate=eq.${inspection['vehicle_plate']}&select=model,driver_name'),
                    headers: _headers,
                  );

                  if (vehicleResponse.statusCode == 200) {
                    final vehicleData = json.decode(vehicleResponse.body);
                    if (vehicleData.isNotEmpty) {
                      inspection['vehicle_model'] = vehicleData[0]['model'];
                      inspection['driver_name'] = vehicleData[0]['driver_name'];
                    }
                  }
                }
                return inspection;
              } catch (e) {
                print('⚠️ Araç bilgisi getirme hatası: $e');
                return inspection;
              }
            })
        );

        return enhancedInspections.cast<Map<String, dynamic>>();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP getAllInspections başarısız, Supabase fallback: $e');

      try {
        final response = await _supabase
            .from('inspections')
            .select()
            .order('inspection_date', ascending: false)
            .limit(20);

        // Her denetim için araç bilgilerini getir
        final enhancedInspections = await Future.wait(
            response.map((inspection) async {
              try {
                if (inspection['vehicle_plate'] != null) {
                  final vehicleResponse = await _supabase
                      .from('vehicles')
                      .select('model, driver_name')
                      .eq('plate', inspection['vehicle_plate'])
                      .maybeSingle();

                  inspection['vehicle_model'] = vehicleResponse?['model'];
                  inspection['driver_name'] = vehicleResponse?['driver_name'];
                }
                return inspection;
              } catch (e) {
                print('⚠️ Araç bilgisi getirme hatası: $e');
                return inspection;
              }
            })
        );

        return enhancedInspections.cast<Map<String, dynamic>>();
      } catch (supabaseError) {
        print('❌ Tüm yöntemler başarısız: $supabaseError');
        return [];
      }
    } finally {
      client?.close();
    }
  }

  Future<Map<String, dynamic>?> getInspectionDetails(
      String inspectionId) async {
    http.Client? client;

    try {
      print('🔍 HYBRID: Denetim detayları getiriliyor: $inspectionId');
      client = await _getHttpClient();

      final response = await client.get(
        Uri.parse(
            '$_supabaseUrl/rest/v1/inspections?id=eq.$inspectionId&select=*,vehicles(*),schools(*)'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          print('✅ HTTP getInspectionDetails başarılı');
          return data[0] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('❌ HTTP getInspectionDetails başarısız, Supabase fallback: $e');

      try {
        final response = await _supabase
            .from('inspections')
            .select('''
          *,
          vehicles!inner(*),
          schools!inner(*)
        ''')
            .eq('id', inspectionId)
            .single();

        return response;
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        return null;
      }
    } finally {
      client?.close();
    }
  }

// YARDIMCI METODLAR
  String _validateUserId(String userId) {
    if (RegExp(r'^\d+$').hasMatch(userId)) {
      return userId;
    }
    return userId;
  }

  String _normalizePlate(String plate) {
    return plate.replaceAll(' ', '').toUpperCase();
  }

  Map<String, dynamic> _createEmptyVehicleData(String plate) {
    return {
      'vehicle': {
        'plate': plate,
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



  List<Map<String, dynamic>> _getDefaultInspectionItems() {
    return [
      {
        'id': 1,
        'category': 'Sürücü Belgeleri',
        'question': 'Ehliyet aslı mevcut mu?',
        'vehicle_field': 'driver_license_status',
        'type': 'boolean',
        'is_critical': true,
        'sort_order': 1,
      },
      {
        'id': 2,
        'category': 'Sürücü Belgeleri',
        'question': 'SRC Belgesi geçerli mi?',
        'vehicle_field': 'src_certificate_status',
        'type': 'boolean',
        'is_critical': true,
        'sort_order': 2,
      },
      // ... diğer denetim maddeleri
    ];
  }

  List<Map<String, dynamic>> _getDemoSchools() {
    return [
      {
        'id': '1',
        'name': 'Atatürk İlkokulu',
        'district': 'Ünye',
        'address': 'Ünye Merkez',
        'is_active': true
      },
      {
        'id': '2',
        'name': 'Cumhuriyet Ortaokulu',
        'district': 'Ünye',
        'address': 'Ünye Merkez',
        'is_active': true
      },
    ];
  }

// MEVCUT SUPABASE METODLARI (Fallback için gerekli)
  Future<Map<String, dynamic>?> getDriverByVehicleId(int vehicleId) async {
    try {
      final response = await _supabase
          .from('vehicles')
          .select('''
          driver_name,
          driver_phone,
          driver_license_type,
          driver_license_expiry,
          driver_birth_date,
          src_certificate_expiry
        ''')
          .eq('id', vehicleId)
          .single();

      return {
        'full_name': response['driver_name'],
        'phone': response['driver_phone'],
        'license_type': response['driver_license_type'],
        'license_expiry_date': response['driver_license_expiry'],
        'birth_date': response['driver_birth_date'],
        'src_certificate_expiry': response['src_certificate_expiry'],
      };
    } catch (e) {
      print('❌ Sürücü getirme hatası: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAttendantByVehicleId(int vehicleId) async {
    try {
      final response = await _supabase
          .from('vehicles')
          .select('''
          attendant_name,
          attendant_birth_date,
          has_reflective_vest,
          has_warning_lights
        ''')
          .eq('id', vehicleId)
          .single();

      return {
        'full_name': response['attendant_name'],
        'birth_date': response['attendant_birth_date'],
        'has_reflective_vest': response['has_reflective_vest'] ?? false,
        'has_warning_lights': response['has_warning_lights'] ?? false,
      };
    } catch (e) {
      print('❌ Rehber getirme hatası: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDocumentsByVehicleId(int vehicleId) async {
    try {
      final response = await _supabase
          .from('vehicles')
          .select('''
          insurance_expiry,
          inspection_expiry,
          route_permit_expiry,
          g_certificate_expiry,
          fire_extinguisher_expiry
        ''')
          .eq('id', vehicleId)
          .single();

      return {
        'insurance_expiry': response['insurance_expiry'],
        'inspection_expiry': response['inspection_expiry'],
        'route_permission_expiry': response['route_permit_expiry'],
        'g_certificate_expiry': response['g_certificate_expiry'],
        'fire_extinguisher_expiry': response['fire_extinguisher_expiry'],
      };
    } catch (e) {
      print('❌ Belge getirme hatası: $e');
      return null;
    }
  }

// ARAÇ SİLME - HYBRID
  Future<void> deleteVehicle(dynamic vehicleId) async {
    http.Client? client;

    try {
      print('🗑️ HYBRID: Araç siliniyor: $vehicleId');
      client = await _getHttpClient();

      final id = vehicleId is String ? vehicleId : vehicleId.toString();

      // Önce ilişkili kayıtları sil
      await client.delete(
        Uri.parse('$_supabaseUrl/rest/v1/vehicle_schools?vehicle_id=eq.$id'),
        headers: _headers,
      );

      // Sonra aracı sil
      final response = await client.delete(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$id'),
        headers: _headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP deleteVehicle başarılı: $id');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP deleteVehicle başarısız, Supabase fallback: $e');

      try {
        final id = vehicleId is String ? vehicleId : vehicleId.toString();

        // Önce ilişkili kayıtları sil
        await _supabase
            .from('vehicle_schools')
            .delete()
            .eq('vehicle_id', id);

        // Sonra aracı sil
        await _supabase
            .from('vehicles')
            .delete()
            .eq('id', id);

        print('✅ Supabase deleteVehicle fallback: $vehicleId');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }
  // DatabaseService'a eklenmesi gereken eksik metodlar:

  Future<Map<String, dynamic>> getCompleteVehicleDataByPlate(String plate) async {
    try {
      print('🔍 HYBRID: Tam araç verisi aranıyor (ByPlate): $plate');

      // ÖNCE LOCAL'A BAK
      final localVehicle = await _localStorage.getVehicleByPlate(plate);
      if (localVehicle != null) {
        print('✅ Local\'da araç bulundu: $plate');

        final vehicleId = localVehicle['id'];

        // FUTURE.WAIT TİP SORUNUNU ÇÖZELİM
        final results = await Future.wait<dynamic>([
          _getDriverDataFallback(vehicleId),
          _getAttendantDataFallback(vehicleId),
          _getDocumentsDataFallback(vehicleId),
          getVehicleSchools(vehicleId), // Direkt metod çağır
        ], eagerError: true);

        return {
          'vehicle': localVehicle,
          'driver': results[0] ?? {},
          'attendant': results[1] ?? {},
          'documents': results[2] ?? {},
          'schools': results[3] ?? [],
          '_isSample': false,
          '_isEmpty': false,
        };
      }

      // LOCAL'DA YOKSA ONLINE DENE
      return await getCompleteVehicleData(plate);
    } catch (e) {
      print('❌ getCompleteVehicleDataByPlate hatası: $e');
      return _createEmptyVehicleData(plate);
    }
  }

// Yardımcı fallback metodları
  Future<Map<String, dynamic>> _getDriverDataFallback(int vehicleId) async {
    try {
      final localVehicles = await _localStorage.getVehicles();
      final vehicle = localVehicles.firstWhere(
            (v) => v['id'] == vehicleId,
        orElse: () => {},
      );

      if (vehicle.isNotEmpty) {
        return {
          'full_name': vehicle['driver_name'],
          'phone': vehicle['driver_phone'],
          'license_type': vehicle['driver_license_type'],
          'license_expiry_date': vehicle['driver_license_expiry'],
          'birth_date': vehicle['driver_birth_date'],
          'src_certificate_expiry': vehicle['src_certificate_expiry'],
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _getAttendantDataFallback(int vehicleId) async {
    try {
      final localVehicles = await _localStorage.getVehicles();
      final vehicle = localVehicles.firstWhere(
            (v) => v['id'] == vehicleId,
        orElse: () => {},
      );

      if (vehicle.isNotEmpty) {
        return {
          'full_name': vehicle['attendant_name'],
          'birth_date': vehicle['attendant_birth_date'],
          'has_reflective_vest': vehicle['has_reflective_vest'] ?? false,
          'has_warning_lights': vehicle['has_warning_lights'] ?? false,
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _getDocumentsDataFallback(int vehicleId) async {
    try {
      final localVehicles = await _localStorage.getVehicles();
      final vehicle = localVehicles.firstWhere(
            (v) => v['id'] == vehicleId,
        orElse: () => {},
      );

      if (vehicle.isNotEmpty) {
        return {
          'insurance_expiry': vehicle['insurance_expiry'],
          'inspection_expiry': vehicle['inspection_expiry'],
          'route_permission_expiry': vehicle['route_permit_expiry'],
          'g_certificate_expiry': vehicle['g_certificate_expiry'],
          'fire_extinguisher_expiry': vehicle['fire_extinguisher_expiry'],
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }

// 2. getRecentInspections metodu
  Future<List<Map<String, dynamic>>> getRecentInspections(String plate) async {
    http.Client? client;

    try {
      print('📋 HYBRID: Son denetimler getiriliyor: $plate');
      client = await _getHttpClient();

      final response = await client.get(
        Uri.parse('$_supabaseUrl/rest/v1/inspections?vehicle_plate=eq.${plate.toUpperCase()}&select=*&order=inspection_date.desc&limit=5'),
        headers: _headers,
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ HTTP getRecentInspections başarılı: ${data.length} denetim');
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP getRecentInspections başarısız, Supabase fallback: $e');

      try {
        final response = await _supabase
            .from('inspections')
            .select()
            .eq('vehicle_plate', plate.toUpperCase())
            .order('inspection_date', ascending: false)
            .limit(5);

        return response.cast<Map<String, dynamic>>();
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        return [];
      }
    } finally {
      client?.close();
    }
  }

// 3. sendVehicleForApproval metodu
  Future<void> sendVehicleForApproval(String vehicleId) async {
    http.Client? client;

    try {
      print('📤 HYBRID: Araç onaya gönderiliyor: $vehicleId');
      client = await _getHttpClient();

      final response = await client.patch(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId'),
        headers: _headers,
        body: json.encode({
          'is_approved': false,
          'rejection_reason': null,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP sendVehicleForApproval başarılı: $vehicleId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP sendVehicleForApproval başarısız, Supabase fallback: $e');

      try {
        await _supabase
            .from('vehicles')
            .update({
          'is_approved': false,
          'rejection_reason': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', vehicleId);
        print('✅ Supabase sendVehicleForApproval fallback: $vehicleId');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

// 4. getVehicleCompleteData metodu
  Future<Map<String, dynamic>> getVehicleCompleteData(int vehicleId) async {
    http.Client? client;

    try {
      print('🔍 HYBRID: Tam araç verisi getiriliyor (ID): $vehicleId');
      client = await _getHttpClient();

      final vehicleResponse = await client.get(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId&select=*'),
        headers: _headers,
      ).timeout(Duration(seconds: 15));

      if (vehicleResponse.statusCode == 200) {
        final List<dynamic> vehicleData = json.decode(vehicleResponse.body);
        if (vehicleData.isEmpty) {
          print('❌ HTTP: Araç bulunamadı');
          return {'_isEmpty': true, '_isSample': false};
        }

        final vehicle = vehicleData[0];
        print('✅ HTTP: Araç bulundu: $vehicleId');

        // FUTURE.WAIT TİP SORUNUNU ÇÖZELİM
        final results = await Future.wait<dynamic>([
          _getDriverData(client, vehicleId),
          _getAttendantData(client, vehicleId),
          _getDocumentsData(client, vehicleId),
          getVehicleSchools(vehicleId), // Direkt metod çağır
        ], eagerError: true);

        return {
          'vehicle': vehicle,
          'driver': results[0] ?? {},
          'attendant': results[1] ?? {},
          'documents': results[2] ?? {},
          'schools': results[3] ?? [],
          '_isSample': false,
          '_isEmpty': false,
        };
      } else {
        throw Exception('HTTP ${vehicleResponse.statusCode}');
      }
    } catch (e) {
      print('❌ HTTP getVehicleCompleteData başarısız, Supabase fallback: $e');

      try {
        return await _getCompleteVehicleDataWithSupabaseById(vehicleId);
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        return {'_isEmpty': true, '_isSample': false};
      }
    } finally {
      client?.close();
    }
  }

// 5. getUsers metodu (zaten var ama kontrol edelim)
  Future<List<Map<String, dynamic>>> getUsers() async {
    http.Client? client;

    try {
      print('🔍 HYBRID: Kullanıcılar getiriliyor');
      client = await _getHttpClient();

      final response = await client.get(
        Uri.parse('$_supabaseUrl/rest/v1/app_users?select=*,schools(name,district)'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ HTTP getUsers başarılı: ${data.length} kullanıcı');
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP getUsers başarısız, Supabase fallback: $e');

      try {
        final response = await _supabase
            .from('app_users')
            .select('*, schools(name, district)')
            .order('created_at', ascending: false);

        print('✅ Supabase getUsers fallback: ${response.length} kullanıcı');
        return response;
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        return _getDemoUsers();
      }
    } finally {
      client?.close();
    }
  }

// 6. saveDriver metodu
  Future<void> saveDriver(Map<String, dynamic> driverData) async {
    http.Client? client;

    try {
      final vehicleId = driverData['vehicle_id'];
      print('👨‍💼 HYBRID: Sürücü kaydediliyor: $vehicleId');
      client = await _getHttpClient();

      final updateData = {
        'driver_name': driverData['full_name'],
        'driver_phone': driverData['phone'],
        'driver_license_type': driverData['license_type'],
        'driver_license_expiry': driverData['license_expiry_date'],
        'driver_birth_date': driverData['birth_date'],
        'src_certificate_expiry': driverData['src_certificate_expiry'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await client.patch(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId'),
        headers: _headers,
        body: json.encode(updateData),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP saveDriver başarılı: $vehicleId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP saveDriver başarısız, Supabase fallback: $e');

      try {
        final vehicleId = driverData['vehicle_id'];

        final updateData = {
          'driver_name': driverData['full_name'],
          'driver_phone': driverData['phone'],
          'driver_license_type': driverData['license_type'],
          'driver_license_expiry': driverData['license_expiry_date'],
          'driver_birth_date': driverData['birth_date'],
          'src_certificate_expiry': driverData['src_certificate_expiry'],
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _supabase
            .from('vehicles')
            .update(updateData)
            .eq('id', vehicleId);

        print('✅ Supabase saveDriver fallback: ${driverData['vehicle_id']}');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

// 7. saveAttendant metodu
  Future<void> saveAttendant(Map<String, dynamic> attendantData) async {
    http.Client? client;

    try {
      final vehicleId = attendantData['vehicle_id'];
      print('👩‍💼 HYBRID: Rehber kaydediliyor: $vehicleId');
      client = await _getHttpClient();

      final updateData = {
        'attendant_name': attendantData['full_name'],
        'attendant_birth_date': attendantData['birth_date'],
        'has_reflective_vest': attendantData['has_reflective_vest'],
        'has_warning_lights': attendantData['has_warning_lights'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await client.patch(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId'),
        headers: _headers,
        body: json.encode(updateData),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP saveAttendant başarılı: $vehicleId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP saveAttendant başarısız, Supabase fallback: $e');

      try {
        final vehicleId = attendantData['vehicle_id'];

        final updateData = {
          'attendant_name': attendantData['full_name'],
          'attendant_birth_date': attendantData['birth_date'],
          'has_reflective_vest': attendantData['has_reflective_vest'],
          'has_warning_lights': attendantData['has_warning_lights'],
          'updated_at': DateTime.now().toIso8601String(),
        };

        final response = await _supabase
            .from('vehicles')
            .update(updateData)
            .eq('id', vehicleId);

        print('✅ Supabase saveAttendant fallback: $vehicleId');
        print('🔍 Güncelleme yanıtı: $response');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        throw supabaseError;
      }
    } finally {
      client?.close();
    }
  }

// Yardımcı metod: ID ile tam veri getirme (Supabase fallback)
  Future<Map<String, dynamic>> _getCompleteVehicleDataWithSupabaseById(int vehicleId) async {
    try {
      print('🔄 Supabase: Tam araç verisi aranıyor (ID): $vehicleId');

      final vehicleResponse = await _supabase
          .from('vehicles')
          .select()
          .eq('id', vehicleId)
          .maybeSingle();

      if (vehicleResponse == null) {
        print('❌ Supabase: Araç bulunamadı');
        return {'_isEmpty': true, '_isSample': false};
      }

      print('✅ Supabase: Araç bulundu: $vehicleId');

      // FUTURE.WAIT TİP SORUNUNU ÇÖZELİM
      final results = await Future.wait<dynamic>([
        getDriverByVehicleId(vehicleId),
        getAttendantByVehicleId(vehicleId),
        getDocumentsByVehicleId(vehicleId),
        getVehicleSchools(vehicleId), // Direkt metod çağır
      ], eagerError: true);

      return {
        'vehicle': vehicleResponse,
        'driver': results[0] ?? {},
        'attendant': results[1] ?? {},
        'documents': results[2] ?? {},
        'schools': results[3] ?? [],
        '_isSample': false,
        '_isEmpty': false,
      };
    } catch (e) {
      print('❌ Supabase getCompleteVehicleData hatası: $e');
      return {'_isEmpty': true, '_isSample': false};
    }
  }

// Demo kullanıcılar
  List<Map<String, dynamic>> _getDemoUsers() {
    return [
      {
        'id': '1',
        'email': 'ilce@mem.gov.tr',
        'full_name': 'İlçe MEM Yetkilisi',
        'user_type': 'ilce',
        'is_active': true,
        'created_at': '2024-01-15T10:00:00Z',
        'schools': {'name': 'İlçe MEM', 'district': 'Ünye'}
      },
      {
        'id': '2',
        'email': 'denetim@mem.gov.tr',
        'full_name': 'Denetim Görevlisi',
        'user_type': 'denetim',
        'is_active': true,
        'created_at': '2024-01-16T11:00:00Z',
        'schools': null
      },
    ];
  }

  Future<void> saveInspection(Map<String, dynamic> inspectionData) async {
    http.Client? client;

    try {
      print('💾 HYBRID: Denetim kaydediliyor...');
      client = await _getHttpClient();

      // TABLO ŞEMASINA UYGUN VERİ HAZIRLA
      final preparedData = _prepareDataForExistingTable(inspectionData);

      print('📤 Kayıt verisi: ${preparedData['vehicle_plate']} - Okul: ${preparedData['school_name']}');

      final response = await client.post(
        Uri.parse('$_supabaseUrl/rest/v1/inspections'),
        headers: _headers,
        body: json.encode(preparedData),
      );

      if (response.statusCode == 201) {
        print('✅ HTTP saveInspection başarılı');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP saveInspection başarısız, Supabase fallback: $e');

      try {
        // Supabase fallback için de aynı veri hazırlama
        final preparedData = _prepareDataForExistingTable(inspectionData);

        final response = await _supabase
            .from('inspections')
            .insert(preparedData)
            .select();

        print('✅ Supabase saveInspection fallback: ${response.length} kayıt');
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        // Local kayıt yap ama hatayı fırlatma - sadece logla
        await _saveInspectionLocally(inspectionData);
        // Hata fırlatma ki kullanıcı formda kalabilsin
        print('⚠️ Denetim yerel olarak kaydedildi, kullanıcı formda kalıyor');
      }
    } finally {
      client?.close();
    }
  }

// YENİ METOD: Veritabanı için veriyi hazırla
  Map<String, dynamic> _prepareDataForExistingTable(Map<String, dynamic> inspectionData) {
    // Mevcut tablo kolonlarına göre veri hazırla
    final preparedData = <String, dynamic>{};

    // Zorunlu alanlar
    preparedData['vehicle_plate'] = inspectionData['vehicle_plate'];
    preparedData['school_name'] = inspectionData['school_name'];
    preparedData['inspector_name'] = inspectionData['inspector_name'];
    preparedData['inspection_date'] = inspectionData['inspection_date'];

    // Sayısal alanlar
    preparedData['completed_items'] = int.tryParse(inspectionData['completed_items'].toString()) ?? 0;
    preparedData['total_items'] = int.tryParse(inspectionData['total_items'].toString()) ?? 0;
    preparedData['total_score'] = 0; // Tabloda var ama kullanmıyoruz

    // Diğer alanlar
    preparedData['result'] = inspectionData['result'];
    preparedData['is_manual_entry'] = inspectionData['is_manual_entry'] ?? false;
    preparedData['details'] = inspectionData['details'];

    // Opsiyonel alanlar - null olarak gönder
    preparedData['vehicle_id'] = null;
    preparedData['school_id'] = null;
    preparedData['inspector_id'] = null;
    preparedData['is_compliant'] = null;
    preparedData['notes'] = null;

    // Tabloda olmayan alanları KESİNLİKLE GÖNDERME
    // 'extra_data', 'vehicle_data', 'driver_data', 'attendant_data', 'documents_data', 'schools', 'school_district'

    return preparedData;
  }

// Local kayıt metodu
  Future<void> _saveInspectionLocally(Map<String, dynamic> inspectionData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_inspection_${inspectionData['vehicle_plate']}_${DateTime.now().millisecondsSinceEpoch}';

      await prefs.setString(key, json.encode(inspectionData));

      print('📱 Denetim local olarak kaydedildi: ${inspectionData['vehicle_plate']} - Key: $key');

      // Local kayıt listesini güncelle
      final localInspections = prefs.getStringList('local_inspections') ?? [];
      localInspections.add(key);
      await prefs.setStringList('local_inspections', localInspections);

    } catch (e) {
      print('❌ Local kayıt hatası: $e');
    }
  }

  Future<bool> hasLocalInspections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localKeys = prefs.getStringList('local_inspections') ?? [];
      return localKeys.isNotEmpty;
    } catch (e) {
      print('❌ Local denetim kontrol hatası: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLocalInspections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localKeys = prefs.getStringList('local_inspections') ?? [];
      final localInspections = <Map<String, dynamic>>[];

      for (final key in localKeys) {
        final inspectionJson = prefs.getString(key);
        if (inspectionJson != null) {
          try {
            final inspectionData = json.decode(inspectionJson);
            localInspections.add(inspectionData);
          } catch (e) {
            print('❌ Local denetim parse hatası: $e');
          }
        }
      }

      return localInspections;
    } catch (e) {
      print('❌ Local denetim getirme hatası: $e');
      return [];
    }
  }

  Future<void> syncLocalInspections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localKeys = prefs.getStringList('local_inspections') ?? [];

      print('🔄 ${localKeys.length} local denetim senkronize ediliyor...');

      for (final key in localKeys) {
        final inspectionJson = prefs.getString(key);
        if (inspectionJson != null) {
          try {
            final inspectionData = json.decode(inspectionJson);
            await saveInspection(inspectionData);

            // Başarılı senkronizasyondan sonra local kaydı sil
            await prefs.remove(key);
            print('✅ Local denetim senkronize edildi: ${inspectionData['vehicle_plate']}');

          } catch (e) {
            print('❌ Local denetim senkronizasyon hatası: $e');
          }
        }
      }

      // Listeyi güncelle
      final updatedKeys = prefs.getStringList('local_inspections') ?? [];
      await prefs.setStringList('local_inspections', updatedKeys);

      print('✅ Local senkronizasyon tamamlandı');

    } catch (e) {
      print('❌ Local senkronizasyon hatası: $e');
    }
  }

  Future<void> syncPendingData() async {
    try {
      final pendingInspections = await _localStorage.getPendingInspections();
      print('🔄 ${pendingInspections.length} bekleyen denetim senkronize ediliyor...');

      for (final inspection in pendingInspections) {
        try {
          // UUID'leri kaldır
          final syncData = Map<String, dynamic>.from(inspection);
          syncData.remove('local_id');
          syncData.remove('is_synced');
          syncData.remove('vehicle_id');
          syncData.remove('school_id');

          await saveInspection(syncData);
          await _localStorage.markInspectionAsSynced(inspection['local_id']);

          print('✅ Denetim senkronize edildi: ${inspection['vehicle_plate']}');
        } catch (e) {
          print('❌ Denetim senkronize hatası: $e');
        }
      }
    } catch (e) {
      print('❌ Senkronizasyon hatası: $e');
    }
  }

}