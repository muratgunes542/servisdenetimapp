import 'package:flutter/material.dart';
import 'inspection_form_screen.dart';
import 'school_management_screen.dart';
import '/services/database_service.dart';
import '/services/auth_service.dart';
import '/utils/constants.dart';
import 'ilce_vehicles_screen.dart';
import 'vehicle_select_screen.dart';
import 'vehicle_list_screen.dart';
import 'reports_screen.dart';
import 'user_management_screen.dart';
import 'school_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();

  // State variables - List tipini Map yapın
  String? _userName;
  String? _userType;
  List<Map<String, dynamic>> _recentInspections = []; // Map olarak değiştirildi
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  // Initialize dashboard data
  Future<void> _initializeDashboard() async {
    await _loadUserData();
    await _loadRecentInspections();
    setState(() => _isLoading = false);
  }

  // Load user data from auth service
  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _userName = user?['full_name'];
        _userType = user?['user_type'];
      });
    } catch (e) {
      print('Kullanıcı verisi yükleme hatası: $e');
    }
  }

  // Load recent inspections
  Future<void> _loadRecentInspections() async {
    try {
      print('📊 HYBRID: Dashboard denetimleri yükleniyor...');
      final inspections = await _dbService.getDashboardInspections();

      print('✅ ${inspections.length} denetim alındı');

      setState(() {
        _recentInspections = inspections.take(5).toList();
      });

    } catch (e) {
      print('❌ Dashboard denetim yükleme hatası: $e');
      setState(() {
        _recentInspections = [];
      });
    }
  }


  // Handle user logout
  void _handleLogout() async {
    await _authService.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Show coming soon snackbar
  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Yakında eklenecek'),
        backgroundColor: Colors.blue,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Show school dashboard for school users
    if (_userType == Constants.userTypeSchool) {
      return SchoolDashboardScreen();
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoading() : _buildDashboardContent(),
    );
  }

  // AppBar with user info and actions
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Servis Denetim',
            style: TextStyle(
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          if (_userType != null)
            Text(
              _getUserTypeText(_userType!),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.person, color: Color(0xFF2196F3)),
          onPressed: () => _showComingSoon('Profil'),
          tooltip: 'Profil',
        ),
        IconButton(
          icon: Icon(Icons.logout, color: Color(0xFF2196F3)),
          onPressed: _handleLogout,
          tooltip: 'Çıkış Yap',
        ),
      ],
    );
  }

  // Loading indicator
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Yükleniyor...'),
        ],
      ),
    );
  }

  // Main dashboard content
  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildWelcomeCard(),
          SizedBox(height: 24),
          _buildStatsCards(),
          SizedBox(height: 24),
          _buildActionButtons(),
          SizedBox(height: 24),
          _buildRecentInspections(),
        ],
      ),
    );
  }

  // Welcome card with user info
  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 30,
                child: Icon(
                  _getUserTypeIcon(_userType),
                  size: 30,
                  color: Color(0xFF2196F3),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoş Geldiniz, ${_userName ?? ''} 👋',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getWelcomeSubtitle(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Statistics cards
  Widget _buildStatsCards() {
    final totalInspections = _recentInspections.length;
    final compliantCount = _recentInspections.where((i) => i['status'] == 'compliant').length;
    final nonCompliantCount = _recentInspections.where((i) => i['status'] == 'non_compliant').length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard('Toplam Denetim', totalInspections.toString(), Icons.assessment, Colors.blue),
          SizedBox(width: 12),
          _buildStatCard('Uygun', compliantCount.toString(), Icons.check_circle, Colors.green),
          SizedBox(width: 12),
          _buildStatCard('Uygun Değil', nonCompliantCount.toString(), Icons.warning, Colors.red),
          if (_userType == Constants.userTypeIlce) ...[
            SizedBox(width: 12),
            _buildStatCard('Okul Sayısı', '0', Icons.school, Colors.orange),
          ],
        ],
      ),
    );
  }

  // Single stat card
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 150,
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Action buttons based on user type
  Widget _buildActionButtons() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HIZLI İŞLEMLER',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            // New Inspection Button (All users)
            _buildActionButton(
              'YENİ DENETİM BAŞLAT',
              Icons.add_circle_outline,
              Colors.blue,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => VehicleSelectScreen()),
              ),
            ),
            SizedBox(height: 12),

            // User-specific buttons
            if (_userType == Constants.userTypeIlce) ..._buildIlceButtons(),
            if (_userType == Constants.userTypeDenetim) ..._buildDenetimButtons(),
          ],
        ),
      ),
    );
  }

  // Buttons for Ilce users
  List<Widget> _buildIlceButtons() {
    return [
      _buildActionButton(
        'KULLANICI YÖNETİMİ',
        Icons.people_outline,
        Colors.green,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => UserManagementScreen()),
        ),
      ),
      SizedBox(height: 12),
      _buildActionButton(
        'ARAÇ YÖNETİMİ',
        Icons.directions_bus,
        Colors.purple,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => IlceVehiclesScreen()),
        ),
      ),
      SizedBox(height: 12),
      _buildActionButton(
        'OKUL YÖNETİMİ',
        Icons.school_outlined,
        Colors.orange,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SchoolManagementScreen()),
        ),
      ),
      SizedBox(height: 12),
    ];
  }

