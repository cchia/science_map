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
    
    // 如果选择了故事模式，只显示该模式的事件
    if (selectedStoryMode != null) {
      var mode = storyModes.firstWhere((m) => m['id'] == selectedStoryMode);
      List<String> modeEventIds = List<String>.from(mode['events']);
      filtered = filtered.where((event) => modeEventIds.contains(event['id']));
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
      title: Text(l10n.appTitle),
      actions: [
        // 🆕 语言切换按钮
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
          
        // 修改学习路径选择器
        Positioned(
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
                    l10n.learningPath,  // 使用翻译
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedStoryMode,
                    hint: Text(l10n.selectTheme),  // 使用翻译
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(l10n.allEvents),  // 使用翻译
                      ),
                      ...storyModes.map((mode) {
                        return DropdownMenuItem<String>(
                          value: mode['id'] as String,
                          child: Row(
                            children: [
                              Text(mode['emoji'], style: TextStyle(fontSize: 20)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  mode['title'],
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
                    Text(
                      storyModes.firstWhere((m) => m['id'] == selectedStoryMode)['description'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _startStoryMode(),
                      icon: Icon(Icons.play_arrow),
                      label: Text(l10n.startLearning),  // 使用翻译
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 36),
                      ),
                    ),
                  ],
                ],
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
        
        // 修改时间轴控制器
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
                    '${l10n.year}: ${selectedYear.round()}',  // 使用翻译
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
                        tooltip: l10n.resetButton,  // 使用翻译
                      ),
                      
                      SizedBox(width: 20),
                      
                      ElevatedButton.icon(
                        onPressed: _togglePlay,
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 32,
                        ),
                        label: Text(
                          isPlaying ? l10n.pauseButton : l10n.playButton,  // 使用翻译
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
                    '${l10n.showingEvents(getFilteredEvents().length)} | ${getInfluenceLines().length} ${l10n.linesCount}',  // 使用翻译
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
    builder: (context) => Dialog(
      child: Container(
        width: 500,
        constraints: BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                          '${event['year']} · $city}',
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
            
            // 内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    
                    SizedBox(height: 16),
                    
    if (description != null && description.isNotEmpty) ...[
      _buildSection('📖 ${l10n.introduction}', description, color),
    ],
    
    if (story != null && story.isNotEmpty) ...[
      _buildSection('📚 ${l10n.story}', story, color),
    ],
    
    if (funFact != null && funFact.isNotEmpty) ...[
      _buildSection('🎉 ${l10n.funFact}', funFact, color),
    ],
    
    if (kidExplanation != null && kidExplanation.isNotEmpty) ...[
      _buildSection('👶 ${l10n.simpleExplanation}', kidExplanation, color),
    ],
    
    if (impact != null && impact.isNotEmpty) ...[
      _buildSection('💫 ${l10n.impact}', impact, color),
    ],
    
    if (influenceStory != null && influenceStory.isNotEmpty) ...[
      _buildSection('🔗 ${l10n.influenceStory}', influenceStory, color),
    ],

                    // 相关概念
if (event['related_concepts'] != null) ...[
  SizedBox(height: 16),
  Text(
    '🔑 ${l10n.relatedConcepts}',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: color,
    ),
  ),
  SizedBox(height: 8),
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: (event['related_concepts'] as List).asMap().entries.map((entry) {
      int index = entry.key;
      String concept = entry.value;
      
      // 🆕 根据语言选择概念文本
      String conceptText = concept;
      if (isEnglish && event['related_concepts_en'] != null) {
        List conceptsEn = event['related_concepts_en'] as List;
        if (index < conceptsEn.length) {
          conceptText = conceptsEn[index];
        }
      }
      
      return Chip(
        label: Text(conceptText),  // ✅ 使用 conceptText
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide(color: color),
      );
    }).toList(),
  ),
],
                    
                    // 🆕 影响关系区域
// 影响关系区域
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
              l10n.knowledgeTransfer,  // ✅ 使用翻译
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
                      l10n.influencedBy,  // ✅ 使用翻译
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
                        child: Text(
                          name,
                          style: TextStyle(fontSize: 13),
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
                      l10n.influenced,  // ✅ 使用翻译
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
                        child: Text(
                          name,
                          style: TextStyle(fontSize: 13),
                        ),
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
                    
                    if (event['quiz'] != null) ...[
                      SizedBox(height: 16),
                      _buildQuiz(event['quiz'], color),
                    ],
                  ],
                ),
              ),
            ),
          ],
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