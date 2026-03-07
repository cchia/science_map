import 'package:flutter/material.dart';

class ScienceMapSearchDelegate extends SearchDelegate<String?> {
  final List<Map<String, dynamic>> events;
  final Map<String, dynamic> people;
  final bool isEnglish;

  ScienceMapSearchDelegate({
    required this.events,
    required this.people,
    required this.isEnglish,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return SizedBox.shrink();

    // 1. Filter Events
    final matchedEvents = events.where((e) {
      final title = (e['title'] ?? '').toString().toLowerCase();
      final titleEn = (e['title_en'] ?? '').toString().toLowerCase();
      final id = (e['id'] ?? '').toString().toLowerCase();
      final year = (e['year'] ?? '').toString();
      
      return title.contains(cleanQuery) || 
             titleEn.contains(cleanQuery) ||
             id.contains(cleanQuery) ||
             year.contains(cleanQuery);
    }).toList();

    // 2. Filter People
    final matchedPeople = people.entries.where((entry) {
        final p = entry.value;
        final name = (p['name'] ?? '').toString().toLowerCase();
        final nameEn = (p['name_en'] ?? '').toString().toLowerCase();
        return name.contains(cleanQuery) || nameEn.contains(cleanQuery);
    }).toList();

    return ListView.builder(
      itemCount: matchedEvents.length + matchedPeople.length,
      itemBuilder: (context, index) {
        if (index < matchedEvents.length) {
            final e = matchedEvents[index];
            final title = isEnglish ? (e['title_en'] ?? e['title']) : e['title'];
            final year = e['year'];
            
            return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: Icon(Icons.event, color: Colors.blue),
                ),
                title: Text(title),
                subtitle: Text(isEnglish ? 'Year: $year' : '年份: $year'),
                onTap: () {
                    close(context, e['id']);
                },
            );
        } else {
            final pEntry = matchedPeople[index - matchedEvents.length];
            final p = pEntry.value;
            final name = isEnglish ? (p['name_en'] ?? p['name']) : p['name'];
            
            return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.withOpacity(0.2),
                  child: Icon(Icons.person, color: Colors.purple),
                ),
                title: Text(name),
                subtitle: Text(isEnglish ? 'Person' : '人物'),
                onTap: () {
                    // 如果选择了人物，尝试跳转到该人物的第一个相关事件
                    // 并在返回的 ID 前加前缀 "person:"，以便主界面区分处理（如果需要）
                    // 或者简单地，直接返回第一个事件的ID
                    if (p['events'] != null && (p['events'] as List).isNotEmpty) {
                         close(context, (p['events'] as List).first);
                    } else {
                      // 如果人物没有关联事件，则无操作 (或者提示)
                    }
                },
            );
        }
      },
    );
  }
}

