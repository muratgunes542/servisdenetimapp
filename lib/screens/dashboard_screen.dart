// screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'school_applications_screen.dart';
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
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  // State variables
  String? _userName;
  String? _userType;
  List<Map<String, dynamic>> _recentInspections = [];
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
      final inspections = await _dbService.getAllInspections();
      setState(() {
        _recentInspections = inspections.take(5).toList();
      });
    } catch (e) {
      print('Denetim yükleme hatası: $e');
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
      backgroundColor: Color(0xFFE3F2FD),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Servis Denetim',
            style: TextStyle(
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.bold,
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
          SizedBox(height: 20),
          _buildStatsCards(),
          SizedBox(height: 20),
          _buildActionButtons(),
          SizedBox(height: 20),
          _buildRecentInspections(),
        ],
      ),
    );
  }

  // Welcome card with user info
  Widget _buildWelcomeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFFE3F2FD),
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
            _buildStatCard('Okul Başvuru', '0', Icons.school, Colors.orange),
          ],
        ],
      ),
    );
  }

  // Single stat card
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        width: 150,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            SizedBox(height: 8),
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
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // New Inspection Button (All users)
            _buildActionButton(
              'YENİ DENETİM BAŞLAT',
              Icons.add,
              Colors.blue,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => VehicleSelectScreen()),
              ),
            ),
            SizedBox(height: 10),

            // User-specific buttons
            if (_userType == Constants.userTypeIlce) ..._buildIlceButtons(),
            if (_userType == Constants.userTypeDenetim) ..._buildDenetimButtons(),
          ],
        ),
      ),
    );
  }

  // Buttons for Ilce users
  // dashboard_screen.dart - İlçe butonlarına ekle
  List<Widget> _buildIlceButtons() {
    return [
      _buildActionButton(
        'KULLANICI YÖNETİMİ',
        Icons.people,
        Colors.green,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => UserManagementScreen()),
        ),
      ),
      SizedBox(height: 10),
      _buildActionButton(
        'ARAÇ YÖNETİMİ',
        Icons.directions_bus,
        Colors.blue,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => IlceVehiclesScreen()),
        ),
      ),
      SizedBox(height: 10),
      _buildActionButton(
        'OKUL BAŞVURULARI', // YENİ
        Icons.school,
        Colors.orange,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SchoolApplicationsScreen()),
        ),
      ),
      SizedBox(height: 10),
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
      SizedBox(height: 10),
      _buildActionButton(
        'RAPORLAR',
        Icons.bar_chart,
        Colors.teal,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReportsScreen()),
        ),
      ),
      SizedBox(height: 10),
    ];
  }

  // Reusable action button
  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  // Recent inspections list
  Widget _buildRecentInspections() {
    if (_recentInspections.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.assessment, size: 48, color: Colors.grey[400]),
              SizedBox(height: 8),
              Text(
                'Henüz denetim bulunmuyor',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
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
                  icon: Icon(Icons.refresh, size: 20),
                  onPressed: _loadRecentInspections,
                  tooltip: 'Yenile',
                ),
              ],
            ),
            SizedBox(height: 8),
            ..._recentInspections.map((inspection) => _buildInspectionItem(inspection)).toList(),
          ],
        ),
      ),
    );
  }

  // Single inspection item
  Widget _buildInspectionItem(Map<String, dynamic> inspection) {
    final vehicle = inspection['vehicles'] ?? {};
    final status = inspection['status'] ?? 'compliant';
    final date = DateTime.parse(inspection['inspection_date']);

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 0),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getStatusColor(status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          status == 'compliant' ? Icons.check_circle : Icons.warning,
          color: _getStatusColor(status),
        ),
      ),
      title: Text(
        vehicle['plate'] ?? 'Plaka Yok',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${inspection['inspector_name']} • ${_formatDate(date)}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${inspection['total_score']}/32',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getStatusColor(status),
            ),
          ),
          Text(
            _getStatusText(status),
            style: TextStyle(
              fontSize: 10,
              color: _getStatusColor(status),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  String _getUserTypeText(String userType) {
    switch (userType) {
      case Constants.userTypeIlce:
        return 'İlçe MEM';
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'compliant':
        return Colors.green;
      case 'conditional':
        return Colors.orange;
      case 'non_compliant':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'compliant':
        return 'Uygun';
      case 'conditional':
        return 'Şartlı';
      case 'non_compliant':
        return 'Uygun Değil';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}