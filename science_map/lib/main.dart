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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:graphview/GraphView.dart';
import 'package:flutter/gestures.dart';

enum FocusMode { none, simple, evolution }

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
  Locale _locale = Locale('en');

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
        Locale('en', ''),
        Locale('zh', ''),
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
  double _minYear = -1000; // 默认值 (会被覆盖)
  double _maxYear = 2025; // 默认值 (会被覆盖)
  double selectedYear = -1000; // 默认值 (会被覆盖)
  RangeValues _zoomedRange = RangeValues(-1000, 2025); // <-- 新增：缩放范围
  bool isPlaying = false;
  Timer? _timer;
  String? _focusedEventId; // <-- 新增：用于跟踪被选中的事件
  Map<String, dynamic>? _focusedEvent;
  Set<String> _focalEventIds = {}; // <-- (新增) 存储焦点链中的所有ID  
  FocusMode _currentFocusMode = FocusMode.none;

// --- (新增) 侧边栏宽度控制 ---
  double _panelWidth = 450.0; // 默认宽度
  final double _minPanelWidth = 350.0; // 最小宽度
  final double _maxPanelWidth = 800.0; // 最大宽度
  // --- (新增结束) ---

  // 数据
  List<Map<String, dynamic>> events = [];
  //List<Map<String, dynamic>> storyModes = [];
  Map<String, dynamic> people = {}; // <--  modification
  Map<String, dynamic> storylines = {};
  bool isLoading = true;
  
  // 筛选
  //String? selectedStoryMode;
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
    '哲学': Colors.teal,
    '工程学': Colors.grey[700]!, // <-- 新增
    '地理学': Colors.lightGreen, // <-- 新增
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
    '哲学': '🏛️',
    '工程学': '⚙️', // <-- 新增
    '地理学': '🌍', // <-- 新增
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
    '哲学': 'Philosophy',
    '工程学': 'Engineering', // <-- 新增
    '地理学': 'Geography', // <-- 新增
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
          print('⚠️ 加载事件失败: $eventId');
        }
      }
      
      // 加载学习路径
      //final modesJson = await rootBundle.loadString('assets/story_modes.json');
      //final modesData = json.decode(modesJson);

      // 加载人物数据
      final peopleIndexJson = await rootBundle.loadString('assets/people_index.json');
      final List<dynamic> personIds = json.decode(peopleIndexJson);

      Map<String, dynamic> loadedPeople = {};
      for (var personId in personIds) {
        try {
          final personJson = await rootBundle.loadString('assets/people/$personId.json');
          final personData = json.decode(personJson);
          loadedPeople[personId] = personData; 
        } catch (e) {
          print('⚠️ 加载人物失败: $personId');
        }
      }

      // --- (新增) 加载故事线 ---
      final storylinesJson = await rootBundle.loadString('assets/storylines.json');
      final Map<String, dynamic> loadedStorylines = json.decode(storylinesJson);
      // --- (新增结束) ---      

      // --- (新增) 查找年份范围 ---
      double minYear = -1000; // 默认
      double maxYear = 2025; // 默认
      if (loadedEvents.isNotEmpty) {
         // 我们只关心非"存根"事件的年份范围
         final years = loadedEvents
             .where((e) => e['is_stub'] != true) 
             .map((e) => e['year'] as int);
             
         if (years.isNotEmpty) {
            minYear = years.reduce((a, b) => a < b ? a : b).toDouble();
            maxYear = years.reduce((a, b) => a > b ? a : b).toDouble();
         }
         
         // 确保最大年份至少是今年，以便动画可以播放
         if (maxYear < 2025) maxYear = 2025;
      }
      // --- (新增结束) ---
      
      setState(() {
        events = loadedEvents;
        //storyModes = modesData.cast<Map<String, dynamic>>();
        people = loadedPeople; 
        storylines = loadedStorylines;
        _minYear = minYear;       // <-- 设置
        _maxYear = maxYear;       // <-- 设置
        selectedYear = minYear; // <-- 在这里设置
        _zoomedRange = RangeValues(minYear, maxYear);
        
        isLoading = false;
      });
      
      print('✅ 加载完成: ${events.length} 个事件, ${people.length} 个人物');
    } catch (e) {
      print('❌ 加载失败: $e');
      setState(() {
        isLoading = false;
      });
    }
  }


  // ========== 辅助方法 ==========

// (新增一个辅助函数)
  List<String> _getFieldsFromEvent(Map<String, dynamic> event) {
    var fieldData = event['field']; // 'field' 始终是中文key
    if (fieldData == null) {
      return ['综合'];
    } else if (fieldData is List) {
      // 如果是列表，确保它不为空，否则返回默认值
      return List<String>.from(fieldData.isNotEmpty ? fieldData : ['综合']);
    } else if (fieldData is String) {
      // 如果是旧的字符串格式，将其包装在列表中
      return [fieldData];
    }
    return ['综合'];
  }

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
        // (可选) 动态调整步长
        double step = (_maxYear - _minYear) / 200; // (让动画总是在20秒左右完成)
        if (step < 2) step = 2; // 最小步长

        selectedYear += step;
        
        if (selectedYear >= _maxYear) {
          selectedYear = _maxYear;
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
      selectedYear = _minYear; // <-- 直接使用已计算的最小值
      _zoomedRange = RangeValues(_minYear, _maxYear);
    });
  }
  // ========== 数据筛选 ==========
// ========== 数据筛选 (已修改为支持焦点模式) ==========
  List<Map<String, dynamic>> getFilteredEvents() {
    
    var filtered = events.where((event) {
      final bool isStub = event['is_stub'] ?? false;
      if (isStub) return false;

      // --- (新) 可见性规则 ---
      // 规则1：事件是否在焦点链中？
      bool isInFocusSet = _focalEventIds.contains(event['id']);
      
      // 规则2：事件是否在100年时间窗口内？
      bool isInTimeWindow = event['year'] <= selectedYear && event['year'] > (selectedYear - 100);

      // 只要满足任一规则，事件就可见
      return isInTimeWindow || isInFocusSet;
      // --- (新规则结束) ---
    });
    
    // (以下过滤器保持不变，它们会作用于上面的结果集)

    // 学科筛选
    if (selectedFields.isNotEmpty) {
      filtered = filtered.where((event) {
        List<String> eventFields = _getFieldsFromEvent(event);
        return eventFields.any((field) => selectedFields.contains(field));
      });
    }
    
    // 搜索筛选
    if (searchQuery.isNotEmpty) {
      final isEnglish = Localizations.localeOf(context).languageCode == 'en';
      filtered = filtered.where((event) {
        String title = isEnglish && event['title_en'] != null 
            ? event['title_en'] : event['title'];
        
        String city = '';
        var cityEn = event['city_en'];
        var cityZh = event['city'];
        if (isEnglish && cityEn != null && cityEn is String) {
          city = cityEn;
        } else if (cityZh != null && cityZh is String) {
          city = cityZh;
        }
        
        String query = searchQuery.toLowerCase();
        return title.toLowerCase().contains(query) || 
               city.toLowerCase().contains(query);
      });
    }
    
    return filtered.toList();
  }  

// ========== (修改) 获取连线逻辑 (带时间过滤) ==========
  List<Map<String, dynamic>> getInfluenceLines() {
    List<Map<String, dynamic>> lines = [];

    // 情况 A: 没有焦点事件 -> 不画线
    if (_focusedEvent == null) return [];

    // 情况 B: 演化/故事模式
    if (_currentFocusMode == FocusMode.evolution && _focalEventIds.isNotEmpty) {
      
      // 1. 获取所有相关事件
      List<Map<String, dynamic>> storyEvents = events
          .where((e) => _focalEventIds.contains(e['id']))
          .toList();
      
      // 2. 排序
      storyEvents.sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));

      // 3. 两两连接
      for (int i = 0; i < storyEvents.length - 1; i++) {
        var start = storyEvents[i];
        var end = storyEvents[i + 1];

        // --- (新增) 核心修改：时间过滤器 ---
        // 如果当前时间轴还没走到“终点”事件的年份，就不画这条线
        // 效果：线会随着时间推移一段一段出现
        if ((end['year'] as int) > selectedYear) {
          continue; 
        }
        // --- (修改结束) ---

        // 确保都有坐标
        if (start['lat'] != null && start['lng'] != null && 
            end['lat'] != null && end['lng'] != null) {
            
          lines.add({
            'from': LatLng(start['lat'], start['lng']),
            'to': LatLng(end['lat'], end['lng']),
            'color': Colors.amber[700], 
            'strokeWidth': 4.0,
            'isDashed': false,
          });
        }
      }
      return lines;
    }

    // 情况 C: 简单模式 (不画线)
    return []; 
  }

// (新) 侧边栏拖动回调
  void _onPanelDrag(DragUpdateDetails details) {
    setState(() {
      // 拖动 (details.delta.dx)
      // 向左拖动 (dx 为负) = 减小宽度
      // 向右拖动 (dx 为正) = 增大宽度
      // 我们的手柄在左侧，所以向左拖（负）应该减小宽度
      _panelWidth -= details.delta.dx;
      
      // 限制最小/最大宽度
      _panelWidth = _panelWidth.clamp(_minPanelWidth, _maxPanelWidth);
    });
  }

  // ========== UI构建 ==========
  @override
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
      // --- (修改) 从 Stack 改为 Row 布局 ---
      body: Row(
        children: [
          // (新) 地图和控制器
          Expanded( // <-- 地图现在会占据所有剩余空间
            child: Stack(
              children: [
                _buildMap(),
                _buildLegend(l10n, isEnglish),
                _buildTimelineController(l10n, isEnglish),
                _buildStoryButton(isEnglish), // <-- (新增) 添加故事模式按钮
                _buildStoryTimelineRail(),
              ],
            ),
          ),
          
          // (新) 详情面板
          // 如果 _focusedEvent 不是 null，则构建并显示侧边栏
          if (_focusedEvent != null)
            _buildDetailsPanel(
              context, 
              _focusedEvent!, 
              isEnglish,
              _panelWidth,    // <-- (新增) 传递当前宽度
              _onPanelDrag,   // <-- (新增) 传递拖动回调
            ),
        ],
      ),
      // --- (修改结束) ---
    );
  }

