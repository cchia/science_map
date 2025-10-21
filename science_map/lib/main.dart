import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
  
  // 搜索和筛选状态
  String searchQuery = '';
  Set<String> selectedFields = {};
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

  // 学科英文名称映射
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

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      // 🆕 加载事件索引
      final String indexResponse = await rootBundle.loadString('assets/events_index.json');
      final List<dynamic> eventIds = json.decode(indexResponse);
      
      // 🆕 逐个加载事件文件
      List<Map<String, dynamic>> loadedEvents = [];
      for (var eventId in eventIds) {
        try {
          final String eventResponse = await rootBundle.loadString('assets/events/$eventId.json');
          
          // 尝试解析 JSON，如果失败则跳过该文件
          try {
            final Map<String, dynamic> eventData = json.decode(eventResponse);
            loadedEvents.add(eventData);
            print('✅ 已加载: $eventId');
          } catch (jsonError) {
            print('❌ JSON 解析失败: $eventId - $jsonError');
            // 继续处理下一个文件，不中断整个加载过程
            continue;
          }
        } catch (e) {
          print('❌ 文件加载失败: $eventId - $e');
          // 继续处理下一个文件
          continue;
        }
      }
      
      // 加载学习路径数据
      final String modesResponse = await rootBundle.loadString('assets/story_modes.json');
      final List<dynamic> modesData = json.decode(modesResponse);
      
      setState(() {
        events = loadedEvents;
        storyModes = modesData.cast<Map<String, dynamic>>();
        isLoading = false;
      });
      
      print('🎉 总共加载了 ${events.length} 个事件');
      
    } catch (e) {
      print('❌ 加载数据失败: $e');
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

  String getFieldName(String fieldCn, bool isEnglish) {
    if (isEnglish) {
      return fieldNamesEn[fieldCn] ?? fieldCn;
    }
    return fieldCn;
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
      if (events.isNotEmpty) {
        selectedYear = events.map((e) => e['year'] as int).reduce((a, b) => a < b ? a : b).toDouble();
      } else {
        selectedYear = -500;
      }
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
    
    // 学科筛选
    if (selectedFields.isNotEmpty) {
      filtered = filtered.where((event) => 
        selectedFields.contains(event['field'])
      );
    }
    
    // 搜索筛选
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
    final locale = Localizations.localeOf(context);
    final isEnglish = locale.languageCode == 'en';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text('🎉'),
            SizedBox(width: 8),
            Text(isEnglish ? 'Completed!' : '完成学习！'),
          ],
        ),
        content: Text(
          isEnglish 
              ? 'Congratulations on completing "$modeTitle"!\n\nYou have learned about the important developments in this field.'
              : '恭喜你完成了《$modeTitle》的学习！\n\n你已经了解了这个领域的重要发展历程。'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                selectedStoryMode = null;
              });
            },
            child: Text(isEnglish ? 'Awesome!' : '太棒了！'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
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

    @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final isEnglish = locale.languageCode == 'en';
    
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.appTitle)),
        body: Center(
          child: CircularProgressIndicator(),
        ),
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
                      color: Colors.white.withOpacity(0.2),
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
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
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
                                        modeTitle,
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
                                modeDescription,
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
                              tooltip: l10n.resetButton,
                            ),
                            
                            SizedBox(width: 20),
                            
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
                        
                        Text(
                          '${isEnglish ? "Showing" : "显示"} ${getFilteredEvents().length} ${l10n.eventsCount} | ${getInfluenceLines().length} ${l10n.linesCount}' +
                          (selectedFields.isNotEmpty ? ' | ${isEnglish ? "Filtered" : "已筛选"}' : '') +
                          (searchQuery.isNotEmpty ? ' | ${isEnglish ? "Searching" : "搜索中"}' : ''),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          textAlign: TextAlign.center,
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

    void _showEventDialog(Map<String, dynamic> event) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final isEnglish = locale.languageCode == 'en';
    
    // 基本字段
    String title = isEnglish && event['title_en'] != null 
        ? event['title_en'] 
        : event['title'];
    String city = isEnglish && event['city_en'] != null 
        ? event['city_en'] 
        : event['city'] ?? '';
    String field = isEnglish && event['field_en'] != null 
        ? event['field_en'] 
        : (event['field'] ?? '综合');
    String? description = isEnglish && event['description_en'] != null 
        ? event['description_en'] 
        : event['description'];
    
    // 🆕 处理嵌套的story对象
    String? storyBrief;
    String? storyDetailed;
    String? historicalContext;
    List? timeline;
    
    if (event['story'] != null) {
      if (event['story'] is String) {
        storyBrief = event['story'];
      } else if (event['story'] is Map) {
        var storyObj = isEnglish && event['story_en'] != null 
            ? event['story_en'] 
            : event['story'];
        storyBrief = storyObj['brief'];
        storyDetailed = storyObj['detailed'];
        historicalContext = storyObj['historical_context'];
        timeline = storyObj['timeline'];
      }
    }
    
    // 🆕 处理嵌套的fun_fact对象
    String? funFactBrief;
    List? funFactExtended;
    
    if (event['fun_fact'] != null) {
      if (event['fun_fact'] is String) {
        funFactBrief = event['fun_fact'];
      } else if (event['fun_fact'] is Map) {
        var funFactObj = isEnglish && event['fun_fact_en'] != null 
            ? event['fun_fact_en'] 
            : event['fun_fact'];
        funFactBrief = funFactObj['brief'];
        funFactExtended = funFactObj['extended'];
      }
    }
    
    // 🆕 处理嵌套的impact对象
    String? impactBrief;
    String? impactDetailed;
    List? modernExamples;
    
    if (event['impact'] != null) {
      if (event['impact'] is String) {
        impactBrief = event['impact'];
      } else if (event['impact'] is Map) {
        var impactObj = isEnglish && event['impact_en'] != null 
            ? event['impact_en'] 
            : event['impact'];
        impactBrief = impactObj['brief'];
        impactDetailed = impactObj['detailed'];
        modernExamples = impactObj['modern_examples'];
      }
    }
    
    // 🆕 处理嵌套的kid_friendly_explanation对象
    String? kidExplanationSimple;
    String? kidExplanationDetailed;
    String? interactiveChallenge;
    
    if (event['kid_friendly_explanation'] != null) {
      if (event['kid_friendly_explanation'] is String) {
        kidExplanationSimple = event['kid_friendly_explanation'];
      } else if (event['kid_friendly_explanation'] is Map) {
        var kidObj = isEnglish && event['kid_friendly_explanation_en'] != null 
            ? event['kid_friendly_explanation_en'] 
            : event['kid_friendly_explanation'];
        kidExplanationSimple = kidObj['simple'];
        kidExplanationDetailed = kidObj['detailed'];
        interactiveChallenge = kidObj['interactive_challenge'];
      }
    }
    
    // 其他字段
    String? principle = isEnglish && event['principle_en'] != null 
        ? event['principle_en'] 
        : event['principle'];
    String? applications = isEnglish && event['applications_en'] != null 
        ? event['applications_en'] 
        : event['applications'];
    String? experiment = isEnglish && event['experiment_en'] != null 
        ? event['experiment_en'] 
        : event['experiment'];
    String? influenceStory = isEnglish && event['influence_story_en'] != null 
        ? event['influence_story_en'] 
        : event['influence_story'];
    
    // 影响关系
    var influences = event['influences'] ?? [];
    var influenceNames = <String>[];
    
    for (var id in influences) {
      var e = events.firstWhere((ev) => ev['id'] == id, orElse: () => {});
      if (e.isNotEmpty) {
        String eventTitle = isEnglish && e['title_en'] != null 
            ? e['title_en'] 
            : e['title'];
        influenceNames.add(eventTitle);
      }
    }
    
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
         length: 5,
        child: Dialog(
          child: Container(
            width: 600,
            height: 700,
            child: Column(
              children: [
                // 标题栏
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
                
                 // 标签栏
                 Container(
                   color: color.withOpacity(0.1),
                   child: TabBar(
                     labelColor: color,
                     unselectedLabelColor: Colors.grey,
                     indicatorColor: color,
                     tabs: [
                       Tab(
                         icon: Icon(Icons.info_outline, size: 20),
                         text: isEnglish ? 'Overview' : '概览',
                       ),
                       Tab(
                         icon: Icon(Icons.science, size: 20),
                         text: isEnglish ? 'Science' : '科学',
                       ),
                       Tab(
                         icon: Icon(Icons.account_tree, size: 20),
                         text: isEnglish ? 'Impact' : '影响',
                       ),
                       Tab(
                         icon: Icon(Icons.link, size: 20),
                         text: isEnglish ? 'Connections' : '关系',
                       ),
                       Tab(
                         icon: Icon(Icons.quiz, size: 20),
                         text: isEnglish ? 'Quiz' : '测验',
                       ),
                     ],
                   ),
                 ),
                
                // 标签页内容
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOverviewTab(
                        event, 
                        color, 
                        isEnglish,
                        field,
                        description,
                        storyBrief,
                        storyDetailed,
                        historicalContext,
                        timeline,
                        funFactBrief,
                        funFactExtended,
                        kidExplanationSimple,
                        kidExplanationDetailed,
                        interactiveChallenge,
                      ),
                      
                      _buildScienceTab(
                        event,
                        color,
                        isEnglish,
                        principle,
                        applications,
                        experiment,
                        kidExplanationSimple,
                        kidExplanationDetailed,
                        interactiveChallenge,
                      ),
                      
                      _buildImpactTab(
                        event,
                        color,
                        isEnglish,
                        impactBrief,
                        impactDetailed,
                        modernExamples,
                        influenceStory,
                        influenceNames,
                        influencedEvents,
                      ),
                      
                      _buildConnectionsTab(
                        event,
                        color,
                        isEnglish,
                      ),
                      
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

    // 概览标签页
  Widget _buildOverviewTab(
    Map<String, dynamic> event,
    Color color,
    bool isEnglish,
    String field,
    String? description,
    String? storyBrief,
    String? storyDetailed,
    String? historicalContext,
    List? timeline,
    String? funFactBrief,
    List? funFactExtended,
    String? kidExplanationSimple,
    String? kidExplanationDetailed,
    String? interactiveChallenge,
  ) {
    String emoji = getFieldEmoji(event['field'] ?? '综合');
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 渐变色块
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.4),
                  color.withOpacity(0.7),
                  color,
                ],
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
          ),
          SizedBox(height: 16),
          
          // 简介
          if (description != null && description.isNotEmpty) ...[
            _buildSection('📖 ${isEnglish ? "Introduction" : "简介"}', description, color),
          ],
          
          // 简短故事
          if (storyBrief != null && storyBrief.isNotEmpty) ...[
            _buildSection('📚 ${isEnglish ? "Story" : "故事"}', storyBrief, color),
          ],
          
          // 详细故事
          if (storyDetailed != null && storyDetailed.isNotEmpty) ...[
            _buildExpandableSection(
              '📖 ${isEnglish ? "Detailed Story" : "详细故事"}',
              storyDetailed,
              color,
            ),
          ],
          
          // 历史背景
          if (historicalContext != null && historicalContext.isNotEmpty) ...[
            _buildExpandableSection(
              '🏛️ ${isEnglish ? "Historical Context" : "历史背景"}',
              historicalContext,
              color,
            ),
          ],
          
          // 时间线
          if (timeline != null && timeline.isNotEmpty) ...[
            _buildTimeline(timeline, color, isEnglish),
          ],
          
          // 简短趣味知识
          if (funFactBrief != null && funFactBrief.isNotEmpty) ...[
            _buildSection('🎉 ${isEnglish ? "Fun Fact" : "趣味知识"}', funFactBrief, color),
          ],
          
          // 扩展趣味知识
          if (funFactExtended != null && funFactExtended.isNotEmpty) ...[
            _buildFunFactCards(funFactExtended, color),
          ],
          
        ],
      ),
    );
  }

  // 科学标签页
  Widget _buildScienceTab(
    Map<String, dynamic> event,
    Color color,
    bool isEnglish,
    String? principle,
    String? applications,
    String? experiment,
    String? kidExplanationSimple,
    String? kidExplanationDetailed,
    String? interactiveChallenge,
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
          
          // 简单解释
          if (kidExplanationSimple != null && kidExplanationSimple.isNotEmpty) ...[
            _buildSection('👶 ${isEnglish ? "Simple Explanation" : "简单解释"}', kidExplanationSimple, color),
          ],
          
          // 详细解释
          if (kidExplanationDetailed != null && kidExplanationDetailed.isNotEmpty) ...[
            _buildExpandableSection(
              '🧒 ${isEnglish ? "Detailed Explanation" : "详细解释"}',
              kidExplanationDetailed,
              color,
            ),
          ],
          
          // 互动挑战
          if (interactiveChallenge != null && interactiveChallenge.isNotEmpty) ...[
            _buildInteractiveChallenge(interactiveChallenge, color, isEnglish),
          ],
          
          // 如果没有科学内容
          if ((principle == null || principle.isEmpty) &&
              (applications == null || applications.isEmpty) &&
              (experiment == null || experiment.isEmpty)) ...[
            Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.science_outlined, size: 80, color: Colors.grey[300]),
                    SizedBox(height: 16),
                    Text(
                      isEnglish 
                          ? 'Scientific details\ncoming soon...' 
                          : '科学详情\n即将添加...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
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

  // 影响标签页
  Widget _buildImpactTab(
    Map<String, dynamic> event,
    Color color,
    bool isEnglish,
    String? impactBrief,
    String? impactDetailed,
    List? modernExamples,
    String? influenceStory,
    List<String> influenceNames,
    List<String> influencedEvents,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 简短影响
          if (impactBrief != null && impactBrief.isNotEmpty) ...[
            _buildSection('💫 ${isEnglish ? "Impact" : "影响"}', impactBrief, color),
          ],
          
          // 详细影响
          if (impactDetailed != null && impactDetailed.isNotEmpty) ...[
            _buildExpandableSection(
              '📊 ${isEnglish ? "Detailed Impact" : "详细影响"}',
              impactDetailed,
              color,
            ),
          ],
          
          // 现代应用例子
          if (modernExamples != null && modernExamples.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              '💡 ${isEnglish ? "Modern Examples" : "现代例子"}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 12),
            ...modernExamples.map((example) {
              String exampleField = example['field'] ?? '';
              String exampleContent = example['example'] ?? '';
              
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exampleField,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      exampleContent,
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          
          // 知识传承故事
          if (influenceStory != null && influenceStory.isNotEmpty) ...[
            _buildExpandableSection(
              '🔗 ${isEnglish ? "Knowledge Legacy" : "知识传承故事"}',
              influenceStory,
              color,
            ),
          ],
          
          // 影响关系网络
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
                        isEnglish ? 'Knowledge Network' : '知识网络',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  
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
                                Expanded(child: Text(name, style: TextStyle(fontSize: 13))),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                  
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
                                Expanded(child: Text(name, style: TextStyle(fontSize: 13))),
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

  // 关系标签页
  Widget _buildConnectionsTab(
    Map<String, dynamic> event,
    Color color,
    bool isEnglish,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 与其他发现的联系
          if (event['connections_to_other_discoveries'] != null && 
              (event['connections_to_other_discoveries'] as List).isNotEmpty) ...[
            _buildConnectionsSection(
              '🔗 ${isEnglish ? "Connections to Other Discoveries" : "与其他发现的联系"}',
              event['connections_to_other_discoveries'],
              color,
              isEnglish,
            ),
          ],
          
          // 受哪些文明影响
          if (event['influenced_by'] != null && 
              (event['influenced_by'] as List).isNotEmpty) ...[
            _buildInfluencedBySection(
              '📜 ${isEnglish ? "Influenced By" : "受以下文明影响"}',
              event['influenced_by'],
              color,
              isEnglish,
            ),
          ],
          
          // 影响了哪些发现
          if (event['influences'] != null && 
              (event['influences'] as List).isNotEmpty) ...[
            _buildInfluencesSection(
              '🌟 ${isEnglish ? "Influences" : "影响了以下发现"}',
              event['influences'],
              color,
              isEnglish,
            ),
          ],
          
          // 如果没有关系数据
          if ((event['connections_to_other_discoveries'] == null || 
               (event['connections_to_other_discoveries'] as List).isEmpty) &&
              (event['influenced_by'] == null || 
               (event['influenced_by'] as List).isEmpty) &&
              (event['influences'] == null || 
               (event['influences'] as List).isEmpty)) ...[
            Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.link_off, size: 80, color: Colors.grey[300]),
                    SizedBox(height: 16),
                    Text(
                      isEnglish 
                          ? 'Connection details\ncoming soon...' 
                          : '关系详情\n即将添加...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
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

  // 测验标签页
  Widget _buildQuizTab(
    Map<String, dynamic> event,
    Color color,
  ) {
    final locale = Localizations.localeOf(context);
    final isEnglish = locale.languageCode == 'en';
    
    // 收集所有测验问题
    List<Map<String, dynamic>> allQuizzes = [];
    
    // 添加主要测验
    if (event['quiz'] != null) {
      allQuizzes.add(event['quiz']);
    }
    
    // 添加额外测验
    if (event['additional_quizzes'] != null) {
      allQuizzes.addAll(List<Map<String, dynamic>>.from(event['additional_quizzes']));
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          if (allQuizzes.isNotEmpty) ...[
            // 显示所有测验问题
            ...allQuizzes.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> quiz = entry.value;
              
              return Column(
                children: [
                  if (index > 0) SizedBox(height: 24), // 问题之间的间距
                  _buildQuiz(quiz, color, questionNumber: index + 1),
                ],
              );
            }).toList(),
          ] else ...[
            Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 80, color: Colors.grey[300]),
                    SizedBox(height: 16),
                    Text(
                      isEnglish 
                          ? 'Quiz coming soon...' 
                          : '测验即将添加...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
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

  // 基础内容区块
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

  // 可展开的内容区块
  Widget _buildExpandableSection(String title, String content, Color color) {
    return _ExpandableSection(
      title: title,
      content: content,
      color: color,
    );
  }

  // 时间线组件
  Widget _buildTimeline(List timeline, Color color, bool isEnglish) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          '📅 ${isEnglish ? "Timeline" : "时间线"}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 12),
        ...timeline.asMap().entries.map((entry) {
          int index = entry.key;
          var item = entry.value;
          String year = item['year'] ?? '';
          String eventText = item['event'] ?? '';
          bool isLast = index == timeline.length - 1;
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      color: color.withOpacity(0.3),
                    ),
                ],
              ),
              SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        year,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        eventText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  // 趣味知识卡片
  Widget _buildFunFactCards(List funFacts, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          '🎊 ${Localizations.localeOf(context).languageCode == 'en' ? "More Fun Facts" : "更多趣味知识"}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 12),
        ...funFacts.map((fact) {
          String factTitle = fact['title'] ?? '';
          String factContent = fact['content'] ?? '';
          
          return Card(
            margin: EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color.withOpacity(0.3)),
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(
                factTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    factContent,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // 互动挑战组件
  Widget _buildInteractiveChallenge(String challenge, Color color, bool isEnglish) {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.withOpacity(0.2), Colors.orange.withOpacity(0.2)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.orange[700], size: 24),
              SizedBox(width: 8),
              Text(
                isEnglish ? '🎮 Interactive Challenge' : '🎮 互动挑战',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            challenge,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuiz(Map<String, dynamic> quiz, Color color, {int? questionNumber}) {
    return _QuizWidget(quiz: quiz, color: color, questionNumber: questionNumber);
  }

  void _showInfluenceDialog(Map<String, dynamic> line) {
    final locale = Localizations.localeOf(context);
    final isEnglish = locale.languageCode == 'en';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Knowledge Transfer' : '知识传播'),
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
  // 构建与其他发现的联系部分
  Widget _buildConnectionsSection(
    String title,
    List connections,
    Color color,
    bool isEnglish,
  ) {
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
        SizedBox(height: 12),
        ...connections.map((connection) {
          String connectionTitle = isEnglish && connection['title_en'] != null
              ? connection['title_en']
              : connection['title'] ?? '';
          String relationship = isEnglish && connection['relationship_en'] != null
              ? connection['relationship_en']
              : connection['relationship'] ?? '';
          
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connectionTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  relationship,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // 构建受哪些文明影响部分
  Widget _buildInfluencedBySection(
    String title,
    List influencedBy,
    Color color,
    bool isEnglish,
  ) {
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
        SizedBox(height: 12),
        ...influencedBy.map((influence) {
          // 支持两种类型：civilization 或 person
          String name = '';
          if (influence['civilization'] != null) {
            name = isEnglish && influence['civilization_en'] != null
                ? influence['civilization_en']
                : influence['civilization'] ?? '';
          } else if (influence['person'] != null) {
            name = isEnglish && influence['person_en'] != null
                ? influence['person_en']
                : influence['person'] ?? '';
          }
          
          String contribution = isEnglish && influence['contribution_en'] != null
              ? influence['contribution_en']
              : influence['contribution'] ?? '';
          
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  contribution,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // 构建影响了哪些发现部分
  Widget _buildInfluencesSection(
    String title,
    List influences,
    Color color,
    bool isEnglish,
  ) {
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
        SizedBox(height: 12),
        ...influences.map((influence) {
          String influenceTitle = isEnglish && influence['title_en'] != null
              ? influence['title_en']
              : influence['title'] ?? '';
          String description = isEnglish && influence['description_en'] != null
              ? influence['description_en']
              : influence['description'] ?? '';
          
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  influenceTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

} // _MapScreenState 类结束

// 可展开内容组件
class _ExpandableSection extends StatefulWidget {
  final String title;
  final String content;
  final Color color;

  const _ExpandableSection({
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  _ExpandableSectionState createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        InkWell(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.color,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: widget.color,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.color.withOpacity(0.2)),
            ),
            child: Text(
              widget.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// _QuizWidget 类（在 _MapScreenState 外面）
class _QuizWidget extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final Color color;
  final int? questionNumber;

  const _QuizWidget({
    required this.quiz,
    required this.color,
    this.questionNumber,
  });

  @override
  State<_QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<_QuizWidget> {
  int? selectedAnswer;
  bool? isCorrect;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isEnglish = locale.languageCode == 'en';
    
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
          widget.questionNumber != null 
              ? '❓ ${isEnglish ? "Question" : "问题"} ${widget.questionNumber}'
              : '❓ ${isEnglish ? "Quiz" : "小测验"}',
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
                          isCorrect! 
                              ? (isEnglish ? 'Great! Correct! 🎉' : '太棒了！答对了！🎉')
                              : (isEnglish ? 'Try again!' : '再想想，试试其他选项！'),
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