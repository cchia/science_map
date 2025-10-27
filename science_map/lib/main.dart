import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';


void main() {
  runApp(ScienceMapApp());
}

// ============================================
// 主应用
// ============================================
class ScienceMapApp extends StatefulWidget {
  @override
  State<ScienceMapApp> createState() => _ScienceMapAppState();
}

class _ScienceMapAppState extends State<ScienceMapApp> {
  Locale _locale = Locale('zh');

  void _changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Science History Map',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'System',
      ),
      locale: _locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('zh', ''),
        Locale('en', ''),
      ],
      home: MapScreen(onLanguageChange: _changeLanguage),
    );
  }
}

// ============================================
// 地图主屏幕
// ============================================
class MapScreen extends StatefulWidget {
  final Function(Locale) onLanguageChange;
  
  const MapScreen({required this.onLanguageChange});
  
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ========== 状态变量 ==========
  // 时间控制
  double selectedYear = 1500;
  bool isPlaying = false;
  Timer? _timer;
  
  // 数据
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> storyModes = [];
  Map<String, dynamic> people = {};
  bool isLoading = true;
  
  // 筛选
  String? selectedStoryMode;
  String searchQuery = '';
  Set<String> selectedFields = {};
  bool showSearchBar = false;

  // ========== 配置数据 ==========
  final Map<String, Color> fieldColors = {
    '物理学': Colors.red,
    '化学': Colors.green,
    '生物学': Colors.blue,
    '数学': Colors.purple,
    '天文学': Colors.orange,
    '医学': Colors.pink,
    '计算机': Colors.cyan,
    '航天': Colors.indigo,
    '综合': Colors.brown,
  };

  final Map<String, String> fieldEmojis = {
    '物理学': '⚛️',
    '化学': '🧪',
    '生物学': '🔬',
    '数学': '📐',
    '天文学': '🔭',
    '医学': '💊',
    '计算机': '💻',
    '航天': '🚀',
    '综合': '📚',
  };

  final Map<String, String> fieldNamesEn = {
    '物理学': 'Physics',
    '化学': 'Chemistry',
    '生物学': 'Biology',
    '数学': 'Mathematics',
    '天文学': 'Astronomy',
    '医学': 'Medicine',
    '计算机': 'Computer Science',
    '航天': 'Space',
    '综合': 'Comprehensive',
  };

