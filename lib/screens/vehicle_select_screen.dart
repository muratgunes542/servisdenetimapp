// vehicle_select_screen.dart
import 'package:flutter/material.dart';
import 'inspection_form_screen.dart';
import '/services/database_service.dart';
import '/services/auth_service.dart';

class VehicleSelectScreen extends StatefulWidget {
  @override
  _VehicleSelectScreenState createState() => _VehicleSelectScreenState();
}

class _VehicleSelectScreenState extends State<VehicleSelectScreen> {
  final TextEditingController _plateController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _recentInspections = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRecentInspections();
  }

  // Kullanıcı verilerini yükle
  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _currentUserId = user?['id']?.toString();
        _currentUserName = user?['full_name'];
      });
    } catch (e) {
      print('Kullanıcı verisi yükleme hatası: $e');
    }
  }

  // Gerçek denetim verilerini yükle
  Future<void> _loadRecentInspections() async {
    try {
      print('📊 HYBRID: Son denetimler yükleniyor...');

      setState(() {
        _isLoading = true;
      });

      final inspections = await _dbService.getDashboardInspections();

      print('✅ ${inspections.length} denetim alındı');

      // DEBUG: İlk denetimin okul ve status bilgilerini kontrol et
      if (inspections.isNotEmpty) {
        final firstInspection = inspections.first;
        print('🔍 İLK DENETİM DEBUG:');
        print('   • school_name: ${firstInspection['school_name']}');
        print('   • schools: ${firstInspection['schools']}');
        print('   • result: ${firstInspection['result']}');
        print('   • status: ${firstInspection['status']}');
        print('   • completed_items: ${firstInspection['completed_items']}');
        print('   • total_items: ${firstInspection['total_items']}');

        // Yeni status metodunu test et
        final calculatedStatus = _getStatusFromInspection(firstInspection);
        print('   • Hesaplanan status: $calculatedStatus');
      }

      setState(() {
        _recentInspections = inspections.take(5).toList();
        _isLoading = false;
      });

    } catch (e) {
      print('❌ Denetim yükleme hatası: $e');
      setState(() {
        _recentInspections = [];
        _isLoading = false;
      });
    }
  }

  void _startNewInspection() {
    if (_plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen araç plakasını giriniz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionFormScreen(
          vehiclePlate: _plateController.text.trim().toUpperCase(),
          isNewInspection: true,
        ),
      ),
    );
  }

  void _selectRecentVehicle(Map<String, dynamic> inspection) {
    final plate = inspection['vehicle_plate'] ??
        inspection['vehicles']?['plate'] ??
        '';

    if (plate.isNotEmpty) {
      _showInspectionOptions(inspection, plate);
    }
  }

  // Denetim seçeneklerini göster
  // vehicle_select_screen.dart - _showInspectionOptions DÜZELTMESİ

  void _showInspectionOptions(Map<String, dynamic> inspection, String plate) {
    // OKUL BİLGİSİNİ DOĞRU YERDEN AL - school_name sütunundan
    final schoolName = inspection['school_name'] ??
        inspection['schools']?['name'] ??
        'Bilinmeyen Okul';

    final inspectorName = inspection['inspector_name'] ?? 'Denetçi Bilinmiyor';
    final inspectionDate = inspection['inspection_date'] != null
        ? _formatDate(inspection['inspection_date'])
        : 'Tarih Bilinmiyor';

    // STATUS BİLGİSİNİ DÜZELT
    final status = _getStatusFromInspection(inspection); // YENİ METOD

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Denetim Seçeneği',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Plaka: $plate',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Son Denetim: $inspectionDate',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              'Denetçi: $inspectorName',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              'Okul: $schoolName', // ✅ ARTIK DOĞRU GÖSTERECEK
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            // STATUS BİLGİSİNİ EKLE
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getStatusColor(status)),
              ),
              child: Text(
                'Durum: ${_getStatusText(status)}',
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(height: 20),

            // ... butonlar aynı kalacak
            // YENİ DENETİM BUTONU
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startNewInspectionWithPlate(plate, inspection);
                },
                icon: Icon(Icons.add_circle_outline, size: 20),
                label: Text('YENİ DENETİM BAŞLAT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),

            // DENETİMİ GÖRÜNTÜLE BUTONU
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _viewInspectionDetails(inspection);
                },
                icon: Icon(Icons.visibility_outlined, size: 20),
                label: Text('DENETİMİ GÖRÜNTÜLE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),

            // BAŞKA OKUL İÇİN KAYDET BUTONU
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _duplicateInspectionForNewSchool(inspection, plate);
                },
                icon: Icon(Icons.copy_outlined, size: 20),
                label: Text('BAŞKA OKUL İÇİN KAYDET'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),

            // İPTAL BUTONU
            SizedBox(
              width: double.infinity,
              height: 45,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('İPTAL', style: TextStyle(color: Colors.grey[600])),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Inspection'dan status bilgisini doğru al
  String _getStatusFromInspection(Map<String, dynamic> inspection) {
    // 1. Önce 'result' alanına bak
    final result = inspection['result']?.toString().toLowerCase();
    if (result != null && result.isNotEmpty) {
      return result;
    }

    // 2. Sonra 'status' alanına bak
    final status = inspection['status']?.toString().toLowerCase();
    if (status != null && status.isNotEmpty) {
      return status;
    }

    // 3. completed_items ve total_items'a göre hesapla
    final completedItems = inspection['completed_items'] ?? 0;
    final totalItems = inspection['total_items'] ?? 0;

    if (completedItems == 0) return 'başlatılmadı';
    if (completedItems == totalItems) return 'tamamlandı';
    return 'devam_ediyor';
  }

// Status renkleri - GÜNCELLENDİ
  Color _getStatusColor(String status) {
    switch (status) {
      case 'compliant':
      case 'uygun':
      case 'tamamlandı':
        return Colors.green;

      case 'conditional':
      case 'şartlı':
      case 'devam_ediyor':
        return Colors.orange;

      case 'non_compliant':
      case 'uygun_değil':
      case 'başlatılmadı':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

// Status metinleri - GÜNCELLENDİ
  String _getStatusText(String status) {
    switch (status) {
      case 'compliant':
      case 'uygun':
        return 'Uygun';

      case 'conditional':
      case 'şartlı':
        return 'Şartlı';

      case 'non_compliant':
      case 'uygun_değil':
        return 'Uygun Değil';

      case 'tamamlandı':
        return 'Tamamlandı';

      case 'devam_ediyor':
        return 'Devam Ediyor';

      case 'başlatılmadı':
        return 'Başlatılmadı';

      default:
        return status; // Orijinal değeri göster
    }
  }

  // Plaka ile yeni denetim başlat
  void _startNewInspectionWithPlate(String plate, Map<String, dynamic>? previousInspection) {
    setState(() {
      _plateController.text = plate;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionFormScreen(
          vehiclePlate: plate,
          isNewInspection: true,
          previousInspectionData: previousInspection,
        ),
      ),
    );
  }

  // Denetim detaylarını görüntüle
  void _viewInspectionDetails(Map<String, dynamic> inspection) {
    final plate = inspection['vehicle_plate'] ??
        inspection['vehicles']?['plate'] ??
        '';

    if (plate.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InspectionFormScreen(
            vehiclePlate: plate,
            isNewInspection: false,
            previousInspectionData: inspection,
            isViewMode: true, // ✅ BU SATIRI EKLEYİN
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plaka bilgisi bulunamadı')),
      );
    }
  }

  // Başka okul için kopyala
  void _duplicateInspectionForNewSchool(Map<String, dynamic> inspection, String plate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionFormScreen(
          vehiclePlate: plate,
          isNewInspection: false,
          previousInspectionData: inspection,
          isDuplicateForNewSchool: true,
          isViewMode: false, // ✅ BU SATIRI EKLEYİN - EDIT MODE'DA AÇILSIN
        ),
      ),
    );
  }

  // Denetim özetini göster
  void _showInspectionSummary(Map<String, dynamic> inspection) {
    final vehicle = inspection['vehicles'] is Map ? inspection['vehicles'] : {};
    final school = inspection['schools'] is Map ? inspection['schools'] : {};

    final plate = inspection['vehicle_plate'] ?? vehicle['plate'] ?? 'Plaka Yok';
    final model = vehicle['model'] ?? '';
    final driverName = vehicle['driver_name'] ?? '';
    final schoolName = school['name'] ?? 'Okul Bilinmiyor';
    final inspectorName = inspection['inspector_name'] ?? 'Denetçi Bilinmiyor';
    final status = inspection['status'] ?? 'unknown';
    final date = inspection['inspection_date'] ?? '';
    final completedItems = inspection['completed_items'] ?? 0;
    final totalItems = inspection['total_items'] ?? 0;
    final notes = inspection['notes'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Denetim Detayları'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Plaka', plate),
              _buildDetailRow('Model', model),
              _buildDetailRow('Sürücü', driverName),
              _buildDetailRow('Okul', schoolName),
              _buildDetailRow('Denetçi', inspectorName),
              _buildDetailRow('Tarih', _formatDate(date)),
              _buildDetailRow('Durum', _getStatusText(status)),
              _buildDetailRow('Skor', '$completedItems/$totalItems'),
              if (notes.isNotEmpty) _buildDetailRow('Notlar', notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _duplicateInspectionForNewSchool(inspection, plate);
            },
            child: Text('Başka Okul İçin Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }



  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFFE3F2FD),
        title: Text(
          'Yeni Denetim',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık ve plaka girişi (önceki kod aynı)
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.directions_bus, size: 60, color: Color(0xFF2196F3)),
                        SizedBox(height: 10),
                        Text('Araç Seçimi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        SizedBox(height: 5),
                        Text('Araç plakasını girin veya kamerayla okutun', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),

                  // Plaka Giriş Alanı (önceki kod aynı)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Araç Plakası', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          TextField(
                            controller: _plateController,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            decoration: InputDecoration(
                              hintText: '34 ABC 123',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF2196F3), width: 2)),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 40),

                  // Son Denetlenen Araçlar
                  Row(
                    children: [
                      Text('SON DENETLENEN ARAÇLAR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Spacer(),
                      if (_recentInspections.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.refresh, size: 20, color: Color(0xFF2196F3)),
                          onPressed: _loadRecentInspections,
                          tooltip: 'Yenile',
                        ),
                    ],
                  ),
                  SizedBox(height: 15),

                  if (_isLoading)
                    Center(child: Padding(padding: EdgeInsets.all(20), child: Column(children: [CircularProgressIndicator(), SizedBox(height: 10), Text('Denetimler yükleniyor...')])))

                  else if (_recentInspections.isEmpty)
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                            SizedBox(height: 10),
                            Text('Henüz denetim bulunmuyor', style: TextStyle(color: Colors.grey[600])),
                            SizedBox(height: 5),
                            Text('İlk denetimi başlatmak için plaka girin', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ),
                    )

                  else
                    ..._recentInspections.map((inspection) {
                      final vehicle = inspection['vehicles'] is Map ? inspection['vehicles'] : {};
                      final school = inspection['schools'] is Map ? inspection['schools'] : {};

                      final plate = inspection['vehicle_plate'] ?? vehicle['plate'] ?? 'Plaka Yok';
                      final model = vehicle['model'] ?? '';
                      final driverName = vehicle['driver_name'] ?? '';

                      // OKUL BİLGİSİ - SCHOOL_NAME SÜTUNUNDAN AL
                      final schoolName = inspection['school_name'] ??
                          school['name'] ??
                          'Okul Bilinmiyor';

                      final inspectorName = inspection['inspector_name'] ?? 'Denetçi Bilinmiyor';

                      // STATUS BİLGİSİ - YENİ METOD İLE AL
                      final status = _getStatusFromInspection(inspection);

                      final date = inspection['inspection_date'] ?? '';
                      final completedItems = inspection['completed_items'] ?? 0;
                      final totalItems = inspection['total_items'] ?? 0;

                      return Card(
                        elevation: 1,
                        margin: EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.directions_bus, color: _getStatusColor(status), size: 30),
                          ),
                          title: Text(plate, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (model.isNotEmpty) Text('$model'),
                              if (driverName.isNotEmpty) Text('Sürücü: $driverName'),
                              Text('Okul: $schoolName'), // ✅ DOĞRU OKUL BİLGİSİ
                              Text('Denetçi: $inspectorName'),
                              Text('${_formatDate(date)} • $completedItems/$totalItems',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getStatusText(status), // ✅ DOĞRU STATUS METNİ
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: _getStatusColor(status),
                                      fontWeight: FontWeight.w600
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _selectRecentVehicle(inspection),
                        ),
                      );
                    }).toList(),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Alt Buton
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[300]!))),
            child: SizedBox(
              width: 120,
              height: 55,
              child: ElevatedButton(
                onPressed: _plateController.text.isNotEmpty ? _startNewInspection : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2196F3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: Text('DEVAM ET ➔', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}