import 'package:supabase_flutter/supabase_flutter.dart';
import '/utils/constants.dart';

// services/database_service.dart - Yeni metodlar ekle
class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // GERÇEK araç ekleme
  Future<Map<String, dynamic>> createVehicle({
    required String plate,
    required String model,
    required int modelYear, // BU SATIRI EKLE
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
          .from(Constants.vehiclesTable)
          .insert({
        'plate': plate.toUpperCase(),
        'model': model,
        'model_year': modelYear, // BU SATIRI EKLE
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
            'school_id': int.parse(schoolId), // Integer'a çevir
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

  // GERÇEK araç güncelleme
  Future<Map<String, dynamic>> updateVehicle({
    required dynamic vehicleId,
    required String plate,
    required String model,
    required int modelYear, // BU SATIRI EKLE
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
          .from(Constants.vehiclesTable)
          .update({
        'plate': plate.toUpperCase(),
        'model': model,
        'model_year': modelYear, // BU SATIRI EKLE
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
            'vehicle_id': int.parse(id), // vehicle_id integer
            'school_id': int.parse(schoolId), // school_id integer
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

  // GERÇEK araç onaylama
  Future<void> approveVehicle(dynamic vehicleId, String approvedBy) async {
    try {
      final id = vehicleId is String ? vehicleId : vehicleId.toString();

      await _supabase
          .from(Constants.vehiclesTable)
          .update({
        'is_approved': true,
        'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
      })
          .eq('id', id);

      print('✅ Araç onaylandı: $id, onaylayan: $approvedBy');
    } catch (e) {
      print('❌ Araç onaylama hatası: $e');
      print('• Hata detayı: ${e.toString()}');
      rethrow;
    }
  }

  // services/database_service.dart - Red metodu ekle
  Future<void> rejectVehicle(dynamic vehicleId, String rejectedBy, String reason) async {
    try {
      final id = vehicleId is String ? vehicleId : vehicleId.toString();

      await _supabase
          .from(Constants.vehiclesTable)
          .update({
        'is_approved': false,
        'rejection_reason': reason,
        'rejected_by': rejectedBy,
        'rejected_at': DateTime.now().toIso8601String(),
      })
          .eq('id', id);

      print('✅ Araç reddedildi: $id, sebep: $reason');
    } catch (e) {
      print('❌ Araç reddetme hatası: $e');
      rethrow;
    }
  }

  // GERÇEK araç silme
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
          .from(Constants.vehiclesTable)
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

  // services/database_service.dart - Okula özel araçları getir
  Future<List<Map<String, dynamic>>> getSchoolVehicles(String schoolId) async {
    try {
      final response = await _supabase
          .from('vehicle_schools')
          .select('''
          vehicles (*)
        ''')
          .eq('school_id', schoolId)
          .order('created_at', ascending: false);

      // Güvenli type conversion
      return response.map<Map<String, dynamic>>((item) {
        final vehicle = item['vehicles'];
        if (vehicle is Map<String, dynamic>) {
          return vehicle;
        } else if (vehicle is Map) {
          return Map<String, dynamic>.from(vehicle as Map);
        } else {
          return {};
        }
      }).where((vehicle) => vehicle.isNotEmpty).toList();

    } catch (e) {
      print('Okul araçları getirme hatası: $e');
      return [];
    }
  }



  // Araç kaydı oluştur veya getir
  Future<Map<String, dynamic>> getOrCreateVehicle(String plate, {String? model, int? capacity}) async {
    try {
      // Önce araç var mı kontrol et
      final response = await _supabase
          .from(Constants.vehiclesTable)
          .select()
          .eq('plate', plate.toUpperCase());

      if (response.isNotEmpty && response[0] != null) {
        return response[0];
      }

      // Yeni araç oluştur
      final newVehicle = await _supabase
          .from(Constants.vehiclesTable)
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

  // Denetim kaydı oluştur - SÜRELİ EVRAK DESTEKLİ
  // Denetim kaydı oluştur - DÜZELTMELİ
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
      final totalItems = inspectionItems.length;
      final status = _calculateStatus(inspectionItems);

      // Denetim kaydı oluştur - TOTAL_ITEMS ALANINI KALDIRIYORUZ
      final inspection = await _supabase
          .from(Constants.inspectionsTable)
          .insert({
        'vehicle_id': vehicle['id'],
        'inspector_name': inspectorName,
        'inspection_date': DateTime.now().toIso8601String(),
        'total_score': compliantItems,
        // 'total_items': totalItems, // BU SATIRI KALDIRIYORUZ - Tabloda yok
        'status': status,
        'driver_signature': driverSignature,
        'created_at': DateTime.now().toIso8601String(),
      })
          .select()
          .single();

      // Denetim detaylarını kaydet
      for (final item in inspectionItems) {
        await _supabase
            .from(Constants.inspectionDetailsTable)
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

  String _calculateStatus(List<Map<String, dynamic>> items) {
    final compliantCount = items.where((item) => item['is_compliant'] == true).length;
    final totalCount = items.length;
    final ratio = compliantCount / totalCount;

    if (ratio >= 0.9) return 'compliant';
    if (ratio >= 0.7) return 'conditional';
    return 'non_compliant';
  }

  // Geçmiş denetimleri getir
  Future<List<Map<String, dynamic>>> getInspectionsByVehicle(String plate) async {
    try {
      final response = await _supabase
          .from(Constants.inspectionsTable)
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

  // Tüm denetimleri getir
  Future<List<Map<String, dynamic>>> getAllInspections() async {
    try {
      final response = await _supabase
          .from(Constants.inspectionsTable)
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

  // Süresi dolmak üzere olan denetimleri getir
  Future<List<Map<String, dynamic>>> getExpiringInspections() async {
    try {
      final thirtyDaysFromNow = DateTime.now().add(Duration(days: 30)).toIso8601String();

      final response = await _supabase
          .from(Constants.inspectionDetailsTable)
          .select('''
            *,
            inspections!inner(
              inspection_date,
              vehicles!inner(plate, model)
            )
          ''')
          .lt('selected_date', thirtyDaysFromNow)
          .gt('selected_date', DateTime.now().toIso8601String())
          .eq('is_critical_date', true);

      return response;
    } catch (e) {
      print('Süresi dolan denetimleri getirme hatası: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllVehicles() async {
    try {
      final response = await _supabase
          .from(Constants.vehiclesTable)
          .select()
          .order('plate');

      return response;
    } catch (e) {
      print('Araç getirme hatası: $e');
      return [];
    }
  }

  // Süresi dolmuş denetimleri getir
  Future<List<Map<String, dynamic>>> getExpiredInspections() async {
    try {
      final response = await _supabase
          .from(Constants.inspectionDetailsTable)
          .select('''
            *,
            inspections!inner(
              inspection_date,
              vehicles!inner(plate, model)
            )
          ''')
          .lt('selected_date', DateTime.now().toIso8601String())
          .eq('is_critical_date', true);

      return response;
    } catch (e) {
      print('Süresi dolmuş denetimleri getirme hatası: $e');
      return [];
    }
  }
}