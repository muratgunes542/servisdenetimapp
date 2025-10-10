// utils/helpers.dart - Ortak metodlar için
class Helpers {
  // Tarih formatlama
  static String formatDate(String? dateString) {
    if (dateString == null) return 'Belirtilmemiş';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // Taşıma türü metni
  static String getTransportTypeText(String transportType) {
    switch (transportType) {
      case 'private': return 'Özel Taşıma';
      case 'state': return 'Devlet Taşıması';
      default: return transportType;
    }
  }

  // ID güvenli string'e çevirme
  static String safeToString(dynamic id) {
    if (id == null) return '';
    if (id is String) return id;
    if (id is int) return id.toString();
    return id.toString();
  }
}