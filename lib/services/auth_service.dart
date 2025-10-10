import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '/utils/constants.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _cachedUser;

  // Giriş yap
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _supabase
          .from('app_users')
          .select()
          .eq('email', email.toLowerCase())
          .eq('password', password)
          .eq('is_active', true)
          .single();

      if (response != null) {
        await saveUserToLocal(response);
        _cachedUser = response; // Cache'e kaydet
        return {'success': true, 'user': response};
      } else {
        return {'success': false, 'error': 'Kullanıcı adı veya şifre hatalı'};
      }
    } catch (e) {
      print('Giriş hatası: $e');
      return {'success': false, 'error': 'Kullanıcı adı veya şifre hatalı'};
    }
  }

  // Çıkış yap
  Future<void> logout() async {
    try {
      await _removeUserFromLocal();
      _cachedUser = null; // Cache'i temizle
      print('✅ Kullanıcı başarıyla çıkış yaptı');
    } catch (e) {
      print('❌ Çıkış hatası: $e');
    }
  }

  // Kullanıcı bilgisini local'e kaydet
  Future<void> saveUserToLocal(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(user));
      _cachedUser = user; // Cache'i güncelle
      print('✅ Kullanıcı bilgisi local\'e kaydedildi: ${user['email']}');
    } catch (e) {
      print('❌ Kullanıcı kaydetme hatası: $e');
    }
  }

  // Local'den kullanıcı bilgisini sil
  Future<void> _removeUserFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
      print('✅ Kullanıcı bilgisi local\'den silindi');
    } catch (e) {
      print('❌ Kullanıcı silme hatası: $e');
    }
  }

  // Local'den kullanıcı bilgisini getir - ASYNC
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      // Önce cache'den kontrol et
      if (_cachedUser != null) {
        return _cachedUser;
      }

      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (userData != null) {
        final user = jsonDecode(userData);
        _cachedUser = user; // Cache'e kaydet
        return user;
      }
      return null;
    } catch (e) {
      print('❌ Kullanıcı getirme hatası: $e');
      return null;
    }
  }

  // Kullanıcı giriş yapmış mı kontrol et - ASYNC
  Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }

  // Kullanıcı tipine göre yetki kontrolü - ASYNC
  Future<bool> hasPermission(String requiredType) async {
    final user = await getCurrentUser();
    if (user == null) return false;

    return user['user_type'] == requiredType;
  }

  // İlçe kullanıcısı mı kontrolü - ASYNC
  Future<bool> isIlceUser() async {
    final user = await getCurrentUser();
    return user != null && user['user_type'] == 'ilce';
  }
  Future<bool> isSchoolUser() async {
    final user = await getCurrentUser();
    return user != null && user['user_type'] == Constants.userTypeSchool;
  }
  // Kullanıcı adını getir - ASYNC
  Future<String?> getCurrentUserName() async {
    final user = await getCurrentUser();
    return user?['full_name'];
  }

  // Kullanıcı tipini getir - ASYNC
  Future<String?> getCurrentUserType() async {
    final user = await getCurrentUser();
    return user?['user_type'];
  }

  // Kullanıcı ID'sini getir - ASYNC
  Future<String?> getCurrentUserId() async {
    final user = await getCurrentUser();
    return user?['id'];
  }
}