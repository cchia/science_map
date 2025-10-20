import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';  // 添加
import 'l10n/app_localizations.dart';  // 添加

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = Locale('zh');  // 默认中文

  void _changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Science History Map',
      theme: ThemeData(primarySwatch: Colors.blue),
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

class MapScreen extends StatefulWidget {
  final Function(Locale) onLanguageChange;
  
  const MapScreen({required this.onLanguageChange});
  
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  double selectedYear = 1500;
  bool isPlaying = false;
  Timer? _timer;
  
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> storyModes = [];

  bool isLoading = true;
  String? selectedStoryMode;


  // 🆕 添加搜索和筛选状态
  String searchQuery = '';
  Set<String> selectedFields = {};  // 选中的学科
  bool showSearchBar = false;

  // 学科颜色映射
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

// 学科emoji映射
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

// 🆕 添加学科英文名称映射
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

// 🆕 添加获取学科名称的方法
String getFieldName(String fieldCn, bool isEnglish) {
  if (isEnglish) {
    return fieldNamesEn[fieldCn] ?? fieldCn;
  }
  return fieldCn;
}

  @override
  void initState() {
    super.initState();
    loadData();  // 改名
  }

  // 修改加载方法
  Future<void> loadData() async {
    try {
      // 加载事件数据
      final String eventsResponse = await rootBundle.loadString('assets/events.json');
      final List<dynamic> eventsData = json.decode(eventsResponse);
      
      // 加载学习路径数据
      final String modesResponse = await rootBundle.loadString('assets/story_modes.json');
      final List<dynamic> modesData = json.decode(modesResponse);
      
      setState(() {
        events = eventsData.cast<Map<String, dynamic>>();
        storyModes = modesData.cast<Map<String, dynamic>>();
        isLoading = false;
      });
    } catch (e) {
      print('加载数据失败: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color getFieldColor(String field) {
    return fieldColors[field] ?? Colors.grey;
  }

  String getFieldEmoji(String field) {
    return fieldEmojis[field] ?? '💡';
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
      selectedYear = -500;
    });
  }

List<Map<String, dynamic>> getFilteredEvents() {
  var filtered = events.where((event) => event['year'] <= selectedYear);
  
  // 故事模式筛选
  if (selectedStoryMode != null) {
    var mode = storyModes.firstWhere((m) => m['id'] == selectedStoryMode);
    List<String> modeEventIds = List<String>.from(mode['events']);
    filtered = filtered.where((event) => modeEventIds.contains(event['id']));
  }
  
  // 🆕 学科筛选
  if (selectedFields.isNotEmpty) {
    filtered = filtered.where((event) => 
      selectedFields.contains(event['field'])
    );
  }
  
  // 🆕 搜索筛选
  if (searchQuery.isNotEmpty) {
    final locale = Localizations.localeOf(context);
    final isEnglish = locale.languageCode == 'en';
    
    filtered = filtered.where((event) {
      String title = isEnglish && event['title_en'] != null 
          ? event['title_en'] 
          : event['title'];
      String city = isEnglish && event['city_en'] != null 
          ? event['city_en'] 
          : event['city'] ?? '';
      String description = isEnglish && event['description_en'] != null 
          ? event['description_en'] 
          : event['description'] ?? '';
      
      String query = searchQuery.toLowerCase();
      return title.toLowerCase().contains(query) ||
             city.toLowerCase().contains(query) ||
             description.toLowerCase().contains(query);
    });
  }
  
  return filtered.toList();
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

  void _startStoryMode() {
    if (selectedStoryMode == null) return;
    
    var mode = storyModes.firstWhere((m) => m['id'] == selectedStoryMode);
    List<String> eventIds = List<String>.from(mode['events']);
    int currentIndex = 0;
    
    _stopAnimation();
    
    var firstEvent = events.firstWhere(
      (e) => e['id'] == eventIds[0],
      orElse: () => {},
    );
    
    if (firstEvent.isEmpty) return;
    
    setState(() {
      selectedYear = firstEvent['year'].toDouble();
    });
    
    Future.delayed(Duration(milliseconds: 500), () {
      _showEventDialog(firstEvent);
    });
  }

  void _showCompletionDialog(String modeTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text('🎉'),
            SizedBox(width: 8),
            Text('完成学习！'),
          ],
        ),
        content: Text('恭喜你完成了《$modeTitle》的学习！\n\n你已经了解了这个领域的重要发展历程。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                selectedStoryMode = null;
              });
            },
            child: Text('太棒了！'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context);  // 获取翻译
  
  if (isLoading) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(child: CircularProgressIndicator()),
    );
  }

  return Scaffold(
appBar: AppBar(
  title: Builder(
    builder: (context) {
      final locale = Localizations.localeOf(context);
      final isEnglish = locale.languageCode == 'en';
      
return showSearchBar
    ? Container(
        padding: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),  // 半透明白色背景
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          autofocus: true,
          style: TextStyle(color: Colors.black, fontSize: 16),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: isEnglish ? 'Search events...' : '搜索事件...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            icon: Icon(Icons.search, color: Colors.white70, size: 20),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        ),
      )
    : Text(l10n.appTitle);
    },
  ),
  actions: [
    // 搜索按钮
    IconButton(
      icon: Icon(showSearchBar ? Icons.close : Icons.search),
      onPressed: () {
        setState(() {
          showSearchBar = !showSearchBar;
          if (!showSearchBar) {
            searchQuery = '';
          }
        });
      },
    ),
    // 筛选按钮
    IconButton(
      icon: Icon(Icons.filter_list),
      onPressed: () => _showFilterDialog(),
    ),
    // 语言切换按钮
    PopupMenuButton<Locale>(
      icon: Icon(Icons.language),
      onSelected: widget.onLanguageChange,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: Locale('zh'),
          child: Row(
            children: [
              Text('🇨🇳'),
              SizedBox(width: 8),
              Text('中文'),
            ],
          ),
        ),
        PopupMenuItem(
          value: Locale('en'),
          child: Row(
            children: [
              Text('🇬🇧'),
              SizedBox(width: 8),
              Text('English'),
            ],
          ),
        ),
      ],
    ),
  ],
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
                              child: Text(
                                emoji,
                                style: TextStyle(fontSize: 22),
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
                }).toList(),
              ),
            ],
          ),
          
