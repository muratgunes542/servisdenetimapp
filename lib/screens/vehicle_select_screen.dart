import 'package:flutter/material.dart';
import 'inspection_form_screen.dart';

class VehicleSelectScreen extends StatefulWidget {
  @override
  _VehicleSelectScreenState createState() => _VehicleSelectScreenState();
}

class _VehicleSelectScreenState extends State<VehicleSelectScreen> {
  final TextEditingController _plateController = TextEditingController();
  final List<Map<String, dynamic>> _recentVehicles = [
    {
      'plate': '34 ABC 123',
      'model': 'Mercedes Sprinter',
      'studentCount': '25',
      'lastInspection': '2 gün önce',
    },
    {
      'plate': '35 DEF 456',
      'model': 'Ford Transit',
      'studentCount': '18',
      'lastInspection': '1 hafta önce',
    },
    {
      'plate': '34 GHI 789',
      'model': 'Volkswagen Crafter',
      'studentCount': '22',
      'lastInspection': '3 gün önce',
    },
  ];

  void _startInspection() {
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
          vehiclePlate: _plateController.text,
        ),
      ),
    );
  }

  void _selectRecentVehicle(Map<String, dynamic> vehicle) {
    setState(() {
      _plateController.text = vehicle['plate'];
    });
    _startInspection();
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
          // Ana İçerik - KAYDIRMA EKLENDİ
          Expanded(
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.directions_bus,
                          size: 60,
                          color: Color(0xFF2196F3),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Araç Seçimi',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Araç plakasını girin veya kamerayla okutun',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40),

                  // Plaka Giriş Alanı
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Araç Plakası',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: _plateController,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: '34 ABC 123',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Color(0xFF2196F3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // VEYA Bölümü
                  Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 15),
                        child: Text(
                          'VEYA',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Kamera Butonu
                  Card(
                    elevation: 2,
                    child: SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: TextButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Kamera özelliği yakında eklenecek'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                        icon: Icon(Icons.camera_alt, size: 30, color: Colors.white),
                        label: Text(
                          'KAMERA İLE PLAKA OKUT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 40),

                  // Son Denetlenen Araçlar
                  Text(
                    'SON DENETLENEN ARAÇLAR',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 15),

                  ..._recentVehicles.map((vehicle) => Card(
                    elevation: 1,
                    margin: EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.directions_bus,
                          color: Color(0xFF2196F3),
                          size: 30,
                        ),
                      ),
                      title: Text(
                        vehicle['plate'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${vehicle['model']} • ${vehicle['studentCount']} öğrenci'),
                          Text(
                            vehicle['lastInspection'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () => _selectRecentVehicle(vehicle),
                    ),
                  )).toList(),

                  SizedBox(height: 20), // Alt boşluk
                ],
              ),
            ),
          ),

          // Alt Buton
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _plateController.text.isNotEmpty ? _startInspection : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2196F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: Text(
                  'DEVAM ET ➔',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}