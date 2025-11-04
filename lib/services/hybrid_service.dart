import 'package:http/http.dart' as http;
import 'dart:convert';
import 'database_service.dart';

class HybridService {
  final DatabaseService _dbService = DatabaseService();
  static const String _supabaseUrl = 'https://your-project.supabase.co';
  static const String _apiKey = 'your-anon-key';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
    'apikey': _apiKey,
    'Prefer': 'return=representation',
  };

  // Ana metod - otomatik olarak en iyi yöntemi seçer
  Future<List<Map<String, dynamic>>> getVehicles() async {
    print('🔍 En iyi bağlantı yöntemi seçiliyor...');

    try {
      // Önce HTTP ile dene (MEB uyumlu)
      final vehicles = await _getVehiclesHttp();
      print('✅ HTTP üzerinden araçlar alındı: ${vehicles.length} adet');
      return vehicles;
    } catch (httpError) {
      print('❌ HTTP başarısız: $httpError');
      print('🔄 Supabase client fallback deneniyor...');

      try {
        // HTTP çalışmazsa normal Supabase client kullan
        final vehicles = await _dbService.getAllVehicles();
        print('✅ Supabase client ile araçlar alındı: ${vehicles.length} adet');
        return vehicles;
      } catch (clientError) {
        print('❌ Tüm bağlantı yöntemleri başarısız');
        throw clientError;
      }
    }
  }

  // HTTP ile araçları getir
  Future<List<Map<String, dynamic>>> _getVehiclesHttp() async {
    final response = await http.get(
      Uri.parse('$_supabaseUrl/rest/v1/vehicles?select=*'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // HTTP ile araç onayla
  Future<void> approveVehicleHttp(String vehicleId, String approvedBy) async {
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

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // Akıllı onaylama - otomatik yöntem seçer
  Future<void> approveVehicle(String vehicleId, String approvedBy) async {
    try {
      await approveVehicleHttp(vehicleId, approvedBy);
    } catch (e) {
      print('HTTP onay başarısız, fallback: $e');
      await _dbService.approveVehicle(vehicleId, approvedBy);
    }
  }
}