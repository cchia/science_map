import 'package:flutter/material.dart';

import '../models/atlas_models.dart';

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    required this.territoryNames,
    required this.placeNames,
    required this.sourceLabels,
    required this.peopleById,
    required this.onPersonSelected,
  });

  final HistoricalEvent event;
  final List<String> territoryNames;
  final List<String> placeNames;
  final List<String> sourceLabels;
  final Map<String, HistoricalPerson> peopleById;
  final ValueChanged<HistoricalPerson> onPersonSelected;

  @override
  Widget build(BuildContext context) {
    final relatedPeople = event.relatedPeople
        .map((id) => peopleById[id])
        .whereType<HistoricalPerson>()
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('事件详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(event.titleZh, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            event.titleEn,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: '年份', value: _yearLabel(event.year)),
              _MetaChip(label: '地点', value: event.locationName),
              _MetaChip(label: '政权', value: territoryNames.join(' / ')),
              if (event.confidence.isNotEmpty)
                _MetaChip(label: '置信度', value: event.confidence),
            ],
          ),
          if (placeNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('地点实体: ${placeNames.join(' / ')}'),
          ],
          const SizedBox(height: 20),
          Text('摘要', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(event.summary),
          const SizedBox(height: 20),
          Text('正文', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(event.content),
          if (event.significance.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('历史意义', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(event.significance),
          ],
          if (event.consequences.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('后续影响', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...event.consequences.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $item'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('标签', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: event.tags
                .map((tag) => Chip(label: Text(tag)))
                .toList(growable: false),
          ),
          if (relatedPeople.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('相关人物', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: relatedPeople
                  .map(
                    (person) => ActionChip(
                      avatar: const Icon(Icons.person, size: 18),
                      label: Text(person.nameZh),
                      onPressed: () => onPersonSelected(person),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (event.sourceNotes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('资料说明', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...event.sourceNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $note'),
              ),
            ),
          ],
          if (sourceLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('来源实体: ${sourceLabels.join(' / ')}'),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

String _yearLabel(int year) {
  if (year < 0) {
    return '公元前${year.abs()}年';
  }
  return '公元$year年';
}