// 学习路径选择器
Positioned(
  top: 20,
  left: 20,
  child: Card(
    elevation: 4,
    child: Container(
      width: 250,
      padding: EdgeInsets.all(12),
      child: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final locale = Localizations.localeOf(context);
          final isEnglish = locale.languageCode == 'en';
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.learningPath,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
                    String modeTitle = isEnglish && mode['title_en'] != null
                        ? mode['title_en']
                        : mode['title'];
                    
                    return DropdownMenuItem<String>(
                      value: mode['id'] as String,
                      child: Row(
                        children: [
                          Text(mode['emoji'], style: TextStyle(fontSize: 20)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              modeTitle,  // 🆕 使用翻译后的标题
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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
                Builder(
                  builder: (context) {
                    var mode = storyModes.firstWhere((m) => m['id'] == selectedStoryMode);
                    String modeDescription = isEnglish && mode['description_en'] != null
                        ? mode['description_en']
                        : mode['description'];
                    
                    return Text(
                      modeDescription,  // 🆕 使用翻译后的描述
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    );
                  },
                ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _startStoryMode(),
                  icon: Icon(Icons.play_arrow),
                  label: Text(l10n.startLearning),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 36),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  ),
),
        
// 图例
Positioned(
  top: 20,
  right: 20,
  child: Card(
    elevation: 4,
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final locale = Localizations.localeOf(context);
          final isEnglish = locale.languageCode == 'en';
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.fieldClassification,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              ...fieldColors.entries.map((entry) {
                String fieldName = getFieldName(entry.key, isEnglish);  // 🆕 使用翻译
                
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
                        '${fieldEmojis[entry.key]} $fieldName',  // 🆕 使用 fieldName
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    ),
  ),
),
        
 // 时间轴控制器
Positioned(
  bottom: 20,
  left: 20,
  right: 20,
  child: Card(
    elevation: 8,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final locale = Localizations.localeOf(context);
          final isEnglish = locale.languageCode == 'en';
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 年份显示
              Text(
                '${l10n.year}: ${selectedYear.round()}',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 8),
              
              // 滑块
              Slider(
                value: selectedYear,
                min: -500,
                max: 2020,
                divisions: 2520,
                label: selectedYear.round().toString(),
                onChanged: isPlaying ? null : (value) {
                  setState(() {
                    selectedYear = value;
                  });
                },
              ),
              
              SizedBox(height: 8),
              
              // 控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 重置按钮
                  IconButton(
                    icon: Icon(Icons.replay),
                    iconSize: 32,
                    color: Colors.blue[700],
                    onPressed: _resetAnimation,
                    tooltip: l10n.resetButton,
                  ),
                  
                  SizedBox(width: 20),
                  
                  // 播放/暂停按钮
                  ElevatedButton.icon(
                    onPressed: _togglePlay,
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32,
                    ),
                    label: Text(
                      isPlaying ? l10n.pauseButton : l10n.playButton,
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
              
              // 统计信息
              Text(
                '${isEnglish ? "Showing" : "显示"} ${getFilteredEvents().length} ${l10n.eventsCount} | ${getInfluenceLines().length} ${l10n.linesCount}' +
                (selectedFields.isNotEmpty ? ' | ${isEnglish ? "Filtered" : "已筛选"}' : '') +
                (searchQuery.isNotEmpty ? ' | ${isEnglish ? "Searching" : "搜索中"}' : ''),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
              
              // 🆕 清除筛选按钮
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
                  label: Text(
                    isEnglish ? 'Clear Filters' : '清除筛选',
                    style: TextStyle(fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
              
              // 🆕 显示当前筛选条件
              if (selectedFields.isNotEmpty) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: selectedFields.map((fieldCn) {
                    String fieldName = getFieldName(fieldCn, isEnglish);
                    Color fieldColor = getFieldColor(fieldCn);
                    
                    return Chip(
                      label: Text(
                        '${fieldEmojis[fieldCn]} $fieldName',
                        style: TextStyle(fontSize: 11, color: Colors.white),
                      ),
                      backgroundColor: fieldColor,
                      deleteIcon: Icon(Icons.close, size: 16, color: Colors.white),
                      onDeleted: () {
                        setState(() {
                          selectedFields.remove(fieldCn);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    ),
  ),
),
      ],
    ),
  );
}

void _showFilterDialog() {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context);
  final isEnglish = locale.languageCode == 'en';
  
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
              children: [
                ...fieldColors.entries.map((entry) {
                  String fieldCn = entry.key;
                  String fieldName = getFieldName(fieldCn, isEnglish);
                  bool isSelected = selectedFields.contains(fieldCn);
                  
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
                        Text('${fieldEmojis[fieldCn]} $fieldName'),
                      ],
                    ),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedFields.add(fieldCn);
                        } else {
                          selectedFields.remove(fieldCn);
                        }
                      });
                    },
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  selectedFields.clear();
                });
              },
              child: Text(isEnglish ? 'Clear All' : '清除全部'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {});  // 刷新主界面
              },
              child: Text(isEnglish ? 'Apply' : '应用'),
            ),
          ],
        );
      },
    ),
  );
}

  void _showEventDialog(Map<String, dynamic> event) {

  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context);  // 改用这个
  final isEnglish = l10n.locale.languageCode == 'en';
  
  // 根据语言选择字段
  String title = isEnglish && event['title_en'] != null 
      ? event['title_en'] 
      : event['title'];
  String city = isEnglish && event['city_en'] != null 
      ? event['city_en'] 
      : event['city'];
  String field = isEnglish && event['field_en'] != null 
      ? event['field_en'] 
      : (event['field'] ?? '综合');
  String? description = isEnglish && event['description_en'] != null 
      ? event['description_en'] 
      : event['description'];
  String? story = isEnglish && event['story_en'] != null 
      ? event['story_en'] 
      : event['story'];
  String? funFact = isEnglish && event['fun_fact_en'] != null 
      ? event['fun_fact_en'] 
      : event['fun_fact'];
  String? kidExplanation = isEnglish && event['kid_friendly_explanation_en'] != null 
      ? event['kid_friendly_explanation_en'] 
      : event['kid_friendly_explanation'];
  String? impact = isEnglish && event['impact_en'] != null 
      ? event['impact_en'] 
      : event['impact'];
  String? influenceStory = isEnglish && event['influence_story_en'] != null 
      ? event['influence_story_en'] 
      : event['influence_story'];
  String? principle = isEnglish && event['principle_en'] != null 
      ? event['principle_en'] 
      : event['principle'];
  String? applications = isEnglish && event['applications_en'] != null 
      ? event['applications_en'] 
      : event['applications'];
  String? experiment = isEnglish && event['experiment_en'] != null 
      ? event['experiment_en'] 
      : event['experiment'];
      
  var influences = event['influences'] ?? [];
  var influenceNames = <String>[];
  
  // 🔧 修改这里：找出影响了这个事件的其他事件（使用对应语言）
  for (var id in influences) {
    var e = events.firstWhere((ev) => ev['id'] == id, orElse: () => {});
    if (e.isNotEmpty) {
      String eventTitle = isEnglish && e['title_en'] != null 
          ? e['title_en'] 
          : e['title'];
      influenceNames.add(eventTitle);
    }
  }
  
  // 🔧 修改这里：找出这个事件影响了哪些事件（使用对应语言）
  var influencedEvents = <String>[];
  for (var e in events) {
    var eInfluences = e['influences'] ?? [];
    if (eInfluences.contains(event['id'])) {
      String eventTitle = isEnglish && e['title_en'] != null 
          ? e['title_en'] 
          : e['title'];
      influencedEvents.add(eventTitle);
    }
  }
  
  Color color = getFieldColor(event['field'] ?? '综合');
  String emoji = getFieldEmoji(event['field'] ?? '综合');
  
   showDialog(
    context: context,
    builder: (context) => DefaultTabController(
      length: 4,  // 4个标签页
      child: Dialog(
        child: Container(
          width: 600,
          height: 700,
          child: Column(
            children: [
              // 标题栏（保持不变）
              Container(
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
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${event['year']} · $city',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
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
              ),
              
              // 🆕 标签栏
              Container(
                color: color.withOpacity(0.1),
                child: TabBar(
                  labelColor: color,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: color,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.info_outline),
                      text: isEnglish ? 'Overview' : '概览',
                    ),
                    Tab(
                      icon: Icon(Icons.science),
                      text: isEnglish ? 'Science' : '科学',
                    ),
                    Tab(
                      icon: Icon(Icons.account_tree),
                      text: isEnglish ? 'Impact' : '影响',
                    ),
                    Tab(
                      icon: Icon(Icons.quiz),
                      text: isEnglish ? 'Quiz' : '测验',
                    ),
                  ],
                ),
              ),
              
              // 🆕 标签页内容
              Expanded(
                child: TabBarView(
                  children: [
                    // 第1页：概览（故事、趣味知识）
                    _buildOverviewTab(
                      event, 
                      color, 
                      isEnglish,
                      field,
                      description,
                      story,
                      funFact,
                      kidExplanation,
                    ),
                    
                    // 第2页：科学知识（原理、应用、实验）
                    _buildScienceTab(
                      event,
                      color,
                      isEnglish,
                      principle,
                      applications,
                      experiment,
                    ),
                    
                    // 第3页：影响关系
                    _buildImpactTab(
                      event,
                      color,
                      isEnglish,
                      impact,
                      influenceStory,
                      influenceNames,
                      influencedEvents,
                    ),
                    
                    // 第4页：小测验
                    _buildQuizTab(
                      event,
                      color,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildSection(String title, String content, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: 16),
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      SizedBox(height: 8),
      Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          content,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    ],
  );
}

// 第1页：概览
Widget _buildOverviewTab(
  Map<String, dynamic> event,
  Color color,
  bool isEnglish,
  String field,
  String? description,
  String? story,
  String? funFact,
  String? kidExplanation,
) {
  return SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
// 找到图片显示部分，修改 fit 属性
if (event['image_url'] != null) ...[
  ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(
      event['image_url'],
      height: 200,
      width: double.infinity,
      fit: BoxFit.contain,  // 改成 contain（完整显示）而不是 cover（裁剪）
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: CircularProgressIndicator(color: color),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // 加载失败时显示渐变色块
        return Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.4),
                color.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  getFieldEmoji(event['field'] ?? '综合'),
                  style: TextStyle(fontSize: 64),
                ),
                SizedBox(height: 8),
                Text(
                  field,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ),
  SizedBox(height: 16),
] else ...[
  // 如果没有图片URL，显示渐变色块
  Container(
    height: 200,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.6),
          color,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            getFieldEmoji(event['field'] ?? '综合'),
            style: TextStyle(fontSize: 72),
          ),
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
  SizedBox(height: 16),
],
        
        // 学科标签
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            field,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // 简介
        if (description != null && description.isNotEmpty) ...[
          _buildSection('📖 ${isEnglish ? "Introduction" : "简介"}', description, color),
        ],
        
        // 故事
        if (story != null && story.isNotEmpty) ...[
          _buildSection('📚 ${isEnglish ? "Story" : "故事"}', story, color),
        ],
        
        // 趣味知识
        if (funFact != null && funFact.isNotEmpty) ...[
          _buildSection('🎉 ${isEnglish ? "Fun Fact" : "趣味知识"}', funFact, color),
        ],
        
        // 简单解释
        if (kidExplanation != null && kidExplanation.isNotEmpty) ...[
          _buildSection('👶 ${isEnglish ? "Simple Explanation" : "简单解释"}', kidExplanation, color),
        ],
      ],
    ),
  );
}