  // ========== 生命周期 ==========
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ========== 数据加载 ==========
  Future<void> _loadData() async {
    try {
      // 加载事件索引
      final indexJson = await rootBundle.loadString('assets/events_index.json');
      final List<dynamic> eventIds = json.decode(indexJson);
      
      // 加载所有事件
      List<Map<String, dynamic>> loadedEvents = [];
      for (var eventId in eventIds) {
        try {
          final eventJson = await rootBundle.loadString('assets/events/$eventId.json');
          final eventData = json.decode(eventJson);
          loadedEvents.add(eventData);
        } catch (e) {
          print('⚠️ 加载失败: $eventId');
        }
      }
      
      // 加载学习路径
      final modesJson = await rootBundle.loadString('assets/story_modes.json');
      final modesData = json.decode(modesJson);
      
      setState(() {
        events = loadedEvents;
        storyModes = modesData.cast<Map<String, dynamic>>();
        isLoading = false;
      });
      
      print('✅ 加载完成: ${events.length} 个事件');
    } catch (e) {
      print('❌ 加载失败: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // ========== 辅助方法 ==========
  Color getFieldColor(String field) => fieldColors[field] ?? Colors.grey;
  String getFieldEmoji(String field) => fieldEmojis[field] ?? '💡';
  String getFieldName(String fieldCn, bool isEnglish) {
    return isEnglish ? (fieldNamesEn[fieldCn] ?? fieldCn) : fieldCn;
  }

  // ========== 动画控制 ==========
  void _togglePlay() {
    setState(() {
      isPlaying = !isPlaying;
      if (isPlaying) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    });
  }

  void _startAnimation() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {
        selectedYear += 2;
        if (selectedYear >= 2020) {
          selectedYear = 2020;
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
      selectedYear = events.isNotEmpty
          ? events.map((e) => e['year'] as int).reduce((a, b) => a < b ? a : b).toDouble()
          : -500;
    });
  }

  // ========== 数据筛选 ==========
  List<Map<String, dynamic>> getFilteredEvents() {
    var filtered = events.where((event) => event['year'] <= selectedYear);
    
    // 学习路径筛选
    if (selectedStoryMode != null) {
      var mode = storyModes.firstWhere((m) => m['id'] == selectedStoryMode);
      List<String> modeEventIds = List<String>.from(mode['events']);
      filtered = filtered.where((event) => modeEventIds.contains(event['id']));
    }
    
    // 学科筛选
    if (selectedFields.isNotEmpty) {
      filtered = filtered.where((event) => selectedFields.contains(event['field']));
    }
    
    // 搜索筛选
    if (searchQuery.isNotEmpty) {
      final isEnglish = Localizations.localeOf(context).languageCode == 'en';
      filtered = filtered.where((event) {
        String title = isEnglish && event['title_en'] != null 
            ? event['title_en'] : event['title'];
        String city = isEnglish && event['city_en'] != null 
            ? event['city_en'] : (event['city'] ?? '');
        
        String query = searchQuery.toLowerCase();
        return title.toLowerCase().contains(query) || 
               city.toLowerCase().contains(query);
      });
    }
    
    return filtered.toList();
  }

  List<Map<String, dynamic>> getInfluenceLines() {
    List<Map<String, dynamic>> lines = [];
    var filteredEvents = getFilteredEvents();
    
    for (var event in filteredEvents) {
      var influences = event['influences'] ?? [];
      for (var influenceId in influences) {
        var sourceEvent = events.firstWhere(
          (e) => e['id'] == influenceId,
          orElse: () => {},
        );
        
        if (sourceEvent.isNotEmpty && sourceEvent['year'] <= selectedYear) {
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
    
    return lines;
  }

  // ========== UI构建 ==========
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final l10n = AppLocalizations.of(context);
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';

    return Scaffold(
      appBar: _buildAppBar(l10n, isEnglish),
      body: Stack(
        children: [
          _buildMap(),
          _buildLearningPathSelector(l10n, isEnglish),
          _buildLegend(l10n, isEnglish),
          _buildTimelineController(l10n, isEnglish),
        ],
      ),
    );
  }

  // ========== AppBar ==========
  PreferredSizeWidget _buildAppBar(AppLocalizations l10n, bool isEnglish) {
    return AppBar(
      title: showSearchBar
          ? _buildSearchField(isEnglish)
          : Text(l10n.appTitle),
      actions: [
        IconButton(
          icon: Icon(showSearchBar ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              showSearchBar = !showSearchBar;
              if (!showSearchBar) searchQuery = '';
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.filter_list),
          onPressed: () => _showFilterDialog(isEnglish),
        ),
        _buildLanguageMenu(),
      ],
    );
  }

  Widget _buildSearchField(bool isEnglish) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        autofocus: true,
        style: TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: isEnglish ? 'Search...' : '搜索...',
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.white70, size: 20),
        ),
        onChanged: (value) => setState(() => searchQuery = value),
      ),
    );
  }

  Widget _buildLanguageMenu() {
    return PopupMenuButton<Locale>(
      icon: Icon(Icons.language),
      onSelected: widget.onLanguageChange,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: Locale('zh'),
          child: Row(
            children: [Text('🇨🇳'), SizedBox(width: 8), Text('中文')],
          ),
        ),
        PopupMenuItem(
          value: Locale('en'),
          child: Row(
            children: [Text('🇬🇧'), SizedBox(width: 8), Text('English')],
          ),
        ),
      ],
    );
  }

  // ========== 地图 ==========
  Widget _buildMap() {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(30, 0),
        initialZoom: 2,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.science_map',
        ),
        _buildPolylineLayer(),
        _buildArrowLayer(),
        _buildMarkerLayer(),
      ],
    );
  }

  PolylineLayer _buildPolylineLayer() {
    return PolylineLayer(
      polylines: getInfluenceLines().map((line) {
        return Polyline(
          points: [line['from'], line['to']],
          strokeWidth: 3.0,
          color: Colors.blue.withOpacity(0.7),
          borderStrokeWidth: 1.0,
          borderColor: Colors.white.withOpacity(0.5),
        );
      }).toList(),
    );
  }

  MarkerLayer _buildArrowLayer() {
    return MarkerLayer(
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
              child: Icon(Icons.arrow_drop_down, color: Colors.blue, size: 30),
            ),
          ),
        );
      }).toList(),
    );
  }

 
  // ========== 学习路径选择器 ==========
  Widget _buildLearningPathSelector(AppLocalizations l10n, bool isEnglish) {
    return Positioned(
      top: 20,
      left: 20,
      child: Card(
        elevation: 4,
        child: Container(
          width: 250,
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.learningPath,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: selectedStoryMode,
                hint: Text(l10n.selectTheme),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(l10n.allEvents),
                  ),
                  ...storyModes.map((mode) {
                    String title = isEnglish && mode['title_en'] != null
                        ? mode['title_en']
                        : mode['title'];
                    return DropdownMenuItem<String>(
                      value: mode['id'] as String,
                      child: Row(
                        children: [
                          Text(mode['emoji'], style: TextStyle(fontSize: 20)),
                          SizedBox(width: 8),
                          Expanded(child: Text(title, style: TextStyle(fontSize: 14))),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedStoryMode = value;
                    if (value != null) {
                      var mode = storyModes.firstWhere((m) => m['id'] == value);
                      var firstEventId = mode['events'][0];
                      var firstEvent = events.firstWhere(
                        (e) => e['id'] == firstEventId,
                        orElse: () => {},
                      );
                      if (firstEvent.isNotEmpty) {
                        selectedYear = firstEvent['year'].toDouble();
                      }
                    }
                  });
                },
              ),
              if (selectedStoryMode != null) ...[
                SizedBox(height: 8),
                Text(
                  _getStoryModeDescription(selectedStoryMode!, isEnglish),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _startStoryMode,
                  icon: Icon(Icons.play_arrow),
                  label: Text(l10n.startLearning),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 36),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getStoryModeDescription(String modeId, bool isEnglish) {
    var mode = storyModes.firstWhere((m) => m['id'] == modeId);
    return isEnglish && mode['description_en'] != null
        ? mode['description_en']
        : mode['description'];
  }

  void _startStoryMode() {
    if (selectedStoryMode == null) return;
    
    var mode = storyModes.firstWhere((m) => m['id'] == selectedStoryMode);
    List<String> eventIds = List<String>.from(mode['events']);
    
    _stopAnimation();
    
    var firstEvent = events.firstWhere(
      (e) => e['id'] == eventIds[0],
      orElse: () => {},
    );
    
    if (firstEvent.isNotEmpty) {
      setState(() {
        selectedYear = firstEvent['year'].toDouble();
      });
      Future.delayed(Duration(milliseconds: 500), () {
        _showEventDialog(firstEvent);
      });
    }
  }

  // ========== 图例 ==========
  Widget _buildLegend(AppLocalizations l10n, bool isEnglish) {
    return Positioned(
      top: 20,
      right: 20,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.fieldClassification,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              ...fieldColors.entries.map((entry) {
                String fieldName = getFieldName(entry.key, isEnglish);
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${fieldEmojis[entry.key]} $fieldName',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 时间轴控制器 ==========
  Widget _buildTimelineController(AppLocalizations l10n, bool isEnglish) {
    return Positioned(
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
                '${l10n.year}: ${selectedYear.round()}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 8),
              Slider(
                value: selectedYear,
                min: -500,
                max: 2020,
                divisions: 2520,
                label: selectedYear.round().toString(),
                onChanged: isPlaying ? null : (value) {
                  setState(() => selectedYear = value);
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
                  ),
                  SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: _togglePlay,
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 32),
                    label: Text(
                      isPlaying ? l10n.pauseButton : l10n.playButton,
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: isPlaying ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '${isEnglish ? "Showing" : "显示"} ${getFilteredEvents().length} ${l10n.eventsCount} | ${getInfluenceLines().length} ${l10n.linesCount}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (selectedFields.isNotEmpty || searchQuery.isNotEmpty) ...[
                SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      selectedFields.clear();
                      searchQuery = '';
                      showSearchBar = false;
                    });
                  },
                  icon: Icon(Icons.clear_all, size: 18),
                  label: Text(isEnglish ? 'Clear Filters' : '清除筛选'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red),
                  ),
                ),
              ],
              if (selectedFields.isNotEmpty) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  alignment: WrapAlignment.center,
                  children: selectedFields.map((fieldCn) {
                    return Chip(
                      label: Text(
                        '${fieldEmojis[fieldCn]} ${getFieldName(fieldCn, isEnglish)}',
                        style: TextStyle(fontSize: 11, color: Colors.white),
                      ),
                      backgroundColor: getFieldColor(fieldCn),
                      deleteIcon: Icon(Icons.close, size: 16, color: Colors.white),
                      onDeleted: () {
                        setState(() => selectedFields.remove(fieldCn));
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ========== 筛选对话框 ==========
  void _showFilterDialog(bool isEnglish) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.filter_list, color: Colors.blue),
                SizedBox(width: 8),
                Text(isEnglish ? 'Filter by Field' : '按学科筛选'),
              ],
            ),
            content: Container(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: fieldColors.entries.map((entry) {
                  String fieldName = getFieldName(entry.key, isEnglish);
                  bool isSelected = selectedFields.contains(entry.key);
                  
                  return CheckboxListTile(
                    title: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: entry.value,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('${fieldEmojis[entry.key]} $fieldName'),
                      ],
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedFields.add(entry.key);
                        } else {
                          selectedFields.remove(entry.key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() => selectedFields.clear());
                },
                child: Text(isEnglish ? 'Clear All' : '清除全部'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {});
                },
                child: Text(isEnglish ? 'Apply' : '应用'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ========== 事件详情对话框 ==========
  void _showEventDialog(Map<String, dynamic> event) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    
    // 提取数据
    final data = EventData.fromJson(event, isEnglish, events);
    final color = getFieldColor(event['field'] ?? '综合');
    final emoji = getFieldEmoji(event['field'] ?? '综合');
    
    showDialog(
      context: context,
      builder: (context) => EventDialog(
        data: data,
        color: color,
        emoji: emoji,
        isEnglish: isEnglish,
      ),
    );
  }

  void _showInfluenceDialog(Map<String, dynamic> line) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Knowledge Transfer' : '知识传播'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isEnglish ? 'influenced' : '影响了',
                style: TextStyle(color: Colors.grey),
              ),
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
            child: Text(isEnglish ? 'Close' : '关闭'),
          ),
        ],
      ),
    );
  }

  // 在 _MapScreenState 中添加方法
  Map<String, List<Map<String, dynamic>>> _clusterEvents() {
    Map<String, List<Map<String, dynamic>>> clusters = {};
    
    for (var event in getFilteredEvents()) {
      // 使用经纬度的组合作为key（精确到小数点后2位）
      String key = '${event['lat'].toStringAsFixed(2)}_${event['lng'].toStringAsFixed(2)}';
      
      if (!clusters.containsKey(key)) {
        clusters[key] = [];
      }
      clusters[key]!.add(event);
    }
    
    return clusters;
  }

  // 修改 _buildMarkerLayer
  MarkerLayer _buildMarkerLayer() {
    var clusters = _clusterEvents();
    List<Marker> markers = [];
    
    clusters.forEach((key, events) {
      if (events.isEmpty) return;
      
      // 使用第一个事件的位置
      var firstEvent = events[0];
      String field = firstEvent['field'] ?? '综合';
      Color color = getFieldColor(field);
      
      if (events.length == 1) {
        // 单个事件，正常显示
        markers.add(_buildSingleMarker(events[0]));
      } else {
        // 多个事件，显示聚类标记
        markers.add(_buildClusterMarker(events, color));
      }
    });
    
    return MarkerLayer(markers: markers);
  }

  Marker _buildSingleMarker(Map<String, dynamic> event) {
    String field = event['field'] ?? '综合';
    Color color = getFieldColor(field);
    String emoji = getFieldEmoji(field);
    
    return Marker(
      point: LatLng(event['lat'], event['lng']),
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () => _showEventDialog(event),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(emoji, style: TextStyle(fontSize: 22)),
              ),
            ),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2),
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
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildClusterMarker(List<Map<String, dynamic>> events, Color color) {
    var firstEvent = events[0];
    
    return Marker(
      point: LatLng(firstEvent['lat'], firstEvent['lng']),
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () => _showClusterDialog(events),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${events.length}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2),
              ),
              child: Text(
                firstEvent['city'] ?? '',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示聚类事件列表
  void _showClusterDialog(List<Map<String, dynamic>> events) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '${events[0]['city']} - ${events.length} ${isEnglish ? "events" : "个事件"}',
              ),
            ),
          ],
        ),
        content: Container(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: events.length,
            itemBuilder: (context, index) {
              var event = events[index];
              String title = isEnglish && event['title_en'] != null
                  ? event['title_en']
                  : event['title'];
              String field = event['field'] ?? '综合';
              Color color = getFieldColor(field);
              String emoji = getFieldEmoji(field);
              
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(emoji, style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${event['year']}',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    _showEventDialog(event);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEnglish ? 'Close' : '关闭'),
          ),
        ],
      ),
    );
  }  
}

