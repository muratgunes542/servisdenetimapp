// models/inspection.dart
class Inspection {
  final String id;
  final String vehiclePlate;
  final String? vehicleModel;
  final String? driverName;
  final String inspectorName;
  final DateTime inspectionDate;
  final String status;
  final int totalScore;
  final int completedItems;
  final String? schoolName;

  Inspection({
    required this.id,
    required this.vehiclePlate,
    this.vehicleModel,
    this.driverName,
    required this.inspectorName,
    required this.inspectionDate,
    required this.status,
    required this.totalScore,
    required this.completedItems,
    this.schoolName,
  });

  // Map'ten Inspection oluştur
  factory Inspection.fromMap(Map<String, dynamic> map) {
    return Inspection(
      id: map['id']?.toString() ?? '',
      vehiclePlate: map['vehicle_plate'] ?? map['plate'] ?? '',
      vehicleModel: map['vehicle_model'] ?? map['model'] ?? '',
      driverName: map['driver_name'] ?? map['driver_full_name'] ?? '',
      inspectorName: map['inspector_name'] ?? '',
      inspectionDate: map['inspection_date'] != null
          ? DateTime.parse(map['inspection_date'])
          : DateTime.now(),
      status: map['status'] ?? 'unknown',
      totalScore: (map['total_score'] ?? map['completed_items'] ?? 0) as int,
      completedItems: (map['completed_items'] ?? map['total_score'] ?? 0) as int,
      schoolName: map['school_name'],
    );
  }

  // Inspection'dan Map oluştur
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_plate': vehiclePlate,
      'vehicle_model': vehicleModel,
      'driver_name': driverName,
      'inspector_name': inspectorName,
      'inspection_date': inspectionDate.toIso8601String(),
      'status': status,
      'total_score': totalScore,
      'completed_items': completedItems,
      'school_name': schoolName,
    };
  }
}