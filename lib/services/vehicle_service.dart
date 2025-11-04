import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';

class VehicleService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Tüm araçları getir
  Future<List<Vehicle>> getAllVehicles() async {
    final response = await _supabase
        .from('vehicles')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((json) => Vehicle.fromJson(json)).toList();
  }

  // Araç durumunu güncelle (onayla/reddet)
  Future<void> updateVehicleStatus({
    required String vehicleId,
    required bool isApproved,
    String? rejectionReason,
  }) async {
    final updateData = {
      'is_approved': isApproved,
      'rejection_reason': rejectionReason,
      'rejected_at': isApproved ? null : DateTime.now().toIso8601String(),
      'approved_at': isApproved ? DateTime.now().toIso8601String() : null,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Null değerleri temizle
    updateData.removeWhere((key, value) => value == null);

    await _supabase
        .from('vehicles')
        .update(updateData)
        .eq('id', vehicleId);
  }

  // Araç detayını getir
  Future<Vehicle?> getVehicleById(String vehicleId) async {
    final response = await _supabase
        .from('vehicles')
        .select()
        .eq('id', vehicleId)
        .single();

    return response != null ? Vehicle.fromJson(response) : null;
  }

  // Onaylı araçları getir
  Future<List<Vehicle>> getApprovedVehicles() async {
    final response = await _supabase
        .from('vehicles')
        .select()
        .eq('is_approved', true)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Vehicle.fromJson(json)).toList();
  }

  // Onay bekleyen araçları getir (reddedilmemiş ve onaylanmamış)
  Future<List<Vehicle>> getPendingVehicles() async {
    final response = await _supabase
        .from('vehicles')
        .select()
        .eq('is_approved', false)
        .filter('rejection_reason', 'is', null) // DÜZELTİLDİ: .is_ yerine .filter
        .order('created_at', ascending: false);

    return (response as List).map((json) => Vehicle.fromJson(json)).toList();
  }

  // Reddedilen araçları getir
  Future<List<Vehicle>> getRejectedVehicles() async {
    final response = await _supabase
        .from('vehicles')
        .select()
        .eq('is_approved', false)
        .not('rejection_reason', 'is', null)
        .order('rejected_at', ascending: false);

    return (response as List).map((json) => Vehicle.fromJson(json)).toList();
  }

  // Plakaya göre araç ara
  Future<List<Vehicle>> searchVehiclesByPlate(String plate) async {
    final response = await _supabase
        .from('vehicles')
        .select()
        .ilike('plate', '%$plate%')
        .order('created_at', ascending: false);

    return (response as List).map((json) => Vehicle.fromJson(json)).toList();
  }

  // Alternatif: Tüm araçları getirip manuel filtreleme
  Future<List<Vehicle>> getPendingVehiclesManual() async {
    final allVehicles = await getAllVehicles();
    return allVehicles.where((vehicle) {
      return !vehicle.isApproved &&
          (vehicle.rejectionReason == null || vehicle.rejectionReason!.isEmpty);
    }).toList();
  }

  Future<List<Vehicle>> getRejectedVehiclesManual() async {
    final allVehicles = await getAllVehicles();
    return allVehicles.where((vehicle) {
      return !vehicle.isApproved &&
          vehicle.rejectionReason != null &&
          vehicle.rejectionReason!.isNotEmpty;
    }).toList();
  }
}