// ========== 关于对话框 ==========
  void _showAboutDialog(BuildContext context, bool isEnglish) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            SizedBox(width: 10),
            Text(isEnglish ? 'About Atlas of Thought' : '关于 Atlas of Thought'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min, // 让弹窗自适应内容高度
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEnglish 
                ? 'This app is a curated knowledge graph of scientific and philosophical ideas.'
                : '这是一个关于科学与哲学思想演变的知识图谱。',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 20),
            Text(
              isEnglish ? 'Curated by:' : '策展人:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'C. Chia', // <-- 您可以修改为您希望显示的名字
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                icon: Icon(Icons.feedback_outlined),
                label: Text(isEnglish ? 'Provide Feedback' : '提供反馈'),
                onPressed: () {
                  // --- 在这里填入您的反馈链接 ---
                  // 方案 A: Google 表单
                  final Uri feedbackUrl = Uri.parse('https://docs.google.com/forms/d/e/1FAIpQLSfyrdQW5dgh1TVyZRy5p0KjqO2-QrmmNGF1wHxQNil4FRmmvA/viewform?usp=header');
                  
                  // 方案 B: 启动电子邮件
                  // final Uri feedbackUrl = Uri(
                  //   scheme: 'mailto',
                  //   path: 'your-email@gmail.com',
                  //   query: 'subject=Feedback for Atlas of Thought',
                  // );
                  
                  launchUrl(feedbackUrl);
                  Navigator.pop(context);
                },
              ),
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
        // --- (新增) "关于"按钮 ---
        IconButton(
          icon: Icon(Icons.info_outline),
          tooltip: isEnglish ? 'About' : '关于',
          onPressed: () => _showAboutDialog(context, isEnglish),
        ),
        // --- (新增结束) ---        
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
        // _buildArrowLayer(),

// <-- 新的聚类图层 -->
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 80, // 聚类的像素半径
            size: Size(50, 50), // 聚类标记的大小
            alignment: Alignment.center,
            
            // 插件需要的标记列表
            markers: getFilteredEvents().map((event) {
              return _buildSingleEventMarker(event);
            }).toList(),
            
            // 我们的自定义聚类标记构建器
            builder: (context, markers) {
              // 注意：markers 列表现在包含的是 Marker 对象，而不是 event map
              // 我们需要从 marker 中获取 event 数据
              // 但对于聚类标记，我们只需要数量和颜色
              
              // (为了简单起见，我们只用第一个事件的颜色作为聚类颜色)
              Color clusterColor = Colors.blue; // 默认
              if (markers.isNotEmpty) {
                 // 这是个变通方法，因为我们不能轻易地从 Marker 访问 event
                 // 我们需要重新查找事件来获取颜色
                 var firstEvent = events.firstWhere(
                   (e) => e['lat'] == markers.first.point.latitude && e['lng'] == markers.first.point.longitude,
                   orElse: () => {},
                 );
                 if (firstEvent.isNotEmpty) {
                    clusterColor = getFieldColor(_getFieldsFromEvent(firstEvent).first);
                 }
              }

              return _buildClusterMarkerWidget(markers.length, clusterColor);
            },
            
            // (可选) "蛛网化"的样式
            spiderfyCluster: false, // <-- 1. 禁用蛛网化
            
            // <-- 2. 添加点击回调 -->
            onClusterTap: _onClusterTapped,
          ),
        ),
        // <-- 聚类图层结束 -->        

      ],
    );
  }

// (新) 递归图遍历函数
  Set<String> _getRecursiveEventChain(Map<String, dynamic> startingEvent) {
    
    final Set<String> allRelatedIds = {}; // 存储所有找到的ID
    final List<Map<String, dynamic>> queue = []; // 用于广度优先搜索 (BFS)

    // --- 1. 向后遍历 (Follow 'influenced_by') ---
    queue.add(startingEvent);
    while (queue.isNotEmpty) {
      final currentEvent = queue.removeAt(0);
      if (allRelatedIds.contains(currentEvent['id'])) continue;
      allRelatedIds.add(currentEvent['id']);

      final chain = currentEvent['influence_chain'];
      if (chain != null && chain is Map && chain['influenced_by'] != null) {
        for (var item in (chain['influenced_by'] as List)) {
          var sourceId = item['id'];
          if (sourceId != null) {
            var sourceEvent = events.firstWhere(
              (e) => e['id'] == sourceId, 
              orElse: () => {}
            );
            if (sourceEvent.isNotEmpty) {
              queue.add(sourceEvent);
            }
          }
        }
      }
    }

    // --- 2. 向前遍历 (Follow 'influenced') ---
    queue.add(startingEvent); // 重新从起点开始
    while (queue.isNotEmpty) {
      final currentEvent = queue.removeAt(0);
      if (allRelatedIds.contains(currentEvent['id'])) continue;
      allRelatedIds.add(currentEvent['id']);

      final chain = currentEvent['influence_chain'];
      if (chain != null && chain is Map && chain['influenced'] != null) {
        for (var item in (chain['influenced'] as List)) {
          var targetId = item['id'];
          if (targetId != null) {
            var targetEvent = events.firstWhere(
              (e) => e['id'] == targetId, 
              orElse: () => {}
            );
            if (targetEvent.isNotEmpty) {
              queue.add(targetEvent);
            }
          }
        }
      }
    }
    
    return allRelatedIds;
  }

// 当一个聚类被点击时的回调
  void _onClusterTapped(MarkerClusterNode cluster) {
    
    // 1. 从 Marker 列表中提取坐标 *值* 的一个 Set
    final Set<String> clusterPoints = cluster.markers.map((m) {
      return '${m.point.latitude}_${m.point.longitude}';
    }).toSet();

    // 2. (已修复) 搜索 *已经过时间过滤* 的列表
    final List<Map<String, dynamic>> clusterEvents = getFilteredEvents().where((event) {
      // 为事件的坐标创建相同的字符串
      String eventPointKey = '${event['lat']}_${event['lng']}';
      
      // 检查 Set 是否包含这个事件的坐标
      return clusterPoints.contains(eventPointKey);
    }).toList();

    // 3. 如果找到了事件，就显示 Bottom Sheet 列表
    if (clusterEvents.isNotEmpty) {
      _showClusterBottomSheet(clusterEvents);
    } else {
      // (用于调试)
      print("Cluster tapped, but no matching *filtered* events found.");
    }
  }

