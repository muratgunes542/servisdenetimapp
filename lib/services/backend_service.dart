import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendService {
  static const String baseUrl = 'https://sizin-backend-url.com/api';

  // Headers - MEB firewall'ı için gerekli olabilir
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'ServisDenetimApp/1.0',
  };

  // Araçları getir
  static Future<List<dynamic>> getVehicles() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Backend araç getirme hatası: $e');
      throw e;
    }
  }

  // Araç onayla
  static Future<void> approveVehicle(String vehicleId, String approvedBy) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicles/$vehicleId/approve'),
        headers: headers,
        body: json.encode({'approvedBy': approvedBy}),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Backend araç onaylama hatası: $e');
      throw e;
    }
  }
}