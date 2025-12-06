import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/utils/constants.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _cachedUser;

  static const String _supabaseUrl = 'https://zxhvyfbzhuvbcnuxsaxq.supabase.co';
  static const String _apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4aHZ5ZmJ6aHV2YmNudXhzYXhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2ODg5MzMsImV4cCI6MjA3NTI2NDkzM30.rFB-7LP_ccNWrPXIpfTuwAW9zdgRXeX0w79kra5P0uQ';

  // STATIC GETTER'lar
  static String get supabaseUrl => _supabaseUrl;

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
    'apikey': _apiKey,
    'Prefer': 'return=representation',
  };

  // MEB Client oluşturma metodu - STATIC
  static http.Client createMebClient() {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(httpClient);
  }

  // GERÇEK DATABASE LOGIN
  Future<Map<String, dynamic>> login(String email, String password) async {
    print('🔐 Login başlatıldı: $email');

    try {
      // Önce HTTP ile database'de kullanıcı ara
      final user = await _findUserInDatabase(email);

      if (user != null) {
        // Basit şifre kontrolü (gerçek uygulamada hash kullanın)
        if (password == '123456') { // Varsayılan şifre
          await _saveUserInfo(user);
          return {'success': true, 'user': user};
        } else {
          return {'success': false, 'error': 'Geçersiz şifre'};
        }
      } else {
        return {'success': false, 'error': 'Kullanıcı bulunamadı'};
      }
    } catch (e) {
      print('❌ Login hatası: $e');
      return {'success': false, 'error': 'Giriş başarısız: $e'};
    }
  }

  // DATABASE'den kullanıcı bul
  Future<Map<String, dynamic>?> _findUserInDatabase(String email) async {
    http.Client? client;

    try {
      print('🔍 Database\'de kullanıcı aranıyor: $email');
      client = createMebClient();

      final response = await client.get(
        Uri.parse('$_supabaseUrl/rest/v1/app_users?email=eq.$email&select=*'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty) {
          final user = data[0] as Map<String, dynamic>;
          print('✅ Kullanıcı bulundu: ${user['email']} - Tip: ${user['user_type']}');
          return user;
        } else {
          print('❌ Kullanıcı bulunamadı: $email');
          return null;
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP kullanıcı arama başarısız, Supabase fallback: $e');

      // Fallback: Supabase client
      try {
        final response = await _supabase
            .from('app_users')
            .select('*')
            .eq('email', email)
            .single();

        print('✅ Supabase kullanıcı bulundu: ${response['email']}');
        return response;
      } catch (supabaseError) {
        print('❌ Tüm bağlantı yöntemleri başarısız: $supabaseError');
        return null;
      }
    } finally {
      client?.close();
    }
  }

  // Kullanıcı bilgilerini kaydet
  Future<void> _saveUserInfo(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user['id']?.toString() ?? '');
    await prefs.setString('user_email', user['email']?.toString() ?? '');
    await prefs.setString('user_name', user['full_name']?.toString() ?? '');
    await prefs.setString('user_type', user['user_type']?.toString() ?? '');
    await prefs.setString('full_name', user['full_name']?.toString() ?? '');
    await prefs.setString('phone', user['phone']?.toString() ?? '');
    await prefs.setString('school_id', user['school_id']?.toString() ?? '');
    await prefs.setBool('is_logged_in', true);

    // Cache'i güncelle
    _cachedUser = user;

    print('✅ Kullanıcı bilgisi local\'e kaydedildi: ${user['email']} - Tip: ${user['user_type']}');
  }

  // Çıkış yap
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _cachedUser = null;
    print('✅ Çıkış yapıldı');
  }

  // Giriş durumunu kontrol et
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  // Kullanıcı bilgilerini getir
  Future<Map<String, dynamic>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getString('user_id') ?? '',
      'email': prefs.getString('user_email') ?? '',
      'name': prefs.getString('user_name') ?? '',
      'user_type': prefs.getString('user_type') ?? '',
      'full_name': prefs.getString('full_name') ?? '',
      'phone': prefs.getString('phone') ?? '',
      'school_id': prefs.getString('school_id') ?? '',
    };
  }

  // Kullanıcı tipine göre yetki kontrolü
  Future<bool> hasPermission(String requiredType) async {
    final user = await getCurrentUser();
    if (user == null) return false;
    return user['user_type'] == requiredType;
  }

  // İlçe kullanıcısı mı kontrolü
  Future<bool> isIlceUser() async {
    final user = await getCurrentUser();
    return user != null && user['user_type'] == Constants.userTypeIlce;
  }

  // Okul kullanıcısı mı kontrolü
  Future<bool> isSchoolUser() async {
    final user = await getCurrentUser();
    return user != null && user['user_type'] == Constants.userTypeSchool;
  }

  // Denetim kullanıcısı mı kontrolü
  Future<bool> isDenetimUser() async {
    final user = await getCurrentUser();
    return user != null && user['user_type'] == Constants.userTypeDenetim;
  }

  // Kullanıcı adını getir
  Future<String?> getCurrentUserName() async {
    final user = await getCurrentUser();
    return user?['full_name'];
  }

  // Kullanıcı tipini getir
  Future<String?> getCurrentUserType() async {
    final user = await getCurrentUser();
    return user?['user_type'];
  }

  // Kullanıcı ID'sini getir
  Future<String?> getCurrentUserId() async {
    final user = await getCurrentUser();
    return user?['id'];
  }

  // Local'den kullanıcı bilgisini getir
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      // Önce cache'den kontrol et
      if (_cachedUser != null) {
        return _cachedUser;
      }

      final prefs = await SharedPreferences.getInstance();

      // Tüm kullanıcı bilgilerini kontrol et
      final userId = prefs.getString('user_id');
      final userEmail = prefs.getString('user_email');
      final userType = prefs.getString('user_type');

      if (userId != null && userEmail != null && userType != null) {
        final user = {
          'id': userId,
          'email': userEmail,
          'name': prefs.getString('user_name') ?? '',
          'user_type': userType,
          'full_name': prefs.getString('full_name') ?? '',
          'phone': prefs.getString('phone') ?? '',
          'school_id': prefs.getString('school_id') ?? '',
        };

        _cachedUser = user; // Cache'e kaydet
        return user;
      }
      return null;
    } catch (e) {
      print('❌ Kullanıcı getirme hatası: $e');
      return null;
    }
  }
}