// (新) 显示聚类事件列表 (使用 Bottom Sheet)
  void _showClusterBottomSheet(List<Map<String, dynamic>> events) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    
    // 按年份排序，最新的在最前面
    events.sort((a, b) => (b['year'] as int).compareTo(a['year'] as int));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允许它占用更多空间
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false, // 不允许全屏
          initialChildSize: 0.5, // 初始大小为屏幕的 50%
          minChildSize: 0.3,   // 最小 30%
          maxChildSize: 0.8,   // 最大 80%
          builder: (context, scrollController) {

            final bool isEnglish = Localizations.localeOf(context).languageCode == 'en';
            var firstEvent = events[0];
            String cityName = '';
            var cityEn = firstEvent['city_en'];
            var city = firstEvent['city'];
            if (isEnglish && cityEn != null && cityEn is String && cityEn.isNotEmpty) {
              cityName = cityEn;
            } else if (city != null && city is String) {
              cityName = city;
            }

            return Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // 标题
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.blue, size: 28),
                        SizedBox(width: 12),
                        Text(
                          '$cityName - ${events.length} ${isEnglish ? "events" : "个事件"}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                  ),
                  
                  // 事件列表
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController, // 使用 DraggableScrollableSheet 的控制器
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        var event = events[index];
                        String title = isEnglish && event['title_en'] != null
                            ? event['title_en']
                            : event['title'];
                        
                        String primaryField = _getFieldsFromEvent(event).first;
                        Color color = getFieldColor(primaryField);
                        String emoji = getFieldEmoji(primaryField);
                        
                  // --- (修改) 获取人名 (支持多人) ---
                  String? personNames; // 重命名为复数

                  // (新) 解析 personIds (兼容旧的 personId)
                  List<String> personIdList = [];
                  var pIds = event['personIds']; // 新的 "personIds" 字段 (数组)
                  var pId = event['personId'];  // 旧的 "personId" 字段 (字符串)
                  if (pIds is List) {
                    personIdList = List<String>.from(pIds);
                  } else if (pId is String) {
                    personIdList = [pId];
                  }

                  if (personIdList.isNotEmpty) {
                    List<String> names = [];
                    for (var pid in personIdList) {
                      if (people.containsKey(pid)) {
                        final personData = people[pid];
                        String fullName = isEnglish && personData['name_en'] != null
                            ? personData['name_en']
                            : personData['name'];

                        // --- (这是从 _buildSingleEventMarker 复制过来的完整逻辑) ---
                        String lastName = fullName.split(' ').last;
                        // 对于中文名，不需要拆分
                        if (!isEnglish && fullName.length > 2) { 
                            lastName = fullName;
                        } else if (!isEnglish) {
                            lastName = fullName;
                        }
                        names.add(lastName);
                        // --- (完整逻辑结束) ---
                      }
                    }
                    // 用 " & " 或 "和" 连接
                    personNames = names.join(isEnglish ? ' & ' : '、');
                  }
                  // --- (修改结束) ---

                        return Card(
                          margin: EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 2)
                              ),
                              child: Center(
                                child: Text(emoji, style: TextStyle(fontSize: 22)),
                              ),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                            (personNames != null)
                              ? '$personNames · ${event['year']}' // "Watson & Crick · 1953"
                              : '${event['year']}', // "1666"
                            style: TextStyle(fontSize: 13),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                          Navigator.pop(context); // 1. 关闭 Bottom Sheet

                          // 2. (新) 复制 _buildSingleEventMarker 中的焦点逻辑
                          // --- 在点击时计算所有相关的ID ---
                          Set<String> newFocalIds = {};
                          newFocalIds.add(event['id']); // 添加被点击的事件本身

                          var chain = event['influence_chain'];
                          if (chain != null && chain is Map) {
                            // 添加所有 "influenced_by" 的事件
                            var influencedByList = chain['influenced_by'];
                            if (influencedByList != null && influencedByList is List) {
                              for (var item in influencedByList) {
                                if (item['id'] != null) newFocalIds.add(item['id']);
                              }
                            }
                            // 添加所有 "influenced" 的事件
                            var influencedList = chain['influenced'];
                            if (influencedList != null && influencedList is List) {
                              for (var item in influencedList) {
                                if (item['id'] != null) newFocalIds.add(item['id']);
                              }
                            }
                          }
                          // --- 逻辑结束 ---

                          // 3. (新) 设置状态以打开侧边栏
                          setState(() {
                            _focusedEvent = event;
                            _focalEventIds = newFocalIds;
                            _currentFocusMode = FocusMode.simple;
                            _panelWidth = 450.0; 
                          });
                        },                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  PolylineLayer _buildPolylineLayer() {
    final lines = getInfluenceLines();
    if (lines.isEmpty) return PolylineLayer(polylines: []);

    return PolylineLayer(
      polylines: lines.map((line) {
        return Polyline(
          points: [line['from'], line['to']],
          strokeWidth: line['strokeWidth'] ?? 3.0, // 使用自定义宽度
          color: (line['color'] as Color? ?? Colors.blue).withOpacity(0.7), // 使用自定义颜色
          borderStrokeWidth: 2.0, // 加个白边，让线在地图上更清楚
          borderColor: Colors.white, 
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

 // ========== (新增) 显示故事列表 ==========
  void _showStoryListDialog(bool isEnglish) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_stories, color: Colors.amber[800]),
              SizedBox(width: 10),
              Text(isEnglish ? 'Curated Storylines' : '精选演化故事'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: storylines.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(isEnglish ? "No storylines loaded." : "暂无故事数据"),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: storylines.length,
                    itemBuilder: (context, index) {
                      String key = storylines.keys.elementAt(index);
                      Map<String, dynamic> story = storylines[key];
                      
                      String title = isEnglish && story['title_en'] != null 
                          ? story['title_en'] 
                          : story['title_zh'];
                      String desc = isEnglish && story['description_en'] != null 
                          ? story['description_en'] 
                          : (story['description_zh'] ?? "");
                      String emoji = story['emoji'] ?? "📚";
                      int count = (story['events'] as List).length;

                      return ListTile(
                        leading: Text(emoji, style: TextStyle(fontSize: 32)),
                        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: desc.isNotEmpty 
                            ? Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis) 
                            : null,
                        trailing: Chip(
                          label: Text('$count', style: TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: Colors.blue[300],
                          padding: EdgeInsets.all(0),
                        ),
                        onTap: () {
                          Navigator.pop(context); // 关闭弹窗
                          _launchStoryMode(story); // 启动故事
                        },
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
        );
      },
    );
  }

// ========== (新增) 启动故事模式 ==========
  void _launchStoryMode(Map<String, dynamic> story) {
    // 1. 获取故事的事件列表
    List<String> eventIds = List<String>.from(story['events']);
    if (eventIds.isEmpty) return;

    // 2. 找到第一个事件 (作为入口点)
    String firstEventId = eventIds.first;
    Map<String, dynamic> firstEvent = events.firstWhere(
      (e) => e['id'] == firstEventId,
      orElse: () => {},
    );

    if (firstEvent.isNotEmpty) {
      setState(() {
        // A. 将时间轴跳转到该事件的年份
        selectedYear = (firstEvent['year'] as int).toDouble();
        
        // B. 设置焦点事件 (打开侧边栏)
        _focusedEvent = firstEvent;
        
        // C. 关键：直接设置演化模式的数据！
        _focalEventIds = eventIds.toSet();
        _currentFocusMode = FocusMode.evolution;
        
        // D. 调整侧边栏宽度
        _panelWidth = 600.0; 
      });
      
      // ✨✨✨ 新增：启动后立即显示叙事简报 ✨✨✨
      // 使用 Future.delayed 确保在 Build 完成后弹出
      Future.delayed(Duration(milliseconds: 300), () {
        if (story.containsKey('narrative_intro')) {
          _showNarrativeDialog(story);
        }
      });
    }
  }

// ========== (新增) 故事模式按钮 ==========
  Widget _buildStoryButton(bool isEnglish) {
    return Positioned(
      top: 20,
      left: 20, // 放在左上角
      child: FloatingActionButton.extended(
        heroTag: "story_btn", // 避免 tag 冲突
        onPressed: () => _showStoryListDialog(isEnglish),
        icon: Icon(Icons.auto_stories),
        label: Text(isEnglish ? 'Storylines' : '精选故事'),
        backgroundColor: Colors.amber[800],
        foregroundColor: Colors.white,
      ),
    );
  }

  // ========== 图例 ==========
  Widget _buildLegend(AppLocalizations l10n, bool isEnglish) {
    return Positioned(
      top: 20,
      right: 20,
      child: Opacity( // <-- 新增
        opacity: 0.9,
        child: Card(
          elevation: 2, // <-- 修改
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // <-- 新增
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
                  fontSize: 22, // <-- 修改
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                  letterSpacing: 0.5, // <-- 新增
                ),
              ),
              SizedBox(height: 8),

// --- (新) 主时间轴 (已缩放) ---
              Slider(
                value: selectedYear,
                min: _zoomedRange.start, // <-- (修改) 使用缩放范围
                max: _zoomedRange.end,   // <-- (修改) 使用缩放范围
                divisions: (_zoomedRange.end - _zoomedRange.start).round().clamp(1, 1000000),
                label: selectedYear.round().toString(),
                onChanged: isPlaying ? null : (value) {
                  setState(() => selectedYear = value);
                },
              ),
              
              // --- (新) 缩放范围控制器 (概览轴) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: RangeSlider(
                  values: _zoomedRange,
                  min: _minYear,
                  max: _maxYear,
                  // (可选) 减少 divisions 以获得更平滑的概览滚动
                  divisions: (_maxYear - _minYear).round().clamp(1, 1000000) ~/ 50, 
                  labels: RangeLabels(
                    _zoomedRange.start.round().toString(),
                    _zoomedRange.end.round().toString(),
                  ),
                  onChanged: isPlaying ? null : (newRange) {
                    setState(() {
                      // 确保范围至少为 100 年 (避免缩放得太近)
                      if (newRange.end - newRange.start < 100) {
                         // 保持中心点，但扩展范围
                         final center = (newRange.start + newRange.end) / 2;
                         _zoomedRange = RangeValues(
                           (center - 50).clamp(_minYear, _maxYear), 
                           (center + 50).clamp(_minYear, _maxYear)
                         );
                      } else {
                        _zoomedRange = newRange;
                      }
                      
                      // 确保 "selectedYear" 始终在新范围内
                      selectedYear = selectedYear.clamp(_zoomedRange.start, _zoomedRange.end);
                    });
                  },
                ),
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
                      shape: RoundedRectangleBorder( // <-- 新增
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4, // <-- 新增
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

// ========== (新增) 故事线选择对话框 ==========
  Future<String?> _showStorylineSelectionDialog(List<String> storylineIds) async {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final l10n = AppLocalizations.of(context);

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(isEnglish ? 'Select Storyline' : '选择故事线'),
          children: storylineIds.map((id) {
            // 从已加载的 map 中获取故事详情
            final story = storylines[id];
            if (story == null) {
              return SizedBox.shrink(); // 无效 ID, 跳过
            }

            final String emoji = story['emoji'] ?? '📚';
            final String title = isEnglish && story['title_en'] != null 
                ? story['title_en'] 
                : story['title_zh'];

            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, id); // 返回被选中的 story id
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Text(emoji, style: TextStyle(fontSize: 24)),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(title, style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
  // ========== 事件详情对话框 ==========
  // <-- MODIFIED _showEventDialog -->
// ========== 事件详情对话框 (已修改为从右侧滑入) ==========
  void _showEventDialog(Map<String, dynamic> event) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    
    String primaryField = _getFieldsFromEvent(event).first;
    final color = getFieldColor(primaryField);
    final emoji = getFieldEmoji(primaryField);

    // 1. (逻辑不变) 设置焦点，触发 'getInfluenceLines' 重绘
    setState(() {
      _focusedEventId = event['id'];
    });

    // 2. (修改) 从 'showDialog' 替换为 'showGeneralDialog'
    showGeneralDialog(
      context: context,
      // (新) 让背景变暗，但点击背景时可以关闭
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.3), // 调暗背景
      
      // (新) 动画时长
      transitionDuration: const Duration(milliseconds: 300),
      
      // (新) 页面构建器 (返回我们的 EventDialog)
      pageBuilder: (context, animation, secondaryAnimation) {
        return EventDialog(
          event: event,
          allEvents: events,
          people: people,
          color: color,
          emoji: emoji,
          isEnglish: isEnglish,
          onEventSelected: (Map<String, dynamic> selectedEvent) {
            Navigator.pop(context); // 关闭当前弹窗
            _showEventDialog(selectedEvent); // 打开新弹窗
          },
        );
      },
      
      // (新) 动画构建器 (从右侧滑入)
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Align(
          alignment: Alignment.centerRight, // <-- 关键：对齐到右侧
          child: SlideTransition(
            // <-- 关键：从右侧 (1.0) 滑动到屏幕内 (0.0)
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0), 
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
            child: child, // 'child' 就是上面 pageBuilder 返回的 EventDialog
          ),
        );
      },
    ).then((_) {
      // 3. (逻辑不变) 当弹窗关闭时，清除焦点
      setState(() {
        _focusedEventId = null;
      });
    });
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

// ========== 详情侧边栏 ==========

  // (新) 详情面板 Widget (代替 EventDialog)
  Widget _buildDetailsPanel(BuildContext context, Map<String, dynamic> event, bool isEnglish, 
    double panelWidth, Function(DragUpdateDetails) onPanelDrag) {
    
    // 1. (从 _showEventDialog 复制) 获取颜色
    String primaryField = _getFieldsFromEvent(event).first;
    final color = getFieldColor(primaryField);
    final emoji = getFieldEmoji(primaryField);

    // 2. (从 EventDialog.build 复制) 解析数据
    final EventData data = EventData.fromJson(event, isEnglish, events, people);
    final List<String> personIds = data.personIds;

    // 3. (新) 创建一个 DefaultTabController
    return DefaultTabController(
      length: 4,
      child: Container(
        width: panelWidth, // <-- (修改) 使用动态宽度
        height: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(-5, 0),
            )
          ],
        ),
        // --- (修改) child 现在是一个 Row ---
        child: Row(
          children: [
            // --- (新增) 拖动手柄 ---
            GestureDetector(
              onHorizontalDragUpdate: onPanelDrag, // <-- 使用回调
              child: Container(
                width: 8, // 手柄宽度
                height: double.infinity,
                color: Colors.grey.shade200, // 背景色
                child: Center(
                  child: Icon(
                    Icons.drag_indicator, 
                    size: 16, 
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            // --- (新增结束) ---

            // --- (旧的 Column 现在在 Expanded 内部) ---
            Expanded(
              child: Column(
                children: [
                  _buildDetailsPanelHeader(context, data, color, emoji),
                  _buildDetailsPanelTabBar(color, isEnglish),
                  Expanded(
                    child: TabBarView(
                      children: [
                        OverviewTab(
                          data: data, 
                          color: color, 
                          isEnglish: isEnglish,
                          personIds: personIds,
                          allEvents: events,
                          people: people,
                          onEventSelected: (Map<String, dynamic> selectedEvent) {
                            setState(() {
                              _focusedEvent = selectedEvent;
                              _panelWidth = 450.0; // (可选) 切换事件时重置宽度
                            });
                          },
                        ),
                        ScienceTab(data: data, color: color, isEnglish: isEnglish),
                        ImpactTab(
                          data: data, 
                          color: color, 
                          isEnglish: isEnglish,
                          allEvents: events,
                          onEventSelected: (Map<String, dynamic> selectedEvent) {
                            setState(() {
                              _focusedEvent = selectedEvent;
                              _panelWidth = 450.0; // (可选) 切换事件时重置宽度
                            });
                          },
                          // --- (新增属性) ---
                          currentFocusMode: _currentFocusMode,
                          focalEventIds: _focalEventIds,
                          focusedEvent: _focusedEvent!,
                          // --- (新增结束) ---              
// --- (新增这两个属性) ---
                          people: people,
                          selectedYear: selectedYear,
                          // --- (新增结束) ---                                      
                        ),
                        QuizTab(data: data, color: color, isEnglish: isEnglish),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // --- (修改结束) ---
          ],
        ),
      ),
    );
  }

// ... 在 _MapScreenState 内部 ...

// (新 - 从 EventDialog._buildHeader 复制而来)
// ... 在 _MapScreenState 内部 ...

  Widget _buildDetailsPanelHeader(BuildContext context, EventData data, Color color, String emoji) {
    final bool isEnglish = Localizations.localeOf(context).languageCode == 'en';

    // --- (新增) 导航逻辑准备 ---
    bool showNav = _currentFocusMode == FocusMode.evolution;
    Map<String, dynamic>? prevEvent;
    Map<String, dynamic>? nextEvent;

    if (showNav) {
      // 1. 获取当前故事的所有事件并排序
      List<Map<String, dynamic>> storyEvents = events
          .where((e) => _focalEventIds.contains(e['id']))
          .toList();
      storyEvents.sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));

      // 2. 找到当前事件的索引
      int currentIndex = storyEvents.indexWhere((e) => e['id'] == data.id);

      // 3. 确定前后事件
      if (currentIndex > 0) prevEvent = storyEvents[currentIndex - 1];
      if (currentIndex < storyEvents.length - 1) nextEvent = storyEvents[currentIndex + 1];
    }
    // --- (准备结束) ---

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color],
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${data.year} · ${data.city}',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),

          // --- (新增) 导航按钮组 ---
          if (showNav) ...[
            // 上一个
            IconButton(
              icon: Icon(Icons.chevron_left, size: 30),
              color: prevEvent != null ? Colors.white : Colors.white30, // 禁用态变暗
              tooltip: isEnglish ? 'Previous Event' : '上一个事件',
              onPressed: prevEvent == null ? null : () {
                setState(() {
                  _focusedEvent = prevEvent;
                  // 可选：同时把时间轴移过去，让演化图高亮状态跟随
                  selectedYear = (prevEvent!['year'] as int).toDouble();
                });
              },
            ),
            
            // 下一个
            IconButton(
              icon: Icon(Icons.chevron_right, size: 30),
              color: nextEvent != null ? Colors.white : Colors.white30,
              tooltip: isEnglish ? 'Next Event' : '下一个事件',
              onPressed: nextEvent == null ? null : () {
                setState(() {
                  _focusedEvent = nextEvent;
                  // 可选：同时把时间轴移过去
                  selectedYear = (nextEvent!['year'] as int).toDouble();
                });
              },
            ),
            // 分隔线
            Container(height: 24, width: 1, color: Colors.white30, margin: EdgeInsets.symmetric(horizontal: 4)),
          ],
          // --- (新增结束) ---
          
          // 模式切换按钮 (保持不变，稍微精简显示逻辑)
          if (_currentFocusMode == FocusMode.simple)
            IconButton(
              icon: Icon(Icons.auto_graph_outlined),
              color: Colors.white,
              tooltip: isEnglish ? 'Show Full Evolution Path' : '显示完整演化路径',
              onPressed: () async {
                 // ... (您现有的 complex onPressed 逻辑，保持不变) ...
                 // ... 为了节省篇幅，这里不重复粘贴，请保留您上一步写好的完整逻辑 ...
                 // ... (查找 storyline_ids, 弹窗选择等) ...
                 
                 // 友情提示：如果您还没保存上一步的代码，需要我再次提供吗？
                 // 假设您这里已经有了那个 async 逻辑。
                 _handleEvolutionButtonPress(); // <-- 建议把那大段逻辑抽离成一个函数
              },
            )
          else if (_currentFocusMode == FocusMode.evolution)
            IconButton(
              icon: Icon(Icons.filter_center_focus),
              color: Colors.white,
              tooltip: isEnglish ? 'Show Simple View' : '显示简单视图',
              onPressed: () {
                // (降级逻辑保持不变)
                Set<String> newFocalIds = {};
                newFocalIds.add(_focusedEvent!['id']);
                var chain = _focusedEvent!['influence_chain'];
                if (chain != null && chain is Map) {
                   // ... (现有逻辑) ...
                   var influencedBy = chain['influenced_by'] as List?;
                   if (influencedBy != null) newFocalIds.addAll(influencedBy.map((e) => e['id'] as String));
                   var influenced = chain['influenced'] as List?;
                   if (influenced != null) newFocalIds.addAll(influenced.map((e) => e['id'] as String));
                }
                setState(() {
                  _focalEventIds = newFocalIds;
                  _currentFocusMode = FocusMode.simple;
                  _panelWidth = 450.0; // 恢复窄宽度
                });
              },
            ),

          // 关闭按钮
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () {
              setState(() {
                _focusedEvent = null; 
                _focalEventIds = {}; 
                _currentFocusMode = FocusMode.none;
              });
            },
          ),
        ],
      ),
    );
  }

  // (可选) 为了代码整洁，建议把刚才那个很长的演化按钮逻辑抽离出来
  Future<void> _handleEvolutionButtonPress() async {
    final event = _focusedEvent!;
    List<String> storyIds = [];
    var storyData = event['storyline_ids'];
    
    if (storyData is List && storyData.isNotEmpty) {
      storyIds = List<String>.from(storyData);
    } else {
      var oldStoryId = event['storyline_id'];
      if (oldStoryId is String && oldStoryId.isNotEmpty) {
        storyIds = [oldStoryId];
      }
    }

    String? selectedStoryId;

    if (storyIds.isEmpty) {
      setState(() {
        _focalEventIds = _getRecursiveEventChain(event);
        _currentFocusMode = FocusMode.evolution;
      });
      return;
    } else if (storyIds.length == 1) {
      selectedStoryId = storyIds.first;
    } else {
      selectedStoryId = await _showStorylineSelectionDialog(storyIds);
      if (selectedStoryId == null) return;
    }

    if (storylines.containsKey(selectedStoryId)) {
      final List<String> eventIds = List<String>.from(storylines[selectedStoryId!]['events']);
      setState(() {
        _focalEventIds = eventIds.toSet();
        _currentFocusMode = FocusMode.evolution;
      });
    } else {
       setState(() {
        _focalEventIds = _getRecursiveEventChain(event);
        _currentFocusMode = FocusMode.evolution;
      });
    }
  }

  // (新 - 从 EventDialog._buildTabBar 复制而来)
// (新 - 从 EventDialog._buildTabBar 复制而来)
  Widget _buildDetailsPanelTabBar(Color color, bool isEnglish) {
    // final l10n = AppLocalizations.of(context); // <-- (错误) 我们不需要这一行

    return Container(
      color: color.withOpacity(0.1),
      child: TabBar(
        labelColor: color,
        unselectedLabelColor: Colors.grey,
        indicatorColor: color,
        tabs: [
          // --- (修复) 恢复为使用 'isEnglish' 的硬编码字符串 ---
          Tab(icon: Icon(Icons.info_outline, size: 20), text: isEnglish ? 'Overview' : '概览'),
          Tab(icon: Icon(Icons.science, size: 20), text: isEnglish ? 'Science' : '科学'),
          Tab(icon: Icon(Icons.account_tree, size: 20), text: isEnglish ? 'Impact' : '影响'),
          Tab(icon: Icon(Icons.quiz, size: 20), text: isEnglish ? 'Quiz' : '测验'),
        ],
      ),
    );
  }

// (新) 为插件构建【单个】事件标记
  Marker _buildSingleEventMarker(Map<String, dynamic> event) {
    String field = _getFieldsFromEvent(event).first;
    Color color = getFieldColor(field);
    String emoji = getFieldEmoji(field);

    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    String title = isEnglish && event['title_en'] != null
        ? event['title_en']
        : event['title'];

    // --- (新增) 获取人名 (支持多人) ---
    String? personName;
    
    // 解析 personIds (兼容旧的 personId)
    List<String> personIdList = [];
    var pIds = event['personIds']; // 新的 "personIds" 字段 (数组)
    var pId = event['personId'];  // 旧的 "personId" 字段 (字符串)
    if (pIds is List) {
      personIdList = List<String>.from(pIds);
    } else if (pId is String) {
      personIdList = [pId];
    }
    
    if (personIdList.isNotEmpty) {
      List<String> names = [];
      for (var pid in personIdList) {
        if (people.containsKey(pid)) {
          final personData = people[pid];
          String fullName = isEnglish && personData['name_en'] != null
              ? personData['name_en']
              : personData['name'];
          // 只取姓氏
          String lastName = fullName.split(' ').last;
          // 对于中文名，不需要拆分
          if (!isEnglish && fullName.length > 2) {
            lastName = fullName;
          } else if (!isEnglish) {
            lastName = fullName;
          }
          names.add(lastName);
        }
      }
      // 用 " & " 或 "、" 连接
      personName = names.join(isEnglish ? ' & ' : '、');
    }
    // --- (新增结束) ---
    
    return Marker(
      point: LatLng(event['lat'], event['lng']),
      width: 180,  
      height: 50,
      alignment: Alignment.topCenter, 
      
      child: Tooltip(
        message: '$title\n$personName · ${event['year']}', // Tooltip 也更新
        
        child: GestureDetector(
          onTap: () {
            // --- (新) 在点击时计算所有相关的ID ---
            Set<String> newFocalIds = {};
            newFocalIds.add(event['id']); // 1. 添加被点击的事件本身
            
            var chain = event['influence_chain'];
            if (chain != null && chain is Map) {
              // 2. 添加所有 "influenced_by" 的事件
              var influencedByList = chain['influenced_by']; //
              if (influencedByList != null && influencedByList is List) {
                for (var item in influencedByList) {
                  if (item['id'] != null) newFocalIds.add(item['id']);
                }
              }
              // 3. 添加所有 "influenced" 的事件
              var influencedList = chain['influenced']; //
              if (influencedList != null && influencedList is List) {
                for (var item in influencedList) {
                  if (item['id'] != null) newFocalIds.add(item['id']);
                }
              }
            }
            // --- (新逻辑结束) ---

            setState(() {
              _focusedEvent = event;
              _focalEventIds = newFocalIds; // <-- (新) 设置这个 Set 状态
              _currentFocusMode = FocusMode.simple;
              _panelWidth = 450.0; 
            });
          },

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Emoji Circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, spreadRadius: 1), // <-- 修改
                  ],
                ),
                child: Center(
                  child: Text(emoji, style: TextStyle(fontSize: 22)),
                ),
              ),
              SizedBox(width: 8),

              // 2. 文本框 (标题 + 人名/年份)
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.7), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3, offset: Offset(0, 1)), // <-- 修改
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      // 第一行：标题
                      Text(
                        title, 
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // --- (修改) 第二行：人名 + 年份 ---
                      Text(
                        (personName != null) 
                            ? '$personName · ${event['year']}' // "Newton · 1666"
                            : '${event['year']}', // "1666" (作为备用)
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis, // 避免名字太长时溢出
                      ),
                      // --- (修改结束) ---
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

  // (新) 为插件构建【聚类】标记 (注意：它返回 Widget，而不是 Marker)
  Widget _buildClusterMarkerWidget(int count, Color color) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 12, spreadRadius: 3),
        ],
      ),
      child: Center(
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }  

  // ========== (新增) 故事线进度栏 ==========
 // ========== (新增) 故事线进度栏 (已修复溢出问题) ==========
  Widget _buildStoryTimelineRail() {
    if (_currentFocusMode != FocusMode.evolution || _focalEventIds.isEmpty) {
      return SizedBox.shrink();
    }

    List<Map<String, dynamic>> storyEvents = events
        .where((e) => _focalEventIds.contains(e['id']))
        .toList();
    storyEvents.sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));
    
    String currentId = _focusedEvent?['id'] ?? '';

    return Positioned(
      bottom: 190, 
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          height: 90, // <--- 修改 1: 增加高度 (从 85 改为 90)
          width: MediaQuery.of(context).size.width * 0.95, 
          constraints: BoxConstraints(maxWidth: 1000), 
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7), 
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: storyEvents.length,
            itemBuilder: (context, index) {
              final event = storyEvents[index];
              bool isActive = event['id'] == currentId;
              bool isPast = (event['year'] as int) <= selectedYear;
              
              String primaryField = _getFieldsFromEvent(event).first;
              Color nodeColor = getFieldColor(primaryField);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _focusedEvent = event;
                    selectedYear = (event['year'] as int).toDouble();
                  });
                },
                child: Container(
                  width: 100, 
                  color: Colors.transparent, 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 1. 年份
                      Text(
                        '${event['year']}',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      
                      SizedBox(height: 4), // <--- 修改 2: 减小间距 (从 8 改为 4)
                      
                      // 2. 点和线
                      Container(
                        height: 20,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: index == 0 
                                        ? Colors.transparent 
                                        : (isPast ? nodeColor.withOpacity(0.8) : Colors.grey.withOpacity(0.5)),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: index == storyEvents.length - 1 
                                        ? Colors.transparent 
                                        : (isPast && currentId != event['id'] ? nodeColor.withOpacity(0.8) : Colors.grey.withOpacity(0.5)),
                                  ),
                                ),
                              ],
                            ),
                            AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              width: isActive ? 16 : 10,
                              height: isActive ? 16 : 10,
                              decoration: BoxDecoration(
                                color: isPast ? nodeColor : Colors.grey,
                                shape: BoxShape.circle,
                                border: isActive ? Border.all(color: Colors.white, width: 2) : null,
                                boxShadow: isActive ? [
                                  BoxShadow(color: nodeColor.withOpacity(0.8), blurRadius: 8, spreadRadius: 2)
                                ] : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 4), // <--- 修改 3: 减小间距 (从 8 改为 4)
                      
                      // 3. 标题
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'en' 
                              ? (event['title_en'] ?? event['title']) 
                              : event['title'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

void _showNarrativeDialog(Map<String, dynamic> story) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    
    // 1. 获取数据
    var intro = story['narrative_intro'];
    if (intro == null) return; // 如果没有简介，直接返回

    String title = isEnglish && story['title_en'] != null ? story['title_en'] : story['title_zh'];
    String content = isEnglish && intro['text_en'] != null ? intro['text_en'] : intro['text_zh'];
    String question = isEnglish && intro['core_question_en'] != null ? intro['core_question_en'] : intro['core_question_zh'];

    // 2. 显示弹窗
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Narrative",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return NarrativeCard(
          title: title,
          content: content,
          question: question,
          onClose: () => Navigator.pop(context),
          onLinkTap: (eventId) {
            // 查找事件
            var targetEvent = events.firstWhere(
              (e) => e['id'] == eventId,
              orElse: () => {},
            );
            
            if (targetEvent.isNotEmpty) {
              Navigator.pop(context); // 关闭弹窗
              
              // 跳转逻辑
              setState(() {
                _focusedEvent = targetEvent;
                selectedYear = (targetEvent['year'] as int).toDouble();
                _currentFocusMode = FocusMode.simple; // 或者 evolution，看您喜好
                _panelWidth = 450.0;
                
                // 如果在演化模式下，可能还需要设置 _focalEventIds
                // 这里简单起见，我们先跳过去，用户可以通过侧边栏按钮再次进入演化视图
              });
            } else {
              print("Event not found: $eventId");
            }
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack).value,
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }  

}