// Buttons for Denetim users
  List<Widget> _buildDenetimButtons() {
    return [
      _buildActionButton(
        'DENETİM GEÇMİŞİ',
        Icons.history,
        Colors.purple,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => VehicleListScreen()),
        ),
      ),
      SizedBox(height: 12),
      _buildActionButton(
        'RAPORLAR',
        Icons.bar_chart,
        Colors.teal,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReportsScreen()),
        ),
      ),
      SizedBox(height: 12),
    ];
  }

  // Reusable action button
  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          text,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  // Recent inspections list
  Widget _buildRecentInspections() {
    if (_recentInspections.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.badge_outlined, size: 48, color: Colors.grey[400]),
              SizedBox(height: 12),
              Text(
                'Henüz denetim bulunmuyor',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'İlk denetimi başlatmak için "Yeni Denetim Başlat" butonunu kullanın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'SON DENETİMLER',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, size: 20, color: Color(0xFF2196F3)),
                  onPressed: _loadRecentInspections,
                  tooltip: 'Yenile',
                ),
              ],
            ),
            SizedBox(height: 12),
            ..._recentInspections.map((inspection) =>
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _buildInspectionItem(inspection),
                )
            ).toList(),
          ],
        ),
      ),
    );
  }



  // dashboard_screen.dart - GÜNCELLENMİŞ HALİ

// Single inspection item - GÜNCELLENDİ
  Widget _buildInspectionItem(Map<String, dynamic> inspection) {
    final vehicle = inspection['vehicles'] is Map ? inspection['vehicles'] : {};
    final school = inspection['schools'] is Map ? inspection['schools'] : {};

    // PLATE - GÜVENLİ ALIM
    final plate = inspection['vehicle_plate'] ?? vehicle['plate'] ?? 'Plaka Yok';

    // MODEL - GÜVENLİ ALIM
    final model = vehicle['model'] ?? '';

    // DRIVER NAME - GÜVENLİ ALIM
    final driverName = vehicle['driver_name'] ??
        inspection['driver_data']?['full_name'] ??
        '';

    // SCHOOL NAME - GÜVENLİ ALIM (school_name sütunundan)
    final schoolName = inspection['school_name'] ??
        school['name'] ??
        'Okul Bilinmiyor';

    // INSPECTOR NAME - GÜVENLİ ALIM
    final inspectorName = inspection['inspector_name'] ?? 'Denetçi Bilinmiyor';

    // STATUS - YENİ METOD İLE ALIM
    final status = _getStatusFromInspection(inspection);

    // DATE - GÜVENLİ ALIM
    final date = inspection['inspection_date'] != null
        ? DateTime.parse(inspection['inspection_date'])
        : DateTime.now();

    final totalScore = inspection['total_score'] ?? 0;
    final completedItems = inspection['completed_items'] ?? 0;
    final totalItems = inspection['total_items'] ?? 0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
            size: 20,
          ),
        ),
        title: Text(
          plate,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (model.isNotEmpty) Text('Model: $model'),
            if (driverName.isNotEmpty) Text('Sürücü: $driverName'),
            Text('Okul: $schoolName'), // ✅ OKUL BİLGİSİ EKLENDİ
            Text('$inspectorName • ${_formatDate(date)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$completedItems/$totalItems', // ✅ total_score yerine total_items
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getStatusColor(status),
              ),
            ),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getStatusText(status), // ✅ DOĞRU STATUS METNİ
                style: TextStyle(
                  fontSize: 10,
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          // Denetim detayına git
          _showInspectionDetails(inspection);
        },
      ),
    );
  }

