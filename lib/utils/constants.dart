class Constants {
  static const String supabaseUrl = 'https://zxhvyfbzhuvbcnuxsaxq.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4aHZ5ZmJ6aHV2YmNudXhzYXhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2ODg5MzMsImV4cCI6MjA3NTI2NDkzM30.rFB-7LP_ccNWrPXIpfTuwAW9zdgRXeX0w79kra5P0uQ';

  // Tablo isimleri
  static const String vehiclesTable = 'vehicles';
  static const String inspectionsTable = 'inspections';
  static const String inspectionDetailsTable = 'inspection_details';
  static const String usersTable = 'app_users';

  // Kullanıcı tipleri
  static const String userTypeIlce = 'ilce';
  static const String userTypeDenetim = 'denetim';
  static const String userTypeSchool = 'school'; // BU SATIRI EKLE

  // Yardımcı metodlar
  static String getUserTypeText(String userType) {
    switch (userType) {
      case userTypeIlce:
        return 'İlçe MEM';
      case userTypeDenetim:
        return 'Denetim Görevlisi';
      case userTypeSchool:
        return 'Okul Kullanıcısı';
      default:
        return userType;
    }
  }
}