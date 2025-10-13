import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '科学发展地图',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  double selectedYear = 1500;
  bool isPlaying = false;
  Timer? _timer;
  
  final List<Map<String, dynamic>> events = [
    {
      'id': 'newton',
      'title': '牛顿《原理》',
      'year': 1687,
      'lat': 52.2053,
      'lng': 0.1218,
      'city': '剑桥',
      'influences': ['copernicus'],
    },
    {
      'id': 'einstein',
      'title': '爱因斯坦相对论',
      'year': 1905,
      'lat': 46.9481,
      'lng': 7.4474,
      'city': '伯尔尼',
      'influences': ['newton', 'maxwell'],
    },
    {
      'id': 'dna',
      'title': 'DNA双螺旋',
      'year': 1953,
      'lat': 52.2253,
      'lng': 0.1418,
      'city': '剑桥',
      'influences': [],
    },
    {
      'id': 'curie',
      'title': '居里夫人发现镭',
      'year': 1898,
      'lat': 48.8566,
      'lng': 2.3522,
      'city': '巴黎',
      'influences': [],
    },
    {
      'id': 'maxwell',
      'title': '麦克斯韦方程组',
      'year': 1865,
      'lat': 55.9533,
      'lng': -3.1883,
      'city': '爱丁堡',
      'influences': ['newton'],
    },
    {
      'id': 'quantum',
      'title': '量子力学诞生',
      'year': 1925,
      'lat': 52.5200,
      'lng': 13.4050,
      'city': '柏林',
      'influences': ['einstein', 'maxwell'],
    },
    {
      'id': 'copernicus',
      'title': '哥白尼日心说',
      'year': 1543,
      'lat': 54.3520,
      'lng': 18.6466,
      'city': '但泽',
      'influences': [],
    },
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      isPlaying = !isPlaying;
    });

    if (isPlaying) {
      _startAnimation();
    } else {
      _stopAnimation();
    }
  }

  void _startAnimation() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {
        selectedYear += 2;
        
        if (selectedYear >= 2000) {
          selectedYear = 2000;
          _stopAnimation();
        }
      });
    });
  }

  void _stopAnimation() {
    _timer?.cancel();
    setState(() {
      isPlaying = false;
    });
  }

  void _resetAnimation() {
    _stopAnimation();
    setState(() {
      selectedYear = 1500;
    });
  }

  List<Map<String, dynamic>> getFilteredEvents() {
    return events.where((event) => event['year'] <= selectedYear).toList();
  }

  List<Map<String, dynamic>> getInfluenceLines() {
    List<Map<String, dynamic>> lines = [];
    var filteredEvents = getFilteredEvents();
    
    for (var event in filteredEvents) {
      if (event['influences'] != null) {
        for (var influenceId in event['influences']) {
          var sourceEvent = events.firstWhere(
            (e) => e['id'] == influenceId,
            orElse: () => {},
          );
          
          if (sourceEvent.isNotEmpty && 
              sourceEvent['year'] <= selectedYear) {
            lines.add({
              'from': LatLng(sourceEvent['lat'], sourceEvent['lng']),
              'to': LatLng(event['lat'], event['lng']),
              'fromTitle': sourceEvent['title'],
              'toTitle': event['title'],
              'fromYear': sourceEvent['year'],
              'toYear': event['year'],
            });
          }
        }
      }
    }
    
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('科学发展地图'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(30, 0),
              initialZoom: 2,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.science_map',
              ),
              
              PolylineLayer(
                polylines: getInfluenceLines().map((line) {
                  return Polyline(
                    points: [line['from'], line['to']],
                    strokeWidth: 3.0,
                    color: Colors.blue.withOpacity(0.7),
                    borderStrokeWidth: 1.0,
                    borderColor: Colors.white.withOpacity(0.5),
                  );
                }).toList(),
              ),
              
              MarkerLayer(
                markers: getInfluenceLines().map((line) {
                  LatLng midPoint = LatLng(
                    (line['from'].latitude + line['to'].latitude) / 2,
                    (line['from'].longitude + line['to'].longitude) / 2,
                  );
                  
                  double angle = math.atan2(
                    line['to'].latitude - line['from'].latitude,
                    line['to'].longitude - line['from'].longitude,
                  );
                  
                  return Marker(
                    point: midPoint,
                    width: 30,
                    height: 30,
                    child: GestureDetector(
                      onTap: () => _showInfluenceDialog(line),
                      child: Transform.rotate(
                        angle: angle + math.pi / 2,
                        child: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
             MarkerLayer(
  markers: getFilteredEvents().map((event) {
    return Marker(
      point: LatLng(event['lat'], event['lng']),
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () => _showEventDialog(event),
        child: Column(
          children: [
            // 外圈光晕效果
Container(
  width: 40,
  height: 40,
  decoration: BoxDecoration(
    color: Colors.transparent,  // 透明背景
    shape: BoxShape.circle,
  ),
  child: Center(
    child: Text(
      '💡',
      style: TextStyle(fontSize: 30),  // 可以调大一点
    ),
  ),
),
            SizedBox(height: 4),
            // 年份标签
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[300]!, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${event['year']}', 
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[900],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }).toList(),
),
            ],
          ),
          
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '年份: ${selectedYear.round()}',
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    Slider(
                      value: selectedYear,
                      min: 1500,
                      max: 2000,
                      divisions: 500,
                      label: selectedYear.round().toString(),
                      onChanged: isPlaying ? null : (value) {
                        setState(() {
                          selectedYear = value;
                        });
                      },
                    ),
                    
                    SizedBox(height: 8),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.replay),
                          iconSize: 32,
                          color: Colors.blue[700],
                          onPressed: _resetAnimation,
                          tooltip: '重置',
                        ),
                        
                        SizedBox(width: 20),
                        
                        ElevatedButton.icon(
                          onPressed: _togglePlay,
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 32,
                          ),
                          label: Text(
                            isPlaying ? '暂停' : '播放',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24, 
                              vertical: 12
                            ),
                            backgroundColor: isPlaying ? Colors.orange : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 8),
                    
                    Text(
                      '显示 ${getFilteredEvents().length} 个事件 | ${getInfluenceLines().length} 条连线',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEventDialog(Map<String, dynamic> event) {
    var influences = event['influences'] ?? [];
    var influenceNames = <String>[];
    
    for (var id in influences) {
      var e = events.firstWhere((ev) => ev['id'] == id, orElse: () => {});
      if (e.isNotEmpty) {
        influenceNames.add(e['title']);
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('年份: ${event['year']}'),
            Text('地点: ${event['city']}'),
            if (influenceNames.isNotEmpty) ...[
              SizedBox(height: 10),
              Text('受以下影响:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...influenceNames.map((name) => Text('  • $name')),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showInfluenceDialog(Map<String, dynamic> line) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('知识传播'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.arrow_forward, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${line['fromTitle']} (${line['fromYear']})',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(left: 32, top: 8, bottom: 8),
              child: Text('影响了', style: TextStyle(color: Colors.grey)),
            ),
            Row(
              children: [
                Icon(Icons.arrow_forward, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${line['toTitle']} (${line['toYear']})',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }
}