// Denetim detaylarını göster - GÜNCELLENDİ
  void _showInspectionDetails(Map<String, dynamic> inspection) {
    final vehicle = inspection['vehicles'] is Map ? inspection['vehicles'] : {};
    final school = inspection['schools'] is Map ? inspection['schools'] : {};

    // TÜM BİLGİLERİ GÜVENLİ ŞEKİLDE AL
    final plate = inspection['vehicle_plate'] ?? vehicle['plate'] ?? 'Plaka Yok';
    final model = vehicle['model'] ?? 'Model Bilinmiyor';
    final driverName = vehicle['driver_name'] ??
        inspection['driver_data']?['full_name'] ??
        'Sürücü Bilinmiyor';
    final schoolName = inspection['school_name'] ??
        school['name'] ??
        'Okul Bilinmiyor';
    final inspectorName = inspection['inspector_name'] ?? 'Denetçi Bilinmiyor';
    final status = _getStatusFromInspection(inspection);
    final date = inspection['inspection_date'] ?? 'Tarih Bilinmiyor';
    final completedItems = inspection['completed_items'] ?? 0;
    final totalItems = inspection['total_items'] ?? 0;

    // EK BİLGİLER
    final schoolDistrict = school['district'] ?? inspection['school_district'] ?? 'İlçe Bilinmiyor';
    final notes = inspection['notes'] ?? 'Not bulunmuyor';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Denetim Detayları'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // TEMEL BİLGİLER
              _buildDetailRow('Plaka', plate),
              _buildDetailRow('Model', model),
              _buildDetailRow('Sürücü', driverName),
              _buildDetailRow('Okul', schoolName),
              _buildDetailRow('Okul İlçesi', schoolDistrict),
              _buildDetailRow('Denetçi', inspectorName),
              _buildDetailRow('Tarih', _formatDate(
                  date != 'Tarih Bilinmiyor'
                      ? DateTime.parse(date)
                      : DateTime.now()
              )),

              // DURUM VE SKOR
              _buildDetailRow('Durum', _getStatusText(status)),
              _buildDetailRow('Tamamlanan Maddeler', '$completedItems/$totalItems'),

              // NOTLAR
              if (notes != 'Not bulunmuyor')
                _buildDetailRow('Notlar', notes),

              // DETAYLAR (JSON)
              if (inspection['details'] is Map)
                _buildDetailsSection(inspection['details']),
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
              // Bu denetimi görüntüleme sayfasına git
              _viewInspection(inspection);
            },
            child: Text('Denetimi Görüntüle'),
          ),
        ],
      ),
    );
  }

// Detaylar bölümü için yardımcı widget
  Widget _buildDetailsSection(Map<String, dynamic> details) {
    final compliantItems = details.values.where((item) =>
    item is Map && item['status'] == 'compliant').length;
    final nonCompliantItems = details.values.where((item) =>
    item is Map && item['status'] == 'non_compliant').length;
    final totalItems = details.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          'Detaylı Sonuçlar',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        _buildDetailRow('Uygun Maddeler', '$compliantItems/$totalItems'),
        _buildDetailRow('Uygun Olmayan Maddeler', '$nonCompliantItems/$totalItems'),
      ],
    );
  }

// Denetimi görüntüleme sayfasına git
  void _viewInspection(Map<String, dynamic> inspection) {
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
            isViewMode: true,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plaka bilgisi bulunamadı')),
      );
    }
  }
// dashboard_screen.dart - STATUS METODLARI EKLEYELİM

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

// Status renkleri
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

// Status metinleri
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
        return status;
    }
  }

// Status ikonları
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'compliant':
      case 'uygun':
      case 'tamamlandı':
        return Icons.check_circle;

      case 'conditional':
      case 'şartlı':
        return Icons.warning;

      case 'non_compliant':
      case 'uygun_değil':
        return Icons.error;

      case 'devam_ediyor':
        return Icons.access_time;

      case 'başlatılmadı':
        return Icons.pending;

      default:
        return Icons.help;
    }
  }





  // Helper Methods
  String _getUserTypeText(String userType) {
    switch (userType) {
      case Constants.userTypeIlce:
        return 'İlçe MEM Kullanıcısı';
      case Constants.userTypeDenetim:
        return 'Denetim Görevlisi';
      case Constants.userTypeSchool:
        return 'Okul Kullanıcısı';
      default:
        return userType;
    }
  }

  IconData _getUserTypeIcon(String? userType) {
    switch (userType) {
      case Constants.userTypeIlce:
        return Icons.admin_panel_settings;
      case Constants.userTypeDenetim:
        return Icons.assignment_ind;
      case Constants.userTypeSchool:
        return Icons.school;
      default:
        return Icons.person;
    }
  }

  String _getWelcomeSubtitle() {
    switch (_userType) {
      case Constants.userTypeIlce:
        return 'İlçe MEM Denetim Yönetim Paneli';
      case Constants.userTypeDenetim:
        return 'Denetim Görevlisi Paneli';
      case Constants.userTypeSchool:
        return 'Okul Servis Yönetim Paneli';
      default:
        return 'Servis Denetim Sistemi';
    }
  }

  // dashboard_screen.dart - DETAIL ROW WIDGET

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? 'Belirtilmemiş' : value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

// Tarih formatlama
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final inspections = await _dbService.getDashboardInspections();

      // DEBUG: İlk denetimin bilgilerini kontrol et
      if (inspections.isNotEmpty) {
        final firstInspection = inspections.first;
        print('🔍 DASHBOARD İLK DENETİM DEBUG:');
        print('   • vehicle_plate: ${firstInspection['vehicle_plate']}');
        print('   • school_name: ${firstInspection['school_name']}');
        print('   • inspector_name: ${firstInspection['inspector_name']}');
        print('   • vehicles: ${firstInspection['vehicles']}');
        print('   • schools: ${firstInspection['schools']}');
        print('   • result: ${firstInspection['result']}');
        print('   • completed_items: ${firstInspection['completed_items']}');
        print('   • total_items: ${firstInspection['total_items']}');
      }

      setState(() {
        _recentInspections = inspections;
        _isLoading = false;
      });

    } catch (e) {
      print('❌ Dashboard veri yükleme hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

}