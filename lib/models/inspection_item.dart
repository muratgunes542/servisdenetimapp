class InspectionItem {
  final int id;
  final String question;
  final String description;
  final bool hasDateField;
  final String? dateFieldLabel;
  final String? dateValue;
  final bool isCriticalDate;
  final bool hasInfoField;
  final String? infoLabel;
  final String? infoValue;
  final bool hasYesNoField;
  final bool? yesNoValue;
  final bool reverseScoring;
  final bool isSettingsSection;
  final bool isInfoSection;
  final Map<String, String>? infoData;

  // View Mode için yeni alanlar
  Map<String, dynamic>? viewModeResponse;
  String? status;
  String? nonCompliantDescription;
  List<String>? nonCompliantPhotos;
  String? notes;

  InspectionItem({
    required this.id,
    required this.question,
    this.description = '',
    this.hasDateField = false,
    this.dateFieldLabel,
    this.dateValue,
    this.isCriticalDate = false,
    this.hasInfoField = false,
    this.infoLabel,
    this.infoValue,
    this.hasYesNoField = false,
    this.yesNoValue,
    this.reverseScoring = false,
    this.isSettingsSection = false,
    this.isInfoSection = false,
    this.infoData,

    // View Mode için yeni parametreler
    this.viewModeResponse,
    this.status,
    this.nonCompliantDescription,
    this.nonCompliantPhotos,
    this.notes,
  });

  // View Mode'da cevap durumunu getiren getter'lar
  String get viewModeStatus => viewModeResponse?['status'] ?? status ?? 'not_answered';
  String get viewModeStatusText => viewModeResponse?['text'] ?? _getStatusText(status);
  String get viewModeNotes => viewModeResponse?['notes'] ?? notes ?? '';
  String get viewModeNonCompliantDesc =>
      viewModeResponse?['non_compliant_description'] ?? nonCompliantDescription ?? '';

  String _getStatusText(String? status) {
    switch (status) {
      case 'compliant': return 'Uygun';
      case 'non_compliant': return 'Uygun Değil';
      default: return 'Cevaplanmadı';
    }
  }
}