// ============================================
// 事件数据模型
// ============================================
// <-- MODIFIED EventData -->
class EventData {
  final String id; // <-- Added
  final List<String> personIds; // <-- Added
  final String title;
  final String city;
  final int year;
  final String primaryField; // <-- 新增 (例如 "物理学")
  final List<String> fields; // <-- 新增 (例如 ["Physics", "Mathematics"])
  
  // 媒体
  final String? eventImage;
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
    required this.id, // <-- Added
    required this.personIds, // <-- Added
    required this.title,
    required this.city,
    required this.year,
    required this.primaryField, // <-- 新增
    required this.fields,     // <-- 新增
    this.eventImage,
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
    Map<String, dynamic> allPeople,
  ) {
    // 基本信息
    String title = isEnglish && json['title_en'] != null
        ? json['title_en']
        : json['title'];
    String city = '';
    var cityEn = json['city_en'];
    var cityZh = json['city'];
    if (isEnglish && cityEn != null && cityEn is String) {
      city = cityEn;
    } else if (cityZh != null && cityZh is String) {
      city = cityZh;
    }

  // --- 新的学科解析逻辑 ---

    // 1. 获取中文基础学科列表 (用于 key)
    List<String> baseFields;
    var fieldData = json['field']; // 始终获取中文 key
    if (fieldData == null) {
      baseFields = ['综合'];
    } else if (fieldData is List) {
      baseFields = List<String>.from(fieldData.isNotEmpty ? fieldData : ['综合']);
    } else if (fieldData is String) {
      baseFields = [fieldData]; // 兼容旧格式
    } else {
      baseFields = ['综合'];
    }
    // "primaryField" 始终是中文列表的第一个
    String primaryField = baseFields.first;

    // 2. 获取已翻译的学科列表 (用于 UI 显示)
    List<String> translatedFields;
    if (isEnglish) {
      var enData = json['field_en'];
      if (enData is List) {
        translatedFields = List<String>.from(enData.isNotEmpty ? enData : baseFields);
      } else if (enData is String) {
        translatedFields = [enData]; // 兼容旧格式
      } else {
        translatedFields = baseFields; // 回退到中文
      }
    } else {
      translatedFields = baseFields; // 如果是中文，直接使用中文列表
    }
    // --- 结束新逻辑 ---
    
    // ... (All other parsing logic remains the same) ...
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
// 简单解释
    SimpleExplanation? simpleExplanation;
    if (json['simple_explanation'] != null) {
      var se = json['simple_explanation'];
      if (se is Map) {
        
        // --- 新增：解析 simple_explanation 内部的视频 ---
        VideoData? simpleVideo;
        if (se['video'] != null) {
          var v = se['video'];
          simpleVideo = VideoData(
            url: v['url'],
            title: isEnglish && v['title_en'] != null ? v['title_en'] : v['title'],
            duration: v['duration'],
          );
        }
        // --- 新增结束 ---

        simpleExplanation = SimpleExplanation(
          text: isEnglish && se['text_en'] != null ? se['text_en'] : (se['text'] ?? ''),
          diagram: se['diagram'],
          video: simpleVideo, // <-- 传入视频数据
        );
      } else if (se is String) {
        simpleExplanation = SimpleExplanation(text: se, diagram: null, video: null);
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
          String? personName; // <-- 新增

          if (sourceEvent.isNotEmpty) {
            // 获取事件标题
            eventTitle = isEnglish && sourceEvent['title_en'] != null
                ? sourceEvent['title_en']
                : sourceEvent['title'];

            // --- (修改) 获取人物姓名 (支持多人) ---
            List<String> personIdList = [];
            var pIds = sourceEvent['personIds']; // 新的
            var pId = sourceEvent['personId'];  // 旧的
            if (pIds is List) {
              personIdList = List<String>.from(pIds);
            } else if (pId is String) {
              personIdList = [pId];
            }

            if (personIdList.isNotEmpty) {
              List<String> names = [];
              for (var pid in personIdList) {
                if (allPeople.containsKey(pid)) {
                  var personData = allPeople[pid];
                  // 这里我们用全名，而不是像地图标记那样只用姓氏
                  names.add(isEnglish && personData['name_en'] != null 
                      ? personData['name_en'] 
                      : personData['name']);
                }
              }
              personName = names.join(isEnglish ? ' & ' : '、');
            }
            // --- (修改结束) ---
          }

          return InfluenceItem(
            id: item['id'],
            personName: personName, // <-- 新增
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
          String? personName; // <-- 新增

          if (targetEvent.isNotEmpty) {
            // 获取事件标题
            eventTitle = isEnglish && targetEvent['title_en'] != null
                ? targetEvent['title_en']
                : targetEvent['title'];
            
            // --- (修改) 获取人物姓名 (支持多人) ---
            List<String> personIdList = [];
            var pIds = targetEvent['personIds']; // 新的
            var pId = targetEvent['personId'];  // 旧的
            if (pIds is List) {
              personIdList = List<String>.from(pIds);
            } else if (pId is String) {
              personIdList = [pId];
            }

            if (personIdList.isNotEmpty) {
              List<String> names = [];
              for (var pid in personIdList) {
                if (allPeople.containsKey(pid)) {
                  var personData = allPeople[pid];
                  // 这里我们用全名，而不是像地图标记那样只用姓氏
                  names.add(isEnglish && personData['name_en'] != null 
                      ? personData['name_en'] 
                      : personData['name']);
                }
              }
              personName = names.join(isEnglish ? ' & ' : '、');
            }
            // --- (修改结束) ---
          }
          
          return InfluenceItem(
            id: item['id'],
            personName: personName, // <-- 新增
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
        legacyText: null,
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
    
    // --- (新) 解析 personIds (兼容旧的 personId) ---
    List<String> personIdList = [];
    var pIds = json['personIds']; // 新的 "personIds" 字段 (数组)
    var pId = json['personId'];  // 旧的 "personId" 字段 (字符串)

    if (pIds is List) {
      personIdList = List<String>.from(pIds);
    } else if (pId is String) {
      personIdList = [pId]; // 将旧的字符串包装成列表
    }
    // --- (新逻辑结束) ---

    return EventData(
      id: json['id'] as String, // <-- Added
      personIds: personIdList, // <-- Added
      title: title,
      city: city,
      year: json['year'],
      primaryField: primaryField, // <-- 新增
      fields: translatedFields, // <-- 新增
      eventImage: media?['event_image'],
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
// <-- END MODIFIED EventData -->


// ============================================
// 数据模型类
// ============================================
// (All classes: VideoData, SummaryData, StoryData, FunFact, 
// SimpleExplanation, PrincipleData, KeyPoint, Application,
// ExperimentData, ImpactData, ImpactStat, InfluenceChain,
// InfluenceItem, QuizData ... remain unchanged)
// ...
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
  final VideoData? video; // <-- 新增
  
  SimpleExplanation({required this.text, this.diagram, this.video}); // <-- 更新构造函数
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
  final String? personName; // <-- 新增
  final String title;
  final String contribution;
  
  InfluenceItem({
    required this.id, 
    this.personName, // <-- 新增
    required this.title, 
    required this.contribution,
  });
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
// <-- MODIFIED EventDialog -->
class EventDialog extends StatelessWidget {
  // final EventData data; // <-- Removed
  final Map<String, dynamic> event; // <-- Added
  final List<Map<String, dynamic>> allEvents; // <-- Added
  final Map<String, dynamic> people; // <-- Added
  final Color color;
  final String emoji;
  final bool isEnglish;
  final Function(Map<String, dynamic>) onEventSelected; // <-- Added

  const EventDialog({
    // required this.data, // <-- Removed
    required this.event, // <-- Added
    required this.allEvents, // <-- Added
    required this.people, // <-- Added
    required this.color,
    required this.emoji,
    required this.isEnglish,
    required this.onEventSelected, // <-- Added
  });

  @override
  Widget build(BuildContext context) {
    // <-- Parse data here
    final EventData data = EventData.fromJson(event, isEnglish, allEvents, people);
    //final String? personId = event['personId'];
    
    return DefaultTabController(
      length: 4,
      child: Dialog(
        child: Container(
          width: 600,
          height: 700,
          child: Column(
            children: [
              _buildHeader(context, data), // <-- Pass data
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  children: [
                    OverviewTab( // <-- Pass new props
                      data: data, 
                      color: color, 
                      isEnglish: isEnglish,
                      personIds: data.personIds,
                      allEvents: allEvents,
                      people: people,
                      onEventSelected: onEventSelected,
                    ),
                    ScienceTab(data: data, color: color, isEnglish: isEnglish),
                    ImpactTab(
                      data: data, 
                      color: color, 
                      isEnglish: isEnglish,
                      allEvents: allEvents,         // <-- 新增
                      onEventSelected: onEventSelected, // <-- 新增
                      // --- (ADD THESE 3 LINES) ---
                      currentFocusMode: FocusMode.simple, // Default to simple mode
                      focalEventIds: { data.id },       // Default to just this event
                      focusedEvent: event,              // Pass the event
                      people: people,
                      selectedYear: data.year.toDouble(),                      
                      // --- (END ADD) ---                      
                    ),
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

  Widget _buildHeader(BuildContext context, EventData data) { // <-- Receive data
    // 获取人物名字（支持多人）
    String? personNames;
    if (data.personIds.isNotEmpty) {
      List<String> names = [];
      for (var pid in data.personIds) {
        if (people.containsKey(pid)) {
          final personData = people[pid];
          String fullName = isEnglish && personData['name_en'] != null
              ? personData['name_en']
              : personData['name'];
          names.add(fullName);
        }
      }
      if (names.isNotEmpty) {
        personNames = names.join(isEnglish ? ' & ' : '、');
      }
    }
    
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
                  data.title, // <-- Use data
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  personNames != null
                      ? '${personNames} · ${data.year} · ${data.city}'
                      : '${data.year} · ${data.city}',
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
// <-- END MODIFIED EventDialog -->

// ============================================
// 概览标签页
// ============================================
// <-- MODIFIED OverviewTab -->
class OverviewTab extends StatelessWidget {
  final EventData data;
  final Color color;
  final bool isEnglish;
  // <-- Added -->
  final List<String> personIds;
  final List<Map<String, dynamic>> allEvents;
  final Map<String, dynamic> people;
  final Function(Map<String, dynamic>) onEventSelected;

  const OverviewTab({
    required this.data,
    required this.color,
    required this.isEnglish,
    // <-- Added -->
    required this.personIds,
    required this.allEvents,
    required this.people,
    required this.onEventSelected,
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
          if (data.eventImage != null) ...[
            EventImage(imageUrl: data.eventImage!, color: color),
            SizedBox(height: 16),
          ],

          // 如果都没有，显示渐变色块
          if (data.video == null && data.eventImage == null) ...[
            GradientHeader(
              field: data.fields.join(' / '), // <-- (例如 "Physics / Mathematics")
              color: color, 
              emoji: _getEmoji(data.primaryField) // <-- (例如 "物理学")
            ),
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

          // <-- START NEW BLOCK -->
          if (personIds.isNotEmpty) ...[ // <-- 修改
            SizedBox(height: 20),
            // 遍历所有 personId 并为每个人创建一个时间线
            ...personIds.map((pid) => Padding( // <-- 新增
                  padding: const EdgeInsets.only(bottom: 16.0), // <-- 新增
                  child: PersonTimelineWidget(
                    personId: pid, // <-- 修改
                    currentEventId: data.id,
                    allEvents: allEvents,
                    people: people,
                    onEventSelected: onEventSelected,
                    color: color,
                    isEnglish: isEnglish,
                  ),
                )), // <-- 新增
          ],
          // <-- END MODIFIED BLOCK -->
        ],
      ),
    );
  }

  String _getEmoji(String baseField) { // <-- 接收一个参数
    final emojis = {
      'Physics': '⚛️', 'Chemistry': '🧪', 'Biology': '🔬',
      'Mathematics': '📐', 'Astronomy': '🔭', 'Medicine': '💊',
      'Computer Science': '💻', 'Space': '🚀', 'Comprehensive': '📚',
      '物理学': '⚛️', '化学': '🧪', '生物学': '🔬',
      '数学': '📐', '天文学': '🔭', '医学': '💊',
      '计算机': '💻', '航天': '🚀', '综合': '📚',
    };
    return emojis[baseField] ?? '📚';
  }
}
// <-- END MODIFIED OverviewTab -->


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

          // 简单解释
          if (data.simpleExplanation != null) ...[
            SizedBox(height: 16),
            SimpleExplanationCard(
              explanation: data.simpleExplanation!,
              color: color,
              isEnglish: isEnglish,
            ),
          ],          
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
// ============================================
// 影响标签页
// ============================================
class ImpactTab extends StatelessWidget {
  final EventData data;
  final Color color;
  final bool isEnglish;
  final List<Map<String, dynamic>> allEvents;
  final Function(Map<String, dynamic>) onEventSelected;
  
  // 这些参数虽然现在不用了，但保留着也不会报错，
  // 或者您可以删掉它们（同时也得去 EventDialog 和 _buildDetailsPanel 删掉传入的参数）
  // 为了改动最小，我们先保留接收，只是不用。
  final FocusMode currentFocusMode;
  final Set<String> focalEventIds;
  final Map<String, dynamic> focusedEvent;
  final Map<String, dynamic> people;
  final double selectedYear;

  const ImpactTab({
    required this.data,
    required this.color,
    required this.isEnglish,
    required this.allEvents,
    required this.onEventSelected,
    required this.currentFocusMode,
    required this.focalEventIds,
    required this.focusedEvent,
    required this.people,
    required this.selectedYear,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 影响文字描述
          if (data.impact != null)
            ImpactCard(impact: data.impact!, color: color, isEnglish: isEnglish),
          
          // 2. (修改) 始终只显示原来的“影响关系网络”列表
          // 不再判断 FocusMode.evolution，也不再显示 EvolutionTreeView
          if (data.influenceChain != null) ...[
            SizedBox(height: 20),
            InfluenceNetworkCard(
              influenceChain: data.influenceChain!,
              color: color,
              isEnglish: isEnglish,
              allEvents: allEvents,
              onEventSelected: onEventSelected,
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
// (All components: VideoPlayer, eventImage, GradientHeader,
// SummaryCard, StoryCard, FunFactsSection, SimpleExplanationCard
// ... remain unchanged)
// ...
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

class EventImage extends StatelessWidget {
  final String imageUrl;
  final Color color;

  const EventImage({required this.imageUrl, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SmartImage(
        imageUrl: imageUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.contain,
        color: color,
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
            style: TextStyle(fontSize: 14, height: 1.6, fontWeight: FontWeight.w400),
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
            child: SmartImage(
              imageUrl: story.image!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.contain,
              color: color,
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
              Text(fact.icon, style: TextStyle(fontSize: 24)),
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

              // --- 新增：显示视频播放器 ---
              if (explanation.video != null) ...[
                VideoPlayer(
                  video: explanation.video!, 
                  color: Colors.blue[700]!, // 匹配卡片颜色
                  isEnglish: isEnglish
                ),
                SizedBox(height: 12),
              ],
              // --- 新增结束 ---
                        
          if (explanation.diagram != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SmartImage(
                imageUrl: explanation.diagram!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.contain,
                color: Colors.blue, // 匹配卡片颜色
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
// (All components: PrincipleSection, ApplicationsGrid,
// ExperimentCard, RelatedConceptsChips ... remain unchanged)
// ...
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
            child: SmartImage(
              imageUrl: principle.diagram!,
              width: double.infinity,
              fit: BoxFit.contain,
              color: color,
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
                      child: SmartImage(
                        imageUrl: app.image!,
                        height: 80,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        color: color,
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
              child: SmartImage(
                imageUrl: experiment.image!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                color: Colors.green, // 匹配卡片颜色
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
// (All components: ImpactCard, InfluenceNetworkCard
// ... remain unchanged)
// ...
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
  final List<Map<String, dynamic>> allEvents;         // <-- 新增
  final Function(Map<String, dynamic>) onEventSelected; // <-- 新增

  const InfluenceNetworkCard({
    required this.influenceChain,
    required this.color,
    required this.isEnglish,
    required this.allEvents,         // <-- 新增
    required this.onEventSelected, // <-- 新增
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
                  ...influenceChain.influencedBy!.map((item) {
                    // --- 新增：查找要跳转的事件 ---
                    final Map<String, dynamic> targetEvent = allEvents.firstWhere(
                      (e) => e['id'] == item.id,
                      orElse: () => {}, // 如果没找到，返回空 map
                    );
                    // --- 新增结束 ---

                    return InkWell( // <-- 用 InkWell 包装
                      onTap: (targetEvent.isNotEmpty && targetEvent['is_stub'] != true) ? () {
                        onEventSelected(targetEvent); // <-- 只有在不是 stub 时才调用
                      } : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4), // 增加点击区域
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.circle, color: Colors.orange, size: 8),
                            SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                // ... (RichText 内容保持不变)
                                text: TextSpan(
                                  style: TextStyle(fontSize: 13, color: Colors.black87),
                                  children: [
                                    if (item.personName != null && item.personName!.isNotEmpty) ...[
                                      TextSpan(
                                        text: '${item.personName} - ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[800], 
                                        ),
                                      ),
                                    ],
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
                      ),
                    );
                  }).toList(),
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
...influenceChain.influenced!.map((item) {
                    // --- 新增：查找要跳转的事件 ---
                    final Map<String, dynamic> targetEvent = allEvents.firstWhere(
                      (e) => e['id'] == item.id,
                      orElse: () => {}, // 如果没找到，返回空 map
                    );
                    // --- 新增结束 ---

                    return InkWell( // <-- 用 InkWell 包装
                      onTap: (targetEvent.isNotEmpty && targetEvent['is_stub'] != true) ? () {
                        onEventSelected(targetEvent); // <-- 只有在不是 stub 时才调用
                      } : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4), // 增加点击区域
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.circle, color: Colors.green, size: 8),
                            SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                // ... (RichText 内容保持不变)
                                text: TextSpan(
                                  style: TextStyle(fontSize: 13, color: Colors.black87),
                                  children: [
                                    if (item.personName != null && item.personName!.isNotEmpty) ...[
                                      TextSpan(
                                        text: '${item.personName} - ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[800], 
                                        ),
                                      ),
                                    ],
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
                      ),
                    );
                  }).toList(),
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
// (QuizWidget remains unchanged)
// ...
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
            child: SmartImage(
              imageUrl: widget.quiz.image!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              color: widget.color,
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
// (EmptyState remains unchanged)
// ...
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

// ============================================
// 人物时间线组件
// ============================================
// <-- NEW WIDGET -->
class PersonTimelineWidget extends StatelessWidget {
  final String personId;
  final String currentEventId;
  final List<Map<String, dynamic>> allEvents;
  final Map<String, dynamic> people;
  final Function(Map<String, dynamic>) onEventSelected;
  final Color color;
  final bool isEnglish;

  const PersonTimelineWidget({
    required this.personId,
    required this.currentEventId,
    required this.allEvents,
    required this.people,
    required this.onEventSelected,
    required this.color,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    // 1. 获取人物信息
    final personInfo = people[personId];
    if (personInfo == null) return SizedBox.shrink();

    final String name = isEnglish && personInfo['name_en'] != null 
        ? personInfo['name_en'] 
        : personInfo['name'];
    final String? portrait = personInfo['portrait'];
    
    // 2. 获取并排序该人物的所有事件
    final List<String> eventIds = List<String>.from(personInfo['events']);
    final List<Map<String, dynamic>> personEvents = allEvents
        .where((event) => eventIds.contains(event['id']))
        .toList();
    
    // 按年份排序
    personEvents.sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));

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
              if (portrait != null)
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(portrait),
                  onBackgroundImageError: (e, s) => Icon(Icons.person, color: color, size: 20),
                )
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withOpacity(0.2),
                  child: Icon(Icons.person, color: color, size: 24),
                ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEnglish ? "$name's Journey" : "$name 的足迹",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

        SizedBox(height: 10),
        Builder(
          builder: (context) {
            // 1. 从 personInfo 中解析 bio
            final String? bio = isEnglish && personInfo['bio_short_en'] != null
                ? personInfo['bio_short_en']
                : personInfo['bio_short'];

            // 2. 如果 bio 存在，就显示它
            if (bio != null && bio.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0), // 在时间线列表前增加一点间距
                child: Text(
                  bio,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
            return SizedBox.shrink(); // 如果没有bio，则不显示
          }
        ),

          SizedBox(height: 12),
          // 3. 构建时间线
          ...personEvents.map((event) {
            final String title = isEnglish && event['title_en'] != null
                ? event['title_en']
                : event['title'];
            String city = '';
            var cityEn = event['city_en'];
            var cityZh = event['city'];
            if (isEnglish && cityEn != null && cityEn is String) {
              city = cityEn;
            } else if (cityZh != null && cityZh is String) {
              city = cityZh;
            }
            final int year = event['year'];
            final bool isCurrent = event['id'] == currentEventId;

            return Opacity(
              opacity: isCurrent ? 1.0 : 0.7,
              child: Card(
                margin: EdgeInsets.only(bottom: 8),
                color: isCurrent ? color.withOpacity(0.2) : Colors.white,
                elevation: isCurrent ? 0 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isCurrent ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '$year · $city',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Icon(
                    isCurrent ? Icons.circle : Icons.arrow_forward_ios, 
                    size: 16, 
                    color: color
                  ),
                  onTap: isCurrent ? null : () {
                    onEventSelected(event);
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================
// 智能图像 (Smart Image)
// 自动选择 Asset 或 Network 渲染器 (SVG 或 PNG/JPG)
// ============================================
class SmartImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Color? color; // 用于占位符和错误图标的颜色

  const SmartImage({
    Key? key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 占位符
    final placeholder = Container(
      height: height,
      width: width,
      color: color?.withOpacity(0.1) ?? Colors.grey[200],
      child: Center(child: CircularProgressIndicator(color: color ?? Colors.blue)),
    );
    
    // 错误控件
    final errorWidget = Container(
      height: height,
      width: width,
      color: color?.withOpacity(0.1) ?? Colors.grey[200],
      child: Center(child: Icon(Icons.broken_image, color: color ?? Colors.grey, size: 48)),
    );

    // 检查是网络图片还是本地 asset
    bool isNetwork = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    bool isSvg = imageUrl.endsWith('.svg');

    if (isNetwork) {
      // --- 是网络图片 ---
      if (isSvg) {
        // 1. Network SVG
        return SvgPicture.network(
          imageUrl,
          height: height,
          width: width,
          fit: fit,
          placeholderBuilder: (BuildContext context) => placeholder,
          // 添加错误处理，抑制 <switch> 元素的警告
          allowDrawingOutsideViewBox: true,
          // 使用错误构建器来处理不支持的 SVG 元素
          semanticsLabel: '',
        );
      } else {
        // 2. Network Raster (PNG, JPG)
        return Image.network(
          imageUrl,
          height: height,
          width: width,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder;
          },
          errorBuilder: (context, error, stackTrace) => errorWidget,
        );
      }
    } else {
      // --- 是本地 Asset ---
      if (isSvg) {
        // 3. Local Asset SVG
        return SvgPicture.asset(
          imageUrl,
          height: height,
          width: width,
          fit: fit,
          placeholderBuilder: (BuildContext context) => placeholder,
          // 添加错误处理，抑制 <switch> 元素的警告
          allowDrawingOutsideViewBox: true,
          // 使用错误构建器来处理不支持的 SVG 元素
          semanticsLabel: '',
        );
      } else {
        // 4. Local Asset Raster (PNG, JPG)
        return Image.asset(
          imageUrl,
          height: height,
          width: width,
          fit: fit,
          // (Image.asset 没有 loadingBuilder, 但我们可以用 frameBuilder 做淡入)
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              child: child,
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 300),
            );
          },
          errorBuilder: (context, error, stackTrace) => errorWidget,
        );
      }
    }
  }
}
// END New Widget

// ============================================
// (新) 演化树状图 (完整版)
// ============================================

class EvolutionTreeView extends StatefulWidget {
  final Map<String, dynamic> focusedEvent;
  final Set<String> focalEventIds;
  final List<Map<String, dynamic>> allEvents;
  final Function(Map<String, dynamic>) onEventSelected;
  final Color color; // 这是 "focusedEvent" 的颜色
  final bool isEnglish;
  final Map<String, dynamic> people; // (新增) 完整的人物 map
  final double selectedYear;         // (新增) 当前时间轴年份

  const EvolutionTreeView({
    required this.focusedEvent,
    required this.focalEventIds,
    required this.allEvents,
    required this.onEventSelected,
    required this.color,
    required this.isEnglish,
    required this.people,      // (新增)
    required this.selectedYear, // (新增)
  });

  @override
  State<EvolutionTreeView> createState() => _EvolutionTreeViewState();
}

class _EvolutionTreeViewState extends State<EvolutionTreeView> {
  final Graph graph = Graph();
  late SugiyamaAlgorithm builder;
  final Map<String, Node> eventNodeMap = {};

  // --- (新增) ---
  final TransformationController _transformationController = TransformationController();
  // --- (新增结束) ---  

  // ====================
  // 辅助数据 (从 MapScreen 复制)
  // ====================
  final Map<String, Color> fieldColors = {
    '物理学': Colors.red, '化学': Colors.green, '生物学': Colors.blue, '数学': Colors.purple,
    '天文学': Colors.orange, '医学': Colors.pink, '计算机': Colors.cyan, '航天': Colors.indigo,
    '哲学': Colors.teal, '工程学': Colors.grey[700]!, '地理学': Colors.lightGreen, '综合': Colors.brown,
  };
  final Map<String, String> fieldEmojis = {
    '物理学': '⚛️', '化学': '🧪', '生物学': '🔬', '数学': '📐', '天文学': '🔭', '医学': '💊',
    '计算机': '💻', '航天': '🚀', '哲学': '🏛️', '工程学': '⚙️', '地理学': '🌍', '综合': '📚',
  };
  
  List<String> _getFieldsFromEvent(Map<String, dynamic> event) {
    var fieldData = event['field']; 
    if (fieldData == null) return ['综合'];
    if (fieldData is List) return List<String>.from(fieldData.isNotEmpty ? fieldData : ['综合']);
    if (fieldData is String) return [fieldData];
    return ['综合'];
  }
  Color getFieldColor(String field) => fieldColors[field] ?? Colors.grey;
  String getFieldEmoji(String field) => fieldEmojis[field] ?? '💡';
  
  // ====================
  // 生命周期
  // ====================

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  @override
  void didUpdateWidget(EvolutionTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果焦点事件、ID 集合或年份发生变化，重建图
    if (oldWidget.focusedEvent['id'] != widget.focusedEvent['id'] ||
        oldWidget.focalEventIds != widget.focalEventIds ||
        oldWidget.selectedYear != widget.selectedYear) {
      
      // 如果只是年份变化，我们不需要重建整个图，只需要重建节点
      // 但为了简单起见，我们先全部重建。
      // (优化：如果只是年份变了，可以只调用 setState() 来触发 _buildNodeWidget 重绘)
      
      // 暂时先全部重建
      _buildGraph();
    }
  }

  // ====================
  // 图构建逻辑
  // ====================
// ====================
  // 图构建逻辑 (已修改：强制线性故事模式)
  // ====================
  void _buildGraph() {
    graph.nodes.clear();
    graph.edges.clear();
    eventNodeMap.clear();

    // --- 步骤 1: 准备并排序数据 ---
    // 获取所有相关事件
    List<Map<String, dynamic>> sortedEvents = [];
    for (String eventId in widget.focalEventIds) {
      final event = widget.allEvents.firstWhere(
        (e) => e['id'] == eventId,
        orElse: () => {},
      );
      if (event.isNotEmpty) {
        sortedEvents.add(event);
      }
    }

    // 关键修复：强制按年份排序 (从小到大)
    sortedEvents.sort((a, b) {
      int yearA = a['year'] as int;
      int yearB = b['year'] as int;
      return yearA.compareTo(yearB);
    });

    // --- 步骤 2: 创建节点 (Nodes) ---
    for (var event in sortedEvents) {
      final node = Node(
        _buildNodeWidget(event), 
        key: ValueKey(event['id']), 
      );
      eventNodeMap[event['id']] = node;
      graph.addNode(node);
    }

    // --- 步骤 3: 创建连线 (Edges) ---
    // 逻辑判断：这是一条“故事线”还是“自动探索”？
    // 如果节点数量大于1，且我们通过故事模式进来，我们使用“强制线性”模式
    
    // 为了简化，我们这里采用混合策略：
    // 1. 始终画出“时间骨架” (A->B->C)，保证直线结构。
    // 2. (可选) 如果您想完全消除杂乱，就注释掉下面的 "B. 原始影响关系" 部分。
    
    // A. 强制时间主线 (The Backbone) - 这保证了从左到右的直线
    for (int i = 0; i < sortedEvents.length - 1; i++) {
      final currentEvent = sortedEvents[i];
      final nextEvent = sortedEvents[i + 1];
      
      final Node source = eventNodeMap[currentEvent['id']]!;
      final Node dest = eventNodeMap[nextEvent['id']]!;
      
      graph.addEdge(source, dest, paint: Paint()
        ..color = Colors.blue.withOpacity(0.8)
        ..strokeWidth = 3 // 主线稍微粗一点
        ..style = PaintingStyle.stroke
      );
    }

    /* // B. (可选) 原始影响关系 
    // 如果您觉得图太乱，请【注释掉】下面这段代码。
    // 注释掉后，图表将只显示上面创建的一条直线。
    
    for (var event in sortedEvents) {
      final sourceNode = eventNodeMap[event['id']];
      var chain = event['influence_chain'];
      
      if (sourceNode != null && chain != null && chain is Map) {
        var influencedList = chain['influenced'];
        if (influencedList != null && influencedList is List) {
          for (var item in influencedList) {
            String targetId = item['id'];
            // 只有当目标也在当前显示的列表中时，才画线
            if (eventNodeMap.containsKey(targetId)) {
              final targetNode = eventNodeMap[targetId]!;
              
              // 检查是否已经有骨架线连接了 (避免重复画线)
              bool hasEdge = graph.edges.any((e) => e.source == sourceNode && e.destination == targetNode);
              
              if (!hasEdge) {
                 // 画细一点的次要连线
                 graph.addEdge(sourceNode, targetNode, paint: Paint()
                  ..color = Colors.grey.withOpacity(0.4) // 灰色，淡一点
                  ..strokeWidth = 1
                  ..style = PaintingStyle.stroke
                );
              }
            }
          }
        }
      }
    }
    */ // <--- B 部分结束

    // --- 步骤 4: 配置算法 ---
    builder = SugiyamaAlgorithm(SugiyamaConfiguration()
      ..orientation = SugiyamaConfiguration.ORIENTATION_LEFT_RIGHT
      ..nodeSeparation = 40 // 增加节点间距
      ..levelSeparation = 80 // 增加层级间距
    );
  }

  // (新) 构建节点 UI (已升级)
  Widget _buildNodeWidget(Map<String, dynamic> event) {
    String title = widget.isEnglish && event['title_en'] != null
        ? event['title_en']
        : event['title'];
    
    // 状态
    final bool isFocused = event['id'] == widget.focusedEvent['id'];
    final bool isInThePast = event['year'] <= widget.selectedYear;

    // 学科信息
    String primaryField = _getFieldsFromEvent(event).first;
    Color nodeColor = getFieldColor(primaryField);
    String emoji = getFieldEmoji(primaryField);

    // 人物信息
    String? personName;
    List<String> personIdList = [];
    var pIds = event['personIds'];
    var pId = event['personId'];
    if (pIds is List) personIdList = List<String>.from(pIds);
    else if (pId is String) personIdList = [pId];

    if (personIdList.isNotEmpty) {
      List<String> names = [];
      for (var pid in personIdList) {
        if (widget.people.containsKey(pid)) {
          final personData = widget.people[pid];
          // 在图中使用姓氏 (或中文全名)，就像地图标记一样
          String fullName = widget.isEnglish && personData['name_en'] != null
              ? personData['name_en']
              : personData['name'];
          String lastName = fullName.split(' ').last;
          if (!widget.isEnglish) lastName = fullName;
          names.add(lastName);
        }
      }
      personName = names.join(widget.isEnglish ? ' & ' : '、');
    }

    return Opacity(
      opacity: isInThePast ? 1.0 : 0.4, // <-- 2. 时间轴联动
      child: GestureDetector(
        onTap: () {
          if (!isFocused) {
            widget.onEventSelected(event);
          }
        },
        child: Card(
          elevation: (isFocused && isInThePast) ? 6 : 2,
          color: (isFocused && isInThePast) ? nodeColor.withOpacity(0.2) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: (isFocused && isInThePast) ? nodeColor : nodeColor.withOpacity(0.7),
              width: (isFocused && isInThePast) ? 3 : 1.5,
            ),
          ),
          child: Container(
            width: 180, // 固定宽度
            padding: EdgeInsets.all(10), // 减小一点 padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // 确保卡片包裹内容
              children: [
                // 第一行：年份
                Text(
                  event['year'].toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: nodeColor,
                  ),
                ),
                SizedBox(height: 5),

                // 第二行：Emoji + 标题
                Text(
                  "$emoji $title",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: (isFocused && isInThePast) ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 5),

                // 第三行：人物
                if (personName != null)
                  Text(
                    personName,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ====================
  // 构建 (Build)
  // ====================
  @override
  Widget build(BuildContext context) {
    if (graph.nodes.isEmpty) {
      return Center(child: Text("Building evolution path..."));
    }

    return Container(
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
              Icon(Icons.auto_graph_outlined, color: Colors.blue[700], size: 24),
              SizedBox(width: 8),
              Expanded( // <-- (修改) 用 Expanded 包裹 Text
                child: Text(
                  widget.isEnglish ? 'Theoretical Evolution' : '理论演化路径',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ),
              // --- (新增) ---
              IconButton(
                icon: Icon(Icons.zoom_out_map, color: Colors.blue[700]),
                tooltip: widget.isEnglish ? 'Reset View' : '重置视图',
                onPressed: () {
                  setState(() {
                    _transformationController.value = Matrix4.identity(); // 重置为 1:1 缩放
                  });
                },
              ),
              // --- (新增结束) ---
            ],
          ),
          SizedBox(height: 16),
          Text(
            widget.isEnglish
              ? "This diagram shows the full intellectual lineage (past to future, left to right). The path dims based on the main timeline."
              : "此图表显示了完整的知识传承（从左到右，从过去到未来）。路径会根据主时间轴动态点亮。",
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          SizedBox(height: 16),

          // 渲染图
          Container(
            height: 600, // 给图一个固定的高度
            child: InteractiveViewer(
              transformationController: _transformationController,  // <-- (新增)                   
              constrained: false, // 允许无限平移/缩放
              boundaryMargin: EdgeInsets.all(100),
              minScale: 0.1,
              maxScale: 2.0,
              child: GraphView(
                graph: graph,
                algorithm: builder,
                paint: Paint()
                  ..color = Colors.blue.withOpacity(0.6) // (修改) 线的颜色
                  ..strokeWidth = 2
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  return node.data ?? SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// 叙事简报卡片 (支持 Markdown 风格链接)
// ============================================
class NarrativeCard extends StatelessWidget {
  final String title;
  final String content;
  final String question;
  final Function(String eventId) onLinkTap;
  final VoidCallback onClose;

  const NarrativeCard({
    Key? key,
    required this.title,
    required this.content,
    required this.question,
    required this.onLinkTap,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 600, // 限制最大宽度
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          margin: EdgeInsets.all(24),
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 30, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 标题栏
              Row(
                children: [
                  Icon(Icons.auto_stories, color: Colors.amber[800], size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title, 
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: onClose,
                  )
                ],
              ),
              Divider(height: 30),
              
              // 2. 可滚动的正文
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.8, fontFamily: 'System'),
                          children: _parseContent(content),
                        ),
                      ),
                      SizedBox(height: 30),
                      
                      // 3. 核心问题
                      Container(
                        padding: EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.psychology, color: Colors.deepPurple, size: 32),
                            SizedBox(height: 8),
                            Text(
                              question,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple[800],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 24),
              
              // 4. 底部按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[800],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Start Exploring / 开始探索", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 解析 [文本](id) 格式
  List<InlineSpan> _parseContent(String text) {
    final List<InlineSpan> spans = [];
    final RegExp exp = RegExp(r'\[(.*?)\]\((.*?)\)');
    
    int lastMatchEnd = 0;
    
    for (final Match match in exp.allMatches(text)) {
      // 添加链接前的普通文字
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      
      final String linkText = match.group(1)!;
      final String eventId = match.group(2)!;

      // 添加链接文字
      spans.add(
        TextSpan(
          text: linkText,
          style: TextStyle(
            color: Colors.blue[700], 
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: Colors.blue[200],
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onLinkTap(eventId),
        ),
      );
      
      lastMatchEnd = match.end;
    }
    
    // 添加剩余文字
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }
    
    return spans;
  }
}
