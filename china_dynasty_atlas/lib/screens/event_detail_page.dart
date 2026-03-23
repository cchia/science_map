import 'package:flutter/material.dart';

import '../l10n/app_l10n.dart';
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
    final l10n = AppL10n.of(context);
    final summary = l10n.isZh ? event.summaryZh : event.summaryEn;
    final content = l10n.isZh ? event.contentZh : event.contentEn;
    final significance = l10n.isZh ? event.significanceZh : event.significanceEn;
    final consequences = l10n.isZh ? event.consequencesZh : event.consequencesEn;
    final locationName = placeNames.isNotEmpty
        ? placeNames.first
        : (l10n.isZh ? event.locationNameZh : event.locationNameEn);
    final relatedPeople = event.relatedPeople
        .map((id) => peopleById[id])
        .whereType<HistoricalPerson>()
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('事件详情', 'Event Details'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.displayName(event.titleZh, event.titleEn),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: l10n.text('年份', 'Year'), value: l10n.formatYear(event.year)),
              _MetaChip(label: l10n.text('地点', 'Location'), value: locationName),
              _MetaChip(label: l10n.text('政权', 'Territory'), value: territoryNames.join(' / ')),
              if (event.confidence.isNotEmpty)
                _MetaChip(label: l10n.text('置信度', 'Confidence'), value: event.confidence),
            ],
          ),
          if (placeNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${l10n.text('地点实体', 'Place Entities')}: ${placeNames.join(' / ')}'),
          ],
          const SizedBox(height: 20),
          Text(l10n.text('摘要', 'Summary'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(summary),
          const SizedBox(height: 20),
          Text(l10n.text('正文', 'Content'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(content),
          if (significance.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.text('历史意义', 'Significance'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(significance),
          ],
          if (consequences.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.text('后续影响', 'Consequences'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...consequences.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $item'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(l10n.text('标签', 'Tags'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: event.tags
                .map((tag) => Chip(label: Text(l10n.tagLabel(tag))))
                .toList(growable: false),
          ),
          if (relatedPeople.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.text('相关人物', 'Related People'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: relatedPeople
                  .map(
                    (person) => ActionChip(
                      avatar: const Icon(Icons.person, size: 18),
                      label: Text(
                        '${l10n.displayName(person.nameZh, person.nameEn)} · ${l10n.roleLabel(person.role)}',
                      ),
                      onPressed: () => onPersonSelected(person),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (event.sourceNotes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.text('资料说明', 'Source Notes'), style: Theme.of(context).textTheme.titleMedium),
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
            Text('${l10n.text('来源实体', 'Source Entities')}: ${sourceLabels.join(' / ')}'),
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

