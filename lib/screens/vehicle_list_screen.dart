//vehicle_list_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/database_service.dart';
import '/utils/constants.dart';
import 'vehicle_edit_screen.dart';

class VehicleListScreen extends StatefulWidget {
  @override
  _VehicleListScreenState createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();

  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filteredVehicles = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final response = await _supabase
          .from(Constants.vehiclesTable)
          .select('''
            *,
            inspections(
              inspection_date,
              total_score,
              status,
              inspector_name
            )
          ''')
          .order('plate');

      setState(() {
        _vehicles = response;
        _filteredVehicles = response;
        _isLoading = false;
      });
    } catch (e) {
      print('Araçları yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  void _searchVehicles(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredVehicles = _vehicles;
      } else {
        _filteredVehicles = _vehicles.where((vehicle) {
          final plate = vehicle['plate']?.toString().toLowerCase() ?? '';
          final model = vehicle['model']?.toString().toLowerCase() ?? '';
          return plate.contains(query.toLowerCase()) ||
              model.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Map<String, dynamic> _getVehicleStats(Map<String, dynamic> vehicle) {
    final inspections = List<Map<String, dynamic>>.from(vehicle['inspections'] ?? []);

    if (inspections.isEmpty) {
      return {
        'lastInspection': null,
        'totalInspections': 0,
        'averageScore': 0,
        'status': 'no_inspection',
      };
    }

    // Son denetimi bul
    inspections.sort((a, b) {
      final dateA = DateTime.parse(a['inspection_date']);
      final dateB = DateTime.parse(b['inspection_date']);
      return dateB.compareTo(dateA);
    });

    final lastInspection = inspections.first;
    final totalScore = inspections.fold(0, (sum, inspection) {
      final score = inspection['total_score'];
      return sum + (score is int ? score : 0);
    });
    final averageScore = totalScore / inspections.length;

    return {
      'lastInspection': lastInspection,
      'totalInspections': inspections.length,
      'averageScore': averageScore,
      'status': lastInspection['status'],
    };
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'compliant': return Colors.green;
      case 'conditional': return Colors.orange;
      case 'non_compliant': return Colors.red;
      case 'no_inspection': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'compliant': return 'Uygun';
      case 'conditional': return 'Şartlı Uygun';
      case 'non_compliant': return 'Uygun Değil';
      case 'no_inspection': return 'Denetim Yok';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFFE3F2FD),
        title: Text(
          'Denetlenen Araçlar',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFF2196F3)),
            onPressed: _loadVehicles,
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama Kutusu
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              onChanged: _searchVehicles,
              decoration: InputDecoration(
                hintText: 'Plaka veya model ara...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // İstatistik
          _buildStats(),

          // Araç Listesi
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredVehicles.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Henüz araç bulunmuyor'
                        : 'Arama sonucu bulunamadı',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredVehicles.length,
              itemBuilder: (context, index) {
                final vehicle = _filteredVehicles[index];
                return _buildVehicleCard(vehicle);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final totalVehicles = _vehicles.length;
    final vehiclesWithInspections = _vehicles.where((v) {
      final inspections = List<Map<String, dynamic>>.from(v['inspections'] ?? []);
      return inspections.isNotEmpty;
    }).length;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Toplam Araç', totalVehicles.toString(), Icons.directions_car),
            _buildStatItem('Denetlenen', vehiclesWithInspections.toString(), Icons.assessment),
            _buildStatItem('Oran', '${totalVehicles > 0 ? ((vehiclesWithInspections / totalVehicles) * 100).toStringAsFixed(1) : 0}%',
                Icons.trending_up),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Color(0xFF2196F3)),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final stats = _getVehicleStats(vehicle);

    // DOĞRU VERİLERİ ALALIM - ESKİ VE YENİ SİSTEM UYUMLU
    final plate = vehicle['plate'] ?? 'Plaka Yok';
    final model = vehicle['model'] ?? 'Model Belirtilmemiş';

    // SÜRÜCÜ BİLGİSİ - ESKİ VE YENİ SİSTEM UYUMLU
    final driverName = vehicle['driver_name'] ??
        vehicle['driver_full_name'] ??
        'Sürücü Belirtilmemiş';

    // TAŞIMA TÜRÜ
    final transportType = vehicle['transport_type'] ?? 'private';
    final transportTypeText = transportType == 'private' ? 'Özel Taşıma' : 'Devlet Taşıması';

    // DURUM RENK VE İKON
    final statusColor = _getStatusColor(stats['status']);
    final statusIcon = _getStatusIcon(stats['status']);

    final recentInspections = List<Map<String, dynamic>>.from(vehicle['inspections'] ?? []);
    final lastInspection = recentInspections.isNotEmpty ? recentInspections.first : null;

    // SON DENETİM OKUL BİLGİSİ - GÜNCELLENMİŞ 👏👏👏
    final lastInspectionDate = lastInspection?['inspection_date'];
    final lastSchool = lastInspection?['school_name'] ??
        lastInspection?['schools']?['name'] ??
        'Okul Bilinmiyor';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
          ),
          child: Icon(
            statusIcon,
            color: statusColor,
            size: 24,
          ),
        ),

        // ANA İÇERİK - OKUL BİLGİSİ EKLENDİ 👏👏👏
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PLAKA - DAHA BELİRGİN
            Text(
              plate,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 2),

            // OKUL BİLGİSİ - YENİ EKLENDİ 👏👏👏👏
            if (lastSchool != null && lastSchool != 'Okul Bilinmiyor')
              Row(
                children: [
                  Icon(Icons.school, size: 12, color: Colors.purple[600]),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      lastSchool,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
              SizedBox(height: 2),
          ],
        ),

        // ALT BİLGİLER - GÜNCELLENDİ 👏
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 6),

            // SÜRÜCÜ BİLGİSİ - NET BİR ŞEKİLDE
            Row(
              children: [
                Icon(Icons.person, size: 12, color: Colors.grey[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    driverName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2),

            // TAŞIMA TÜRÜ
            Row(
              children: [
                Icon(Icons.category, size: 12, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  transportTypeText,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),

            // DENETİM BİLGİSİ - GÜNCELLENDİ 👏👏👏
            if (lastInspection != null) ...[
              Text(
                'Son denetim: ${_formatDate(lastInspectionDate)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.pending, size: 12, color: Colors.orange[600]),
                  SizedBox(width: 4),
                  Text(
                    'Henüz denetim yapılmamış',
                    style: TextStyle(fontSize: 11, color: Colors.orange[700], fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],
          ],
        ),

        // SAĞ TARAF - BUTONLAR VE DURUM (AYNI KALACAK)
        trailing: Container(
          constraints: BoxConstraints(minWidth: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // DÜZENLE BUTONU
              IconButton(
                icon: Icon(Icons.edit, size: 20, color: Colors.blue[700]),
                onPressed: () {
                  _editVehicle(vehicle);
                },
                tooltip: 'Aracı Düzenle',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 36, minHeight: 36),
              ),

              // DURUM VE SKOR BİLGİSİ
              if (lastInspection != null) ...[
                SizedBox(height: 4),
                Text(
                  '${lastInspection['total_score'] ?? 0}/32',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _getStatusText(stats['status']),
                    style: TextStyle(
                      fontSize: 9,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Denetim Yok',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // TIKLANABİLİRLİK
        onTap: () {
          _showVehicleDetails(vehicle);
        },
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

// DURUM İKONU İÇİN YARDIMCI METOD
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'compliant':
        return Icons.check_circle;
      case 'conditional':
        return Icons.warning;
      case 'non_compliant':
        return Icons.error;
      case 'no_inspection':
      default:
        return Icons.directions_bus;
    }
  }



// TARİH FORMATLAMA (ZATEN VAR OLAN)
  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Belirtilmemiş';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _editVehicle(Map<String, dynamic> vehicle) async {
    // Tüm ilgili verileri yükle
    try {
      final vehicleId = vehicle['id'];

      // Paralel olarak tüm verileri yükle
      final results = await Future.wait([
        _dbService.getDriverByVehicleId(vehicleId),
        _dbService.getAttendantByVehicleId(vehicleId),
        _dbService.getDocumentsByVehicleId(vehicleId),
      ]);

      final driverData = results[0];
      final attendantData = results[1];
      final documentsData = results[2];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleEditScreen(
            vehicle: vehicle,
            driverData: driverData,
            attendantData: attendantData,
            documentsData: documentsData,
          ),
        ),
      ).then((refresh) {
        if (refresh == true) {
          _loadVehicles();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Araç bilgileri güncellendi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });

    } catch (e) {
      print('Veri yükleme hatası: $e');
      // Hata durumunda boş verilerle aç
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleEditScreen(
            vehicle: vehicle,
            driverData: null,
            attendantData: null,
            documentsData: null,
          ),
        ),
      );
    }
  }

  void _showVehicleDetails(Map<String, dynamic> vehicle) {
    final stats = _getVehicleStats(vehicle);
    final inspections = List<Map<String, dynamic>>.from(vehicle['inspections'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Araç Detayları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            _buildDetailItem('Plaka', vehicle['plate'] ?? 'Belirtilmemiş'),
            _buildDetailItem('Model', vehicle['model'] ?? 'Belirtilmemiş'),
            _buildDetailItem('Kapasite', vehicle['capacity']?.toString() ?? 'Belirtilmemiş'),
            _buildDetailItem('Toplam Denetim', stats['totalInspections'].toString()),
            if (stats['averageScore'] > 0)
              _buildDetailItem('Ortalama Puan', stats['averageScore'].toStringAsFixed(1)),
            SizedBox(height: 16),
            if (inspections.isNotEmpty) ...[
              Text(
                'Denetim Geçmişi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              ...inspections.take(3).map((inspection) =>
                  _buildInspectionHistoryItem(inspection)
              ).toList(),
            ],
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('KAPAT'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildInspectionHistoryItem(Map<String, dynamic> inspection) {
    final date = DateTime.parse(inspection['inspection_date']);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getStatusColor(inspection['status']).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            inspection['status'] == 'compliant' ? Icons.check_circle : Icons.warning,
            color: _getStatusColor(inspection['status']),
          ),
        ),
        title: Text('${inspection['inspector_name']}'),
        subtitle: Text('${date.day}/${date.month}/${date.year}'),
        trailing: Text(
          '${inspection['total_score']}/32',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _getStatusColor(inspection['status']),
          ),
        ),
      ),
    );
  }



}