// ============================================
// 事件数据模型
// ============================================
class EventData {
  final String title;
  final String city;
  final int year;
  final String field;
  
  // 媒体
  final String? heroImage;
  final String? portrait;
  final VideoData? video;
  
  // 内容
  final SummaryData? summary;
  final StoryData? story;
  final List<FunFact>? funFacts;
  final SimpleExplanation? simpleExplanation;
  
  // 科学
  final PrincipleData? principle;
  final List<Application>? applications;
  final ExperimentData? experiment;
  final List<String>? relatedConcepts;
  
  // 影响
  final ImpactData? impact;
  final InfluenceChain? influenceChain;
  
  // 测验
  final QuizData? quiz;

  EventData({
    required this.title,
    required this.city,
    required this.year,
    required this.field,
    this.heroImage,
    this.portrait,
    this.video,
    this.summary,
    this.story,
    this.funFacts,
    this.simpleExplanation,
    this.principle,
    this.applications,
    this.experiment,
    this.relatedConcepts,
    this.impact,
    this.influenceChain,
    this.quiz,
  });

  factory EventData.fromJson(
    Map<String, dynamic> json,
    bool isEnglish,
    List<Map<String, dynamic>> allEvents,
  ) {
    // 基本信息
    String title = isEnglish && json['title_en'] != null
        ? json['title_en']
        : json['title'];
    String city = isEnglish && json['city_en'] != null
        ? json['city_en']
        : (json['city'] ?? '');
    String field = isEnglish && json['field_en'] != null
        ? json['field_en']
        : (json['field'] ?? '综合');
    
    // 媒体
    Map<String, dynamic>? media = json['media'];
    VideoData? video;
    if (media?['video'] != null) {
      var v = media!['video'];
      video = VideoData(
        url: v['url'],
        title: isEnglish && v['title_en'] != null ? v['title_en'] : v['title'],
        duration: v['duration'],
      );
    }
    
    // 摘要
    SummaryData? summary;
    if (json['summary'] != null) {
      var s = json['summary'];
      summary = SummaryData(
        text: isEnglish && s['text_en'] != null ? s['text_en'] : (s['text'] ?? ''),
        keyPoints: isEnglish && s['key_points_en'] != null
            ? List<String>.from(s['key_points_en'])
            : (s['key_points'] != null ? List<String>.from(s['key_points']) : null),
      );
    }
    
    // 故事
    StoryData? story;
    if (json['story'] != null) {
      var st = json['story'];
      if (st is Map) {
        story = StoryData(
          text: isEnglish && st['text_en'] != null ? st['text_en'] : (st['text'] ?? ''),
          image: st['image'],
        );
      } else if (st is String) {
        story = StoryData(text: st, image: null);
      }
    }
    
    // 趣味知识
    List<FunFact>? funFacts;
    if (json['fun_facts'] != null) {
      funFacts = (json['fun_facts'] as List).map((f) {
        return FunFact(
          icon: f['icon'] ?? '💡',
          text: isEnglish && f['text_en'] != null ? f['text_en'] : (f['text'] ?? ''),
        );
      }).toList();
    }
    
    // 简单解释
    SimpleExplanation? simpleExplanation;
    if (json['simple_explanation'] != null) {
      var se = json['simple_explanation'];
      if (se is Map) {
        simpleExplanation = SimpleExplanation(
          text: isEnglish && se['text_en'] != null ? se['text_en'] : (se['text'] ?? ''),
          diagram: se['diagram'],
        );
      } else if (se is String) {
        simpleExplanation = SimpleExplanation(text: se, diagram: null);
      }
    }
    
    // 原理
    PrincipleData? principle;
    if (json['principle'] != null) {
      var p = json['principle'];
      if (p is Map) {
        List<KeyPoint>? keyPoints;
        if (p['key_points'] != null) {
          keyPoints = (p['key_points'] as List).map((kp) {
            return KeyPoint(
              icon: kp['icon'] ?? '•',
              title: isEnglish && kp['title_en'] != null ? kp['title_en'] : (kp['title'] ?? ''),
              text: isEnglish && kp['text_en'] != null ? kp['text_en'] : (kp['text'] ?? ''),
            );
          }).toList();
        }
        
        principle = PrincipleData(
          title: isEnglish && p['title_en'] != null ? p['title_en'] : (p['title'] ?? ''),
          diagram: p['diagram'],
          keyPoints: keyPoints,
          video: p['video'],
        );
      }
    }
    
    // 应用
    List<Application>? applications;
    if (json['applications'] != null) {
      applications = (json['applications'] as List).map((a) {
        return Application(
          icon: a['icon'] ?? '💡',
          title: isEnglish && a['title_en'] != null ? a['title_en'] : (a['title'] ?? ''),
          image: a['image'],
          text: isEnglish && a['text_en'] != null ? a['text_en'] : (a['text'] ?? ''),
        );
      }).toList();
    }
    
    // 实验
    ExperimentData? experiment;
    if (json['experiment'] != null) {
      var e = json['experiment'];
      if (e is Map) {
        experiment = ExperimentData(
          title: isEnglish && e['title_en'] != null ? e['title_en'] : (e['title'] ?? ''),
          video: e['video'],
          image: e['image'],
          materials: isEnglish && e['materials_en'] != null
              ? List<String>.from(e['materials_en'])
              : (e['materials'] != null ? List<String>.from(e['materials']) : null),
          description: isEnglish && e['description_en'] != null ? e['description_en'] : (e['description'] ?? ''),
          why: isEnglish && e['why_en'] != null ? e['why_en'] : (e['why'] ?? ''),
        );
      }
    }
    
    // 相关概念
    List<String>? relatedConcepts;
    if (json['related_concepts'] != null) {
      relatedConcepts = isEnglish && json['related_concepts_en'] != null
          ? List<String>.from(json['related_concepts_en'])
          : List<String>.from(json['related_concepts']);
    }
    
    // 影响
    ImpactData? impact;
    if (json['impact'] != null) {
      var imp = json['impact'];
      if (imp is Map) {
        List<ImpactStat>? stats;
        if (imp['stats'] != null) {
          stats = (imp['stats'] as List).map((s) {
            return ImpactStat(
              number: s['number'],
              label: isEnglish && s['label_en'] != null ? s['label_en'] : s['label'],
            );
          }).toList();
        }
        
        impact = ImpactData(
          text: isEnglish && imp['text_en'] != null ? imp['text_en'] : (imp['text'] ?? ''),
          stats: stats,
        );
      } else if (imp is String) {
        impact = ImpactData(text: imp, stats: null);
      }
    }
    
    // 影响链
    InfluenceChain? influenceChain;
    if (json['influence_chain'] != null) {
      var ic = json['influence_chain'];
      
      List<InfluenceItem>? influencedBy;
      if (ic['influenced_by'] != null) {
        influencedBy = (ic['influenced_by'] as List).map((item) {
          var sourceEvent = allEvents.firstWhere(
            (e) => e['id'] == item['id'],
            orElse: () => {},
          );
          String eventTitle = '';
          if (sourceEvent.isNotEmpty) {
            eventTitle = isEnglish && sourceEvent['title_en'] != null
                ? sourceEvent['title_en']
                : sourceEvent['title'];
          }
          
          return InfluenceItem(
            id: item['id'],
            title: eventTitle,
            contribution: isEnglish && item['contribution_en'] != null
                ? item['contribution_en']
                : item['contribution'],
          );
        }).toList();
      }
      
      List<InfluenceItem>? influenced;
      if (ic['influenced'] != null) {
        influenced = (ic['influenced'] as List).map((item) {
          var targetEvent = allEvents.firstWhere(
            (e) => e['id'] == item['id'],
            orElse: () => {},
          );
          String eventTitle = '';
          if (targetEvent.isNotEmpty) {
            eventTitle = isEnglish && targetEvent['title_en'] != null
                ? targetEvent['title_en']
                : targetEvent['title'];
          }
          
          return InfluenceItem(
            id: item['id'],
            title: eventTitle,
            contribution: isEnglish && item['contribution_en'] != null
                ? item['contribution_en']
                : item['contribution'],
          );
        }).toList();
      }
      
      influenceChain = InfluenceChain(
        influencedBy: influencedBy,
        influenced: influenced,
        legacyText: isEnglish && ic['legacy_text_en'] != null
            ? ic['legacy_text_en']
            : ic['legacy_text'],
      );
    }
    
    // 测验
    QuizData? quiz;
    if (json['quiz'] != null) {
      var q = json['quiz'];
      quiz = QuizData(
        question: isEnglish && q['question_en'] != null ? q['question_en'] : (q['question'] ?? ''),
        image: q['image'],
        options: isEnglish && q['options_en'] != null
            ? List<String>.from(q['options_en'])
            : List<String>.from(q['options']),
        answer: q['answer'],
        explanation: isEnglish && q['explanation_en'] != null ? q['explanation_en'] : (q['explanation'] ?? ''),
      );
    }
    
    return EventData(
      title: title,
      city: city,
      year: json['year'],
      field: field,
      heroImage: media?['hero_image'],
      portrait: media?['portrait'],
      video: video,
      summary: summary,
      story: story,
      funFacts: funFacts,
      simpleExplanation: simpleExplanation,
      principle: principle,
      applications: applications,
      experiment: experiment,
      relatedConcepts: relatedConcepts,
      impact: impact,
      influenceChain: influenceChain,
      quiz: quiz,
    );
  }
}

