class Vehicle {
  final String id;
  final String plate;
  final String? model;
  final int? capacity;
  final String? serviceCompany;
  final DateTime? createdAt;
  final String? driverPhotoUrl;
  final String? driverName;
  final DateTime? insuranceExpiry;
  final DateTime? inspectionExpiry;
  final bool isApproved;
  final String? approvedByName;
  final String? approvedByUser;
  final String? transportType;
  final String? driverPhone;
  final String? guideName;
  final int? guideAge;
  final String? guidePhotoUrl;
  final bool? hasReflectiveVest;
  final bool? hasWarningLights;
  final DateTime? approvedAt;
  final DateTime? updatedAt;
  final String? approvedBy;
  final DateTime? driverLicenseExpiry;
  final DateTime? srcCertificateExpiry;
  final DateTime? routePermitExpiry;
  final DateTime? gCertificateExpiry;
  final int? modelYear;
  final String? rejectionReason; // Tabloda rejection_reason
  final String? rejectedBy;
  final DateTime? rejectedAt;

  Vehicle({
    required this.id,
    required this.plate,
    this.model,
    this.capacity,
    this.serviceCompany,
    this.createdAt,
    this.driverPhotoUrl,
    this.driverName,
    this.insuranceExpiry,
    this.inspectionExpiry,
    required this.isApproved,
    this.approvedByName,
    this.approvedByUser,
    this.transportType,
    this.driverPhone,
    this.guideName,
    this.guideAge,
    this.guidePhotoUrl,
    this.hasReflectiveVest,
    this.hasWarningLights,
    this.approvedAt,
    this.updatedAt,
    this.approvedBy,
    this.driverLicenseExpiry,
    this.srcCertificateExpiry,
    this.routePermitExpiry,
    this.gCertificateExpiry,
    this.modelYear,
    this.rejectionReason,
    this.rejectedBy,
    this.rejectedAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id']?.toString() ?? '',
      plate: json['plate'] ?? '',
      model: json['model'],
      capacity: json['capacity'] != null ? int.tryParse(json['capacity'].toString()) : null,
      serviceCompany: json['service_company'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      driverPhotoUrl: json['driver_photo_url'],
      driverName: json['driver_name'],
      insuranceExpiry: json['insurance_expiry'] != null ? DateTime.parse(json['insurance_expiry']) : null,
      inspectionExpiry: json['inspection_expiry'] != null ? DateTime.parse(json['inspection_expiry']) : null,
      isApproved: json['is_approved'] ?? false,
      approvedByName: json['approved_by_name'],
      approvedByUser: json['approved_by_user'],
      transportType: json['transport_type'],
      driverPhone: json['driver_phone'],
      guideName: json['guide_name'],
      guideAge: json['guide_age'] != null ? int.tryParse(json['guide_age'].toString()) : null,
      guidePhotoUrl: json['guide_photo_url'],
      hasReflectiveVest: json['has_reflective_vest'] ?? false,
      hasWarningLights: json['has_warning_lights'] ?? false,
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      approvedBy: json['approved_by'],
      driverLicenseExpiry: json['driver_license_expiry'] != null ? DateTime.parse(json['driver_license_expiry']) : null,
      srcCertificateExpiry: json['src_certificate_expiry'] != null ? DateTime.parse(json['src_certificate_expiry']) : null,
      routePermitExpiry: json['route_permit_expiry'] != null ? DateTime.parse(json['route_permit_expiry']) : null,
      gCertificateExpiry: json['g_certificate_expiry'] != null ? DateTime.parse(json['g_certificate_expiry']) : null,
      modelYear: json['model_year'] != null ? int.tryParse(json['model_year'].toString()) : null,
      rejectionReason: json['rejection_reason'], // Tabloda rejection_reason
      rejectedBy: json['rejected_by'],
      rejectedAt: json['rejected_at'] != null ? DateTime.parse(json['rejected_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plate': plate,
      'model': model,
      'capacity': capacity,
      'service_company': serviceCompany,
      'created_at': createdAt?.toIso8601String(),
      'driver_photo_url': driverPhotoUrl,
      'driver_name': driverName,
      'insurance_expiry': insuranceExpiry?.toIso8601String(),
      'inspection_expiry': inspectionExpiry?.toIso8601String(),
      'is_approved': isApproved,
      'approved_by_name': approvedByName,
      'approved_by_user': approvedByUser,
      'transport_type': transportType,
      'driver_phone': driverPhone,
      'guide_name': guideName,
      'guide_age': guideAge,
      'guide_photo_url': guidePhotoUrl,
      'has_reflective_vest': hasReflectiveVest,
      'has_warning_lights': hasWarningLights,
      'approved_at': approvedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'approved_by': approvedBy,
      'driver_license_expiry': driverLicenseExpiry?.toIso8601String(),
      'src_certificate_expiry': srcCertificateExpiry?.toIso8601String(),
      'route_permit_expiry': routePermitExpiry?.toIso8601String(),
      'g_certificate_expiry': gCertificateExpiry?.toIso8601String(),
      'model_year': modelYear,
      'rejection_reason': rejectionReason,
      'rejected_by': rejectedBy,
      'rejected_at': rejectedAt?.toIso8601String(),
    };
  }

  Vehicle copyWith({
    String? id,
    String? plate,
    String? model,
    int? capacity,
    String? serviceCompany,
    DateTime? createdAt,
    String? driverPhotoUrl,
    String? driverName,
    DateTime? insuranceExpiry,
    DateTime? inspectionExpiry,
    bool? isApproved,
    String? approvedByName,
    String? approvedByUser,
    String? transportType,
    String? driverPhone,
    String? guideName,
    int? guideAge,
    String? guidePhotoUrl,
    bool? hasReflectiveVest,
    bool? hasWarningLights,
    DateTime? approvedAt,
    DateTime? updatedAt,
    String? approvedBy,
    DateTime? driverLicenseExpiry,
    DateTime? srcCertificateExpiry,
    DateTime? routePermitExpiry,
    DateTime? gCertificateExpiry,
    int? modelYear,
    String? rejectionReason,
    String? rejectedBy,
    DateTime? rejectedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      plate: plate ?? this.plate,
      model: model ?? this.model,
      capacity: capacity ?? this.capacity,
      serviceCompany: serviceCompany ?? this.serviceCompany,
      createdAt: createdAt ?? this.createdAt,
      driverPhotoUrl: driverPhotoUrl ?? this.driverPhotoUrl,
      driverName: driverName ?? this.driverName,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      inspectionExpiry: inspectionExpiry ?? this.inspectionExpiry,
      isApproved: isApproved ?? this.isApproved,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedByUser: approvedByUser ?? this.approvedByUser,
      transportType: transportType ?? this.transportType,
      driverPhone: driverPhone ?? this.driverPhone,
      guideName: guideName ?? this.guideName,
      guideAge: guideAge ?? this.guideAge,
      guidePhotoUrl: guidePhotoUrl ?? this.guidePhotoUrl,
      hasReflectiveVest: hasReflectiveVest ?? this.hasReflectiveVest,
      hasWarningLights: hasWarningLights ?? this.hasWarningLights,
      approvedAt: approvedAt ?? this.approvedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      driverLicenseExpiry: driverLicenseExpiry ?? this.driverLicenseExpiry,
      srcCertificateExpiry: srcCertificateExpiry ?? this.srcCertificateExpiry,
      routePermitExpiry: routePermitExpiry ?? this.routePermitExpiry,
      gCertificateExpiry: gCertificateExpiry ?? this.gCertificateExpiry,
      modelYear: modelYear ?? this.modelYear,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
    );
  }
}