// 第2页：科学知识
Widget _buildScienceTab(
  Map<String, dynamic> event,
  Color color,
  bool isEnglish,
  String? principle,
  String? applications,
  String? experiment,
) {
  return SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 科学原理
        if (principle != null && principle.isNotEmpty) ...[
          _buildSection('🔬 ${isEnglish ? "Scientific Principle" : "科学原理"}', principle, color),
        ],
        
        // 实际应用
        if (applications != null && applications.isNotEmpty) ...[
          _buildSection('💡 ${isEnglish ? "Real-world Applications" : "实际应用"}', applications, color),
        ],
        
        // 动手实验
        if (experiment != null && experiment.isNotEmpty) ...[
          _buildSection('🧪 ${isEnglish ? "Try This Experiment" : "动手实验"}', experiment, color),
        ],
        
        // 相关概念
        if (event['related_concepts'] != null) ...[
          SizedBox(height: 16),
          Text(
            '🔑 ${isEnglish ? "Related Concepts" : "相关概念"}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Builder(
            builder: (context) {
              List conceptsCn = event['related_concepts'] as List;
              List? conceptsEn = event['related_concepts_en'] as List?;
              
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(conceptsCn.length, (index) {
                  String conceptText;
                  if (isEnglish && conceptsEn != null && index < conceptsEn.length) {
                    conceptText = conceptsEn[index];
                  } else {
                    conceptText = conceptsCn[index];
                  }
                  
                  return Chip(
                    label: Text(conceptText),
                    backgroundColor: color.withOpacity(0.1),
                    side: BorderSide(color: color),
                  );
                }),
              );
            },
          ),
        ],
        
        // 如果没有科学内容，显示提示
        if ((principle == null || principle.isEmpty) &&
            (applications == null || applications.isEmpty) &&
            (experiment == null || experiment.isEmpty)) ...[
          Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.science_outlined, size: 64, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  Text(
                    isEnglish 
                        ? 'Scientific details coming soon...' 
                        : '科学详情即将添加...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

// 第3页：影响关系
Widget _buildImpactTab(
  Map<String, dynamic> event,
  Color color,
  bool isEnglish,
  String? impact,
  String? influenceStory,
  List<String> influenceNames,
  List<String> influencedEvents,
) {
  return SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 影响
        if (impact != null && impact.isNotEmpty) ...[
          _buildSection('💫 ${isEnglish ? "Impact" : "影响"}', impact, color),
        ],
        
        // 知识传承故事
        if (influenceStory != null && influenceStory.isNotEmpty) ...[
          _buildSection('🔗 ${isEnglish ? "Knowledge Legacy" : "知识传承故事"}', influenceStory, color),
        ],
        
        // 影响关系
        if (influenceNames.isNotEmpty || influencedEvents.isNotEmpty) ...[
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
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
                      isEnglish ? 'Knowledge Transfer' : '知识传承',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
                
                // 受以下影响
                if (influenceNames.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ...influenceNames.map((name) => Padding(
                          padding: EdgeInsets.only(left: 26, top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: Colors.orange, size: 8),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(name, style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
                
                // 影响了以下
                if (influencedEvents.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[900],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ...influencedEvents.map((name) => Padding(
                          padding: EdgeInsets.only(left: 26, top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: Colors.green, size: 8),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(name, style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

// 第4页：测验
Widget _buildQuizTab(
  Map<String, dynamic> event,
  Color color,
) {
  return SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        if (event['quiz'] != null) ...[
          _buildQuiz(event['quiz'], color),
        ] else ...[
          Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  Text(
                    'Quiz coming soon...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildQuiz(Map<String, dynamic> quiz, Color color) {
    return _QuizWidget(quiz: quiz, color: color);
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

// Quiz widget classes moved outside of _MapScreenState
class _QuizWidget extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final Color color;

  const _QuizWidget({
    required this.quiz,
    required this.color,
  });

  @override
  State<_QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<_QuizWidget> {
  int? selectedAnswer;
  bool? isCorrect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEnglish = l10n.locale.languageCode == 'en';
    
    // 根据语言选择问题和选项
    String question = isEnglish && widget.quiz['question_en'] != null
        ? widget.quiz['question_en']
        : widget.quiz['question'];
    
    List options = isEnglish && widget.quiz['options_en'] != null
        ? widget.quiz['options_en']
        : widget.quiz['options'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '❓ ${l10n.quiz}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.color,
          ),
        ),
        SizedBox(height: 8),
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
                question,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              ...options.asMap().entries.map((entry) {
                int idx = entry.key;
                String option = entry.value;
                bool isSelected = selectedAnswer == idx;
                bool isAnswered = selectedAnswer != null;
                bool isThisCorrect = idx == widget.quiz['answer'];
                
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
                        isCorrect = idx == widget.quiz['answer'];
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
              }).toList(),
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
                        child: Text(
                          isCorrect! ? l10n.correct : l10n.tryAgain,
                          style: TextStyle(
                            color: isCorrect! ? Colors.green[800] : Colors.red[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
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