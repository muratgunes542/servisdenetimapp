import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // BURAYA KENDİ SUPABASE BİLGİLERİNİZİ EKLEYİN
  static const String _supabaseUrl = 'https://zxhvyfbzhuvbcnuxsaxq.supabase.co'; // SUPABASE_URL'niz
  static const String _apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4aHZ5ZmJ6aHV2YmNudXhzYXhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2ODg5MzMsImV4cCI6MjA3NTI2NDkzM30.rFB-7LP_ccNWrPXIpfTuwAW9zdgRXeX0w79kra5P0uQ'; // ANON_KEY'iniz

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
    'apikey': _apiKey,
    'Prefer': 'return=representation',
  };

  // MEB ağı için özel HTTP client
  static http.Client _createMebClient() {
    var ioClient = HttpClient();
    ioClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // Sadece Supabase için sertifika doğrulamasını atla
      return host.contains('supabase.co');
    };

    // Timeout ayarları
    ioClient.connectionTimeout = Duration(seconds: 10);
    return IOClient(ioClient);
  }

  // Akıllı bağlantı metodu - MEB ağını tespit et
  Future<http.Client> _getHttpClient() async {
    try {
      // MEB ağında mı kontrol et
      final testClient = _createMebClient();
      final testResponse = await testClient.get(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?select=*&limit=1'),
        headers: _headers,
      ).timeout(Duration(seconds: 5));

      // Eğer başarılıysa MEB client'ını kullan
      if (testResponse.statusCode == 200) {
        print('🔍 MEB ağı tespit edildi, özel client kullanılıyor');
        return testClient;
      }
    } catch (e) {
      print('🔍 Normal ağ tespit edildi, standart client kullanılıyor');
    }

    // Normal ağda standart client
    return http.Client();
  }

  // HYBRID GET metodları
  Future<List<Map<String, dynamic>>> getAllVehicles() async {
    http.Client? client;

    try {
      client = await _getHttpClient();

      final response = await client.get(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?select=*'),
        headers: _headers,
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ HTTP getAllVehicles başarılı: ${data.length} araç');
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP getAllVehicles başarısız, Supabase fallback: $e');

      // Fallback: normal Supabase client
      try {
        final response = await _supabase
            .from('vehicles')
            .select('*')
            .order('created_at', ascending: false);
        print('✅ Supabase getAllVehicles fallback: ${response.length} araç');
        return response;
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        return [];
      }
    } finally {
      client?.close();
    }
  }

  // Kullanıcı araçlarını getir - HYBRID
  Future<List<Map<String, dynamic>>> getUserVehicles(String userId) async {
    try {
      // HTTP ile dene
      final response = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?select=*&created_by=eq.$userId'),
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
      print('❌ HTTP getUserVehicles başarısız, fallback: $e');
      // Fallback: normal Supabase client
      final response = await _supabase
          .from('vehicles')
          .select('*')
          .eq('created_by', userId)
          .order('created_at', ascending: false);
      print('✅ Supabase getUserVehicles fallback: ${response.length} araç');
      return response;
    }
  }

  // Araç onayla - HYBRID
  Future<void> approveVehicle(String vehicleId, String approvedBy) async {
    try {
      // HTTP ile dene
      final response = await http.patch(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId'),
        headers: _headers,
        body: json.encode({
          'is_approved': true,
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP approveVehicle başarılı: $vehicleId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP approveVehicle başarısız, fallback: $e');
      // Fallback: normal Supabase client
      await _supabase
          .from('vehicles')
          .update({
        'is_approved': true,
        'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', vehicleId);
      print('✅ Supabase approveVehicle fallback: $vehicleId');
    }
  }

  // Araç reddet - HYBRID
  Future<void> rejectVehicle(String vehicleId, String rejectedBy, String reason) async {
    try {
      // HTTP ile dene
      final response = await http.patch(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId'),
        headers: _headers,
        body: json.encode({
          'is_approved': false,
          'rejection_reason': reason,
          'approved_by': rejectedBy,
          'approved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP rejectVehicle başarılı: $vehicleId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP rejectVehicle başarısız, fallback: $e');
      // Fallback: normal Supabase client
      await _supabase
          .from('vehicles')
          .update({
        'is_approved': false,
        'rejection_reason': reason,
        'approved_by': rejectedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', vehicleId);
      print('✅ Supabase rejectVehicle fallback: $vehicleId');
    }
  }

  // Onayı geri al - HYBRID
  Future<void> unapproveVehicle(String vehicleId, String userId) async {
    try {
      // HTTP ile dene
      final response = await http.patch(
        Uri.parse('$_supabaseUrl/rest/v1/vehicles?id=eq.$vehicleId'),
        headers: _headers,
        body: json.encode({
          'is_approved': false,
          'approved_by': null,
          'approved_at': null,
          'rejection_reason': null,
          'updated_at': DateTime.now().toIso8601String(),
          'updated_by': userId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ HTTP unapproveVehicle başarılı: $vehicleId');
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP unapproveVehicle başarısız, fallback: $e');
      // Fallback: normal Supabase client
      await _supabase
          .from('vehicles')
          .update({
        'is_approved': false,
        'approved_by': null,
        'approved_at': null,
        'rejection_reason': null,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': userId,
      })
          .eq('id', vehicleId);
      print('✅ Supabase unapproveVehicle fallback: $vehicleId');
    }
  }

  // === NORMAL SUPABASE METODLAR (Constants olmadan) ===

  // Araç oluştur
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
    try {
      // Önce aracı oluştur
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
      })
          .select()
          .single();

      // Okul ilişkilerini ekle
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

      return vehicle;
    } catch (e) {
      print('Araç oluşturma hatası: $e');
      rethrow;
    }
  }

  // Araç güncelle
  Future<Map<String, dynamic>> updateVehicle({
    required dynamic vehicleId,
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
    try {
      final id = vehicleId is String ? vehicleId : vehicleId.toString();

      final vehicle = await _supabase
          .from('vehicles')
          .update({
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
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', id)
          .select()
          .single();

      // Okul ilişkilerini güncelle
      if (schoolIds != null) {
        await _supabase
            .from('vehicle_schools')
            .delete()
            .eq('vehicle_id', id);

        for (final schoolId in schoolIds) {
          await _supabase
              .from('vehicle_schools')
              .insert({
            'vehicle_id': int.parse(id),
            'school_id': int.parse(schoolId),
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      return vehicle;
    } catch (e) {
      print('Araç güncelleme hatası: $e');
      rethrow;
    }
  }

  // Araç sil
  Future<void> deleteVehicle(dynamic vehicleId) async {
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
    } catch (e) {
      print('Araç silme hatası: $e');
      rethrow;
    }
  }

  // Okulları getir
  Future<List<Map<String, dynamic>>> getSchools() async {
    try {
      final response = await _supabase
          .from('schools')
          .select()
          .order('name');

      return response;
    } catch (e) {
      print('Okul getirme hatası: $e');
      return [];
    }
  }

  // Aracın bağlı olduğu okulları getir
  Future<List<Map<String, dynamic>>> getVehicleSchools(dynamic vehicleId) async {
    try {
      final id = vehicleId is String ? vehicleId : vehicleId.toString();

      final response = await _supabase
          .from('vehicle_schools')
          .select('''
            schools (*)
          ''')
          .eq('vehicle_id', id);

      return response;
    } catch (e) {
      print('Araç okulları getirme hatası: $e');
      return [];
    }
  }

  // Okul kullanıcısının araçlarını getir
  Future<List<Map<String, dynamic>>> getSchoolVehicles(String schoolId) async {
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

      return vehicles;
    } catch (e) {
      print('Okul araçları getirme hatası: $e');
      throw e;
    }
  }

  // Onaya gönder
  Future<void> sendVehicleForApproval(String vehicleId) async {
    try {
      await _supabase
          .from('vehicles')
          .update({
        'is_approved': false,
        'rejection_reason': null,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', vehicleId);
    } catch (e) {
      print('Onaya gönderme hatası: $e');
      throw e;
    }
  }

  // Denetim oluştur
  Future<Map<String, dynamic>> createInspection({
    required String vehiclePlate,
    required String inspectorName,
    required List<Map<String, dynamic>> inspectionItems,
    String? driverSignature,
  }) async {
    try {
      // Aracı getir veya oluştur
      final vehicle = await getOrCreateVehicle(vehiclePlate);

      // Toplam skor ve durum hesapla
      final compliantItems = inspectionItems.where((item) => item['is_compliant'] == true).length;
      final status = _calculateStatus(inspectionItems);

      // Denetim kaydı oluştur
      final inspection = await _supabase
          .from('inspections')
          .insert({
        'vehicle_id': vehicle['id'],
        'inspector_name': inspectorName,
        'inspection_date': DateTime.now().toIso8601String(),
        'total_score': compliantItems,
        'status': status,
        'driver_signature': driverSignature,
        'created_at': DateTime.now().toIso8601String(),
      })
          .select()
          .single();

      // Denetim detaylarını kaydet
      for (final item in inspectionItems) {
        await _supabase
            .from('inspection_details')
            .insert({
          'inspection_id': inspection['id'],
          'item_number': item['item_number'],
          'question': item['question'],
          'is_compliant': item['is_compliant'],
          'explanation': item['explanation'],
          'selected_date': item['selected_date'],
          'date_field_label': item['date_field_label'],
          'is_critical_date': item['is_critical_date'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      print('Denetim başarıyla kaydedildi: ${inspection['id']}');
      return inspection;

    } catch (e) {
      print('Denetim kaydetme hatası: $e');
      rethrow;
    }
  }

  // Araç getir veya oluştur
  Future<Map<String, dynamic>> getOrCreateVehicle(String plate, {String? model, int? capacity}) async {
    try {
      // Önce araç var mı kontrol et
      final response = await _supabase
          .from('vehicles')
          .select()
          .eq('plate', plate.toUpperCase());

      if (response.isNotEmpty && response[0] != null) {
        return response[0];
      }

      // Yeni araç oluştur
      final newVehicle = await _supabase
          .from('vehicles')
          .insert({
        'plate': plate.toUpperCase(),
        'model': model,
        'capacity': capacity,
        'created_at': DateTime.now().toIso8601String(),
      })
          .select()
          .single();

      return newVehicle;
    } catch (e) {
      print('Araç oluşturma hatası: $e');
      rethrow;
    }
  }

  // Denetim durumu hesapla
  String _calculateStatus(List<Map<String, dynamic>> items) {
    final compliantCount = items.where((item) => item['is_compliant'] == true).length;
    final totalCount = items.length;
    final ratio = compliantCount / totalCount;

    if (ratio >= 0.9) return 'compliant';
    if (ratio >= 0.7) return 'conditional';
    return 'non_compliant';
  }

  // Diğer metodlar...
  Future<List<Map<String, dynamic>>> getInspectionsByVehicle(String plate) async {
    try {
      final response = await _supabase
          .from('inspections')
          .select('''
            *,
            vehicles!inner(plate, model, capacity)
          ''')
          .eq('vehicles.plate', plate.toUpperCase())
          .order('inspection_date', ascending: false);

      return response;
    } catch (e) {
      print('Denetim getirme hatası: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllInspections() async {
    try {
      final response = await _supabase
          .from('inspections')
          .select('''
            *,
            vehicles(plate, model, capacity)
          ''')
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      print('Tüm denetimleri getirme hatası: $e');
      return [];
    }
  }
}