// ============================================
// 数据模型类
// ============================================
class VideoData {
  final String url;
  final String title;
  final String duration;
  
  VideoData({required this.url, required this.title, required this.duration});
}

class SummaryData {
  final String text;
  final List<String>? keyPoints;
  
  SummaryData({required this.text, this.keyPoints});
}

class StoryData {
  final String text;
  final String? image;
  
  StoryData({required this.text, this.image});
}

class FunFact {
  final String icon;
  final String text;
  
  FunFact({required this.icon, required this.text});
}

class SimpleExplanation {
  final String text;
  final String? diagram;
  
  SimpleExplanation({required this.text, this.diagram});
}

class PrincipleData {
  final String? title;
  final String? diagram;
  final List<KeyPoint>? keyPoints;
  final String? video;
  
  PrincipleData({this.title, this.diagram, this.keyPoints, this.video});
}

class KeyPoint {
  final String icon;
  final String title;
  final String text;
  
  KeyPoint({required this.icon, required this.title, required this.text});
}

class Application {
  final String icon;
  final String title;
  final String? image;
  final String text;
  
  Application({required this.icon, required this.title, this.image, required this.text});
}

class ExperimentData {
  final String? title;
  final String? video;
  final String? image;
  final List<String>? materials;
  final String? description;
  final String? why;
  
