// local_storage_service.dart
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _vehiclesBox = 'vehicles';
  static const String _inspectionsBox = 'inspections';
  static const String _usersBox = 'users';
  static const String _schoolsBox = 'schools';

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);

    // Box'ları aç
    await Hive.openBox<Map<dynamic, dynamic>>(_vehiclesBox);
    await Hive.openBox<Map<dynamic, dynamic>>(_inspectionsBox);
    await Hive.openBox<Map<dynamic, dynamic>>(_usersBox);
    await Hive.openBox<Map<dynamic, dynamic>>(_schoolsBox);

    _isInitialized = true;
    print('✅ Local Storage başlatıldı');
  }

  // VEHICLES
  Future<void> saveVehicle(Map<String, dynamic> vehicle) async {
    final box = Hive.box<Map<dynamic, dynamic>>(_vehiclesBox);
    await box.put(vehicle['id']?.toString() ?? vehicle['plate'], vehicle);
  }

  Future<List<Map<String, dynamic>>> getVehicles() async {
    final box = Hive.box<Map<dynamic, dynamic>>(_vehiclesBox);
    return box.values.map((v) => Map<String, dynamic>.from(v)).toList();
  }

  Future<Map<String, dynamic>?> getVehicleByPlate(String plate) async {
    try {
      final box = Hive.box<Map<dynamic, dynamic>>(_vehiclesBox);
      final normalizedPlate = plate.toUpperCase();

      // firstWhere yerine where kullanıp firstOrNull benzeri bir yaklaşım
      final matchingVehicles = box.values.where((v) {
        final vehiclePlate = (v['plate'] as String?)?.toUpperCase();
        return vehiclePlate == normalizedPlate;
      }).toList();

      if (matchingVehicles.isNotEmpty) {
        return Map<String, dynamic>.from(matchingVehicles.first);
      }

      return null;
    } catch (e) {
      print('❌ Local araç getirme hatası: $e');
      return null;
    }
  }

  Future<void> saveSchools(List<Map<String, dynamic>> schools) async {
    final box = Hive.box<Map<dynamic, dynamic>>(_schoolsBox);
    for (final school in schools) {
      await box.put(school['id']?.toString() ?? school['name'], school);
    }
  }

  Future<Map<String, dynamic>?> getSchoolById(String schoolId) async {
    try {
      final box = Hive.box<Map<dynamic, dynamic>>(_schoolsBox);
      final school = box.get(schoolId);
      return school != null ? Map<String, dynamic>.from(school) : null;
    } catch (e) {
      print('❌ Local school getirme hatası: $e');
      return null;
    }
  }

  Future<void> saveSchool(Map<String, dynamic> school) async {
    final box = Hive.box<Map<dynamic, dynamic>>(_schoolsBox);
    await box.put(school['id']?.toString() ?? school['name'], school);
  }

  Future<List<Map<String, dynamic>>> getSchools() async {
    final box = Hive.box<Map<dynamic, dynamic>>(_schoolsBox);
    return box.values.map((v) => Map<String, dynamic>.from(v)).toList();
  }



  // INSPECTIONS
  Future<void> saveInspection(Map<String, dynamic> inspection) async {
    final box = Hive.box<Map<dynamic, dynamic>>(_inspectionsBox);
    final id = inspection['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(id, {...inspection, 'local_id': id, 'is_synced': false});
  }

  Future<List<Map<String, dynamic>>> getInspections() async {
    final box = Hive.box<Map<dynamic, dynamic>>(_inspectionsBox);
    return box.values.map((v) => Map<String, dynamic>.from(v)).toList();
  }

  Future<List<Map<String, dynamic>>> getPendingInspections() async {
    final box = Hive.box<Map<dynamic, dynamic>>(_inspectionsBox);
    return box.values
        .where((v) => v['is_synced'] == false)
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
  }

  Future<void> markInspectionAsSynced(String localId) async {
    final box = Hive.box<Map<dynamic, dynamic>>(_inspectionsBox);
    final inspection = box.get(localId);
    if (inspection != null) {
      await box.put(localId, {...inspection, 'is_synced': true});
    }
  }

  // Diğer metodlar...
  Future<void> saveUser(Map<String, dynamic> user) async {
    final box = Hive.box<Map<dynamic, dynamic>>(_usersBox);
    await box.put(user['id']?.toString() ?? user['email'], user);
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final box = Hive.box<Map<dynamic, dynamic>>(_usersBox);
    return box.values.map((v) => Map<String, dynamic>.from(v)).toList();
  }
}