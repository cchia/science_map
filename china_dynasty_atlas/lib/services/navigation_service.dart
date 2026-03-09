import 'package:flutter/foundation.dart';

import '../models/atlas_models.dart';
import '../search/atlas_search_delegate.dart';
import '../state/atlas_explorer_controller.dart';

class AtlasNavigationService {
  const AtlasNavigationService();

  void applySearchSelection({
    required SearchSelection selection,
    required AtlasExplorerController controller,
    required VoidCallback onMapSelectionChanged,
    required ValueChanged<HistoricalEvent> onEventOpened,
    required ValueChanged<String> onPersonSelected,
  }) {
    switch (selection.type) {
      case SearchSelectionType.territory:
        controller.jumpToTerritory(selection.id);
        onMapSelectionChanged();
        return;
      case SearchSelectionType.event:
        final event = controller.eventById(selection.id);
        if (event == null) return;
        controller.jumpToEvent(event);
        onMapSelectionChanged();
        onEventOpened(event);
        return;
      case SearchSelectionType.person:
        onPersonSelected(selection.id);
        return;
    }
  }
}