  ExperimentData({
    this.title,
    this.video,
    this.image,
    this.materials,
    this.description,
    this.why,
  });
}

class ImpactData {
  final String text;
  final List<ImpactStat>? stats;
  
  ImpactData({required this.text, this.stats});
}

class ImpactStat {
  final String number;
  final String label;
  
  ImpactStat({required this.number, required this.label});
}

class InfluenceChain {
  final List<InfluenceItem>? influencedBy;
  final List<InfluenceItem>? influenced;
  final String? legacyText;
  
  InfluenceChain({this.influencedBy, this.influenced, this.legacyText});
}

class InfluenceItem {
  final String id;
  final String title;
  final String contribution;
  
  InfluenceItem({required this.id, required this.title, required this.contribution});
}

class QuizData {
  final String question;
  final String? image;
  final List<String> options;
  final int answer;
  final String? explanation;
  
  QuizData({
    required this.question,
    this.image,
    required this.options,
    required this.answer,
    this.explanation,
  });
}

// ============================================
// 事件详情对话框
// ============================================
class EventDialog extends StatelessWidget {
  final EventData data;
  final Color color;
  final String emoji;
  final bool isEnglish;

  const EventDialog({
    required this.data,
    required this.color,
    required this.emoji,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Dialog(
        child: Container(
          width: 600,
          height: 700,
          child: Column(
            children: [
              _buildHeader(context),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  children: [
                    OverviewTab(data: data, color: color, isEnglish: isEnglish),
                    ScienceTab(data: data, color: color, isEnglish: isEnglish),
                    ImpactTab(data: data, color: color, isEnglish: isEnglish),
                    QuizTab(data: data, color: color, isEnglish: isEnglish),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 32)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${data.year} · ${data.city}',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: color.withOpacity(0.1),
      child: TabBar(
        labelColor: color,
        unselectedLabelColor: Colors.grey,
        indicatorColor: color,
        tabs: [
          Tab(icon: Icon(Icons.info_outline, size: 20), text: isEnglish ? 'Overview' : '概览'),
          Tab(icon: Icon(Icons.science, size: 20), text: isEnglish ? 'Science' : '科学'),
          Tab(icon: Icon(Icons.account_tree, size: 20), text: isEnglish ? 'Impact' : '影响'),
          Tab(icon: Icon(Icons.quiz, size: 20), text: isEnglish ? 'Quiz' : '测验'),
        ],
      ),
    );
  }
}

// ============================================
// 概览标签页
// ============================================
class OverviewTab extends StatelessWidget {
  final EventData data;
  final Color color;
  final bool isEnglish;

  const OverviewTab({
    required this.data,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 视频或图片
          // 视频
          if (data.video != null) ...[
            VideoPlayer(video: data.video!, color: color, isEnglish: isEnglish),
            SizedBox(height: 16),
          ],

          // 图片（即使有视频也显示）
          if (data.heroImage != null) ...[
            HeroImage(imageUrl: data.heroImage!, color: color),
            SizedBox(height: 16),
          ],

          // 如果都没有，显示渐变色块
          if (data.video == null && data.heroImage == null) ...[
            GradientHeader(field: data.field, color: color, emoji: _getEmoji()),
            SizedBox(height: 16),
          ],
          
          // 摘要
          if (data.summary != null)
            SummaryCard(summary: data.summary!, color: color),
          
          // 故事
          if (data.story != null) ...[
            SizedBox(height: 16),
            StoryCard(story: data.story!, color: color, isEnglish: isEnglish),
          ],
          
          // 趣味知识
          if (data.funFacts != null && data.funFacts!.isNotEmpty) ...[
            SizedBox(height: 16),
            FunFactsSection(funFacts: data.funFacts!, color: color, isEnglish: isEnglish),
          ],
          
          // 简单解释
          if (data.simpleExplanation != null) ...[
            SizedBox(height: 16),
            SimpleExplanationCard(
              explanation: data.simpleExplanation!,
              color: color,
              isEnglish: isEnglish,
            ),
          ],
        ],
      ),
    );
  }

  String _getEmoji() {
    final emojis = {
      'Physics': '⚛️', 'Chemistry': '🧪', 'Biology': '🔬',
      'Mathematics': '📐', 'Astronomy': '🔭', 'Medicine': '💊',
      'Computer Science': '💻', 'Space': '🚀',
      '物理学': '⚛️', '化学': '🧪', '生物学': '🔬',
      '数学': '📐', '天文学': '🔭', '医学': '💊',
      '计算机': '💻', '航天': '🚀',
    };
    return emojis[data.field] ?? '📚';
  }
}

// ============================================
// 科学标签页
// ============================================
class ScienceTab extends StatelessWidget {
  final EventData data;
  final Color color;
  final bool isEnglish;

  const ScienceTab({
    required this.data,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 原理
          if (data.principle != null)
            PrincipleSection(principle: data.principle!, color: color, isEnglish: isEnglish),
          
          // 应用
          if (data.applications != null && data.applications!.isNotEmpty) ...[
            SizedBox(height: 20),
            ApplicationsGrid(applications: data.applications!, color: color, isEnglish: isEnglish),
          ],
          
          // 实验
          if (data.experiment != null) ...[
            SizedBox(height: 20),
            ExperimentCard(experiment: data.experiment!, color: color, isEnglish: isEnglish),
          ],
          
          // 相关概念
          if (data.relatedConcepts != null && data.relatedConcepts!.isNotEmpty) ...[
            SizedBox(height: 16),
            RelatedConceptsChips(concepts: data.relatedConcepts!, color: color),
          ],
          
          // 空状态
          if (data.principle == null && 
              (data.applications == null || data.applications!.isEmpty) &&
              data.experiment == null) ...[
            EmptyState(
              icon: Icons.science_outlined,
              message: isEnglish ? 'Scientific details\ncoming soon...' : '科学详情\n即将添加...',
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================
// 影响标签页
// ============================================
class ImpactTab extends StatelessWidget {
  final EventData data;
  final Color color;
  final bool isEnglish;

  const ImpactTab({
    required this.data,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 影响
          if (data.impact != null)
            ImpactCard(impact: data.impact!, color: color, isEnglish: isEnglish),
          
          // 影响关系网络
          if (data.influenceChain != null) ...[
            SizedBox(height: 20),
            InfluenceNetworkCard(
              influenceChain: data.influenceChain!,
              color: color,
              isEnglish: isEnglish,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================
// 测验标签页
// ============================================
class QuizTab extends StatelessWidget {
  final EventData data;
  final Color color;
  final bool isEnglish;

  const QuizTab({
    required this.data,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: data.quiz != null
          ? QuizWidget(quiz: data.quiz!, color: color)
          : EmptyState(
              icon: Icons.quiz_outlined,
              message: isEnglish ? 'Quiz coming soon...' : '测验即将添加...',
            ),
    );
  }
}

// ============================================
// UI组件 - 概览相关
// ============================================

class VideoPlayer extends StatelessWidget {
  final VideoData video;
  final Color color;
  final bool isEnglish;

  const VideoPlayer({
    required this.video,
    required this.color,
    required this.isEnglish,
  });

  Future<void> _openVideo() async {
    String youtubeUrl = video.url.replaceAll('/embed/', '/watch?v=');
    final Uri uri = Uri.parse(youtubeUrl);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('打开失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openVideo,  // 点击才打开
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.3), Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 大红色播放按钮
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.6),
                            blurRadius: 24,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      isEnglish ? 'Click to Watch on YouTube' : '点击在YouTube观看',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                    SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            video.duration,
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.video_library, color: color, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      video.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.open_in_new, color: color, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeroImage extends StatelessWidget {
  final String imageUrl;
  final Color color;

  const HeroImage({required this.imageUrl, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            color: color.withOpacity(0.1),
            child: Center(child: CircularProgressIndicator(color: color)),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(Icons.image, size: 64, color: Colors.white),
            ),
          );
        },
      ),
    );
  }
}

class GradientHeader extends StatelessWidget {
  final String field;
  final Color color;
  final String emoji;

  const GradientHeader({
    required this.field,
    required this.color,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.4), color.withOpacity(0.7), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 72)),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                field,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final SummaryData summary;
  final Color color;

  const SummaryCard({required this.summary, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.text,
            style: TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
          ),
          if (summary.keyPoints != null && summary.keyPoints!.isNotEmpty) ...[
            SizedBox(height: 12),
            ...summary.keyPoints!.map((point) => Padding(
              padding: EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: color, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text(point, style: TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class StoryCard extends StatelessWidget {
  final StoryData story;
  final Color color;
  final bool isEnglish;

  const StoryCard({
    required this.story,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📚 ${isEnglish ? "Story" : "故事"}',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
        ),
        SizedBox(height: 8),
        if (story.image != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              story.image!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => SizedBox.shrink(),
            ),
          ),
          SizedBox(height: 8),
        ],
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.5)),
          ),
          child: Text(
            story.text,
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
      ],
    );
  }
}

class FunFactsSection extends StatelessWidget {
  final List<FunFact> funFacts;
  final Color color;
  final bool isEnglish;

  const FunFactsSection({
    required this.funFacts,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🎉 ${isEnglish ? "Fun Facts" : "趣味知识"}',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
        ),
        SizedBox(height: 12),
        ...funFacts.map((fact) => Container(
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fact.icon, style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Expanded(
                child: Text(fact.text, style: TextStyle(fontSize: 14, height: 1.4)),
              ),
            ],
          ),
        )),
      ],
    );
  }
}

class SimpleExplanationCard extends StatelessWidget {
  final SimpleExplanation explanation;
  final Color color;
  final bool isEnglish;

  const SimpleExplanationCard({
    required this.explanation,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withOpacity(0.1), Colors.purple.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.child_care, color: Colors.blue[700], size: 22),
              SizedBox(width: 8),
              Text(
                '👶 ${isEnglish ? "Simple Explanation" : "简单解释"}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (explanation.diagram != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                explanation.diagram!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => SizedBox.shrink(),
              ),
            ),
            SizedBox(height: 10),
          ],
          Text(
            explanation.text,
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ============================================
// UI组件 - 科学相关
// ============================================
class PrincipleSection extends StatelessWidget {
  final PrincipleData principle;
  final Color color;
  final bool isEnglish;

  const PrincipleSection({
    required this.principle,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (principle.title != null)
          Text(
            '🔬 ${principle.title}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        SizedBox(height: 12),
        
        // 原理图
        if (principle.diagram != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              principle.diagram!,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => SizedBox.shrink(),
            ),
          ),
          SizedBox(height: 12),
        ],
        
        // 关键要点
        if (principle.keyPoints != null)
          ...principle.keyPoints!.map((point) => Container(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point.icon, style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(point.text, style: TextStyle(fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        
        // 视频
        if (principle.video != null) ...[
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.play_circle_filled, size: 24),
            label: Text(isEnglish ? 'Watch Explanation' : '观看讲解'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ],
    );
  }
}

class ApplicationsGrid extends StatelessWidget {
  final List<Application> applications;
  final Color color;
  final bool isEnglish;

  const ApplicationsGrid({
    required this.applications,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '💡 ${isEnglish ? "Applications" : "实际应用"}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
          children: applications.map((app) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图片或图标
                  if (app.image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Image.network(
                        app.image!,
                        height: 80,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 80,
                            color: color.withOpacity(0.1),
                            child: Center(
                              child: Text(app.icon, style: TextStyle(fontSize: 40)),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Text(app.icon, style: TextStyle(fontSize: 40)),
                      ),
                    ),
                  
                  // 内容
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              app.text,
                              style: TextStyle(fontSize: 12, height: 1.3),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class ExperimentCard extends StatelessWidget {
  final ExperimentData experiment;
  final Color color;
  final bool isEnglish;

  const ExperimentCard({
    required this.experiment,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.withOpacity(0.1), Colors.teal.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, color: Colors.green[700], size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🧪 ${experiment.title ?? (isEnglish ? "Experiment" : "实验")}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // 视频或图片
          if (experiment.video != null)
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text(
                      isEnglish ? 'Watch Experiment' : '观看实验',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            )
          else if (experiment.image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                experiment.image!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => SizedBox.shrink(),
              ),
            ),
          
          if (experiment.video != null || experiment.image != null)
            SizedBox(height: 12),
          
          // 材料
          if (experiment.materials != null && experiment.materials!.isNotEmpty) ...[
            Text(
              isEnglish ? '📦 Materials:' : '📦 材料：',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: experiment.materials!.map((material) {
                return Chip(
                  label: Text(material, style: TextStyle(fontSize: 12)),
                  backgroundColor: Colors.green.withOpacity(0.2),
                  side: BorderSide(color: Colors.green),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                );
              }).toList(),
            ),
            SizedBox(height: 10),
          ],
          
          // 说明
          if (experiment.description != null)
            Text(
              experiment.description!,
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          
          if (experiment.why != null) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.green[700], size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      experiment.why!,
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RelatedConceptsChips extends StatelessWidget {
  final List<String> concepts;
  final Color color;

  const RelatedConceptsChips({required this.concepts, required this.color});

  @override
  Widget build(BuildContext context) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🔑 ${isEnglish ? "Related Concepts" : "相关概念"}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: concepts.map((concept) {
            return Chip(
              label: Text(concept),
              backgroundColor: color.withOpacity(0.1),
              side: BorderSide(color: color),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ============================================
// UI组件 - 影响相关
// ============================================
class ImpactCard extends StatelessWidget {
  final ImpactData impact;
  final Color color;
  final bool isEnglish;

  const ImpactCard({
    required this.impact,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: color, size: 24),
              SizedBox(width: 8),
              Text(
                '💫 ${isEnglish ? "Impact" : "影响"}',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(impact.text, style: TextStyle(fontSize: 14, height: 1.5)),
          
          // 统计数据
          if (impact.stats != null && impact.stats!.isNotEmpty) ...[
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: impact.stats!.map((stat) {
                return Column(
                  children: [
                    Text(
                      stat.number,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      stat.label,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class InfluenceNetworkCard extends StatelessWidget {
  final InfluenceChain influenceChain;
  final Color color;
  final bool isEnglish;

  const InfluenceNetworkCard({
    required this.influenceChain,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree, color: Colors.blue[700], size: 24),
              SizedBox(width: 8),
              Text(
                isEnglish ? 'Knowledge Network' : '知识网络',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          
          // 受以下影响
          if (influenceChain.influencedBy != null && influenceChain.influencedBy!.isNotEmpty) ...[
            SizedBox(height: 14),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_downward, color: Colors.orange[700], size: 20),
                      SizedBox(width: 6),
                      Text(
                        isEnglish ? 'Influenced By' : '受以下影响',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  ...influenceChain.influencedBy!.map((item) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.circle, color: Colors.orange, size: 8),
                        SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 13, color: Colors.black87),
                              children: [
                                TextSpan(
                                  text: item.title,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: '\n'),
                                TextSpan(
                                  text: item.contribution,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
          
          // 影响了以下
          if (influenceChain.influenced != null && influenceChain.influenced!.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_upward, color: Colors.green[700], size: 20),
                      SizedBox(width: 6),
                      Text(
                        isEnglish ? 'Influenced' : '影响了以下',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  ...influenceChain.influenced!.map((item) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.circle, color: Colors.green, size: 8),
                        SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 13, color: Colors.black87),
                              children: [
                                TextSpan(
                                  text: item.title,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: '\n'),
                                TextSpan(
                                  text: item.contribution,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
          
          // 传承故事
          if (influenceChain.legacyText != null && influenceChain.legacyText!.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_stories, color: Colors.amber[800], size: 20),
                      SizedBox(width: 6),
                      Text(
                        '📖 ${isEnglish ? "Legacy" : "传承"}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[900],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    influenceChain.legacyText!,
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================
// 测验组件
// ============================================
class QuizWidget extends StatefulWidget {
  final QuizData quiz;
  final Color color;

  const QuizWidget({required this.quiz, required this.color});

  @override
  State<QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget> {
  int? selectedAnswer;
  bool? isCorrect;

  @override
  Widget build(BuildContext context) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '❓ ${isEnglish ? "Quiz" : "小测验"}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.color,
          ),
        ),
        SizedBox(height: 8),
        
        // 题目图片
        if (widget.quiz.image != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              widget.quiz.image!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => SizedBox.shrink(),
            ),
          ),
          SizedBox(height: 12),
        ],
        
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.quiz.question,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              
              // 选项
              ...widget.quiz.options.asMap().entries.map((entry) {
                int idx = entry.key;
                String option = entry.value;
                bool isSelected = selectedAnswer == idx;
                bool isAnswered = selectedAnswer != null;
                bool isThisCorrect = idx == widget.quiz.answer;
                
                Color? buttonColor;
                if (isAnswered) {
                  if (isThisCorrect) {
                    buttonColor = Colors.green;
                  } else if (isSelected) {
                    buttonColor = Colors.red;
                  }
                }
                
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: ElevatedButton(
                    onPressed: isAnswered ? null : () {
                      setState(() {
                        selectedAnswer = idx;
                        isCorrect = idx == widget.quiz.answer;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor ?? Colors.grey[200],
                      foregroundColor: buttonColor != null ? Colors.white : Colors.black,
                      minimumSize: Size(double.infinity, 40),
                      disabledBackgroundColor: buttonColor,
                      disabledForegroundColor: buttonColor != null ? Colors.white : Colors.black,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${String.fromCharCode(65 + idx)}. $option',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        if (isAnswered && isThisCorrect)
                          Icon(Icons.check_circle, size: 20),
                      ],
                    ),
                  ),
                );
              }),
              
              // 反馈
              if (isCorrect != null) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCorrect!
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect! ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCorrect! ? Icons.celebration : Icons.refresh,
                        color: isCorrect! ? Colors.green[700] : Colors.red[700],
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCorrect!
                                  ? (isEnglish ? 'Great! Correct! 🎉' : '太棒了！答对了！🎉')
                                  : (isEnglish ? 'Try again!' : '再想想！'),
                              style: TextStyle(
                                color: isCorrect! ? Colors.green[800] : Colors.red[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (isCorrect! && widget.quiz.explanation != null) ...[
                              SizedBox(height: 6),
                              Text(
                                widget.quiz.explanation!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================
// 通用UI组件
// ============================================
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}