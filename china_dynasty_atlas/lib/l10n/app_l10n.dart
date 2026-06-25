import 'package:flutter/widgets.dart';

class AppL10n {
  const AppL10n._(this._isZh);

  // Narrative fields are currently authored in Chinese only.
  // Keep UI single-language (Chinese) until full English narrative pack is ready.
  static const bool englishNarrativeReady = true;

  final bool _isZh;

  static AppL10n of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return AppL10n._(useChineseForLocale(locale));
  }

  static bool useChineseForLocale(Locale locale) {
    if (!englishNarrativeReady) return true;
    return locale.languageCode.toLowerCase().startsWith('zh');
  }

  String text(String zh, String en) => _isZh ? zh : en;
  bool get isZh => _isZh;

  String get appTitle => text('世界文明图谱', 'World Civilizations Atlas');

  String displayName(String zh, String en) {
    if (_isZh) {
      return zh.isNotEmpty ? zh : en;
    }
    return en.isNotEmpty ? en : zh;
  }

  String formatYear(int year) {
    if (_isZh) {
      if (year < 0) return '公元前${year.abs()}年';
      return '公元$year年';
    }
    if (year < 0) return '${year.abs()} BCE';
    return '$year CE';
  }

  String roleLabel(String role) {
    if (!_isZh) return role;
    switch (role) {
      case 'emperor':
        return '皇帝';
      case 'general':
        return '将领';
      case 'envoy':
        return '使者';
      case 'chancellor':
        return '丞相';
      case 'inventor':
        return '发明家';
      case 'military_leader':
        return '军事领袖';
      case 'political_military_leader':
        return '政治军事领袖';
      case 'rebel_leader':
        return '起义领袖';
      default:
        return role;
    }
  }

  String approvalStatusLabel(String status) {
    if (!_isZh) return status;
    switch (status) {
      case 'approved':
        return '已批准';
      case 'reference_only':
        return '仅参考';
      case 'pending':
        return '待审';
      default:
        return status;
    }
  }

  String licenseLabel(String license) {
    if (!_isZh) return license;
    switch (license) {
      case 'Internal':
        return '内部';
      case 'Public Domain':
        return '公有领域';
      case 'Public Domain Mark 1.0':
        return '公有领域标记 1.0';
      case 'CC BY-SA 3.0 / GFDL':
        return 'CC BY-SA 3.0 / GFDL';
      case 'CC BY-SA 4.0':
        return 'CC BY-SA 4.0';
      case 'Academic research only':
        return '仅学术研究';
      case 'CC0':
        return 'CC0';
      default:
        return license;
    }
  }

  String tagLabel(String tag) {
    if (_isZh) return tag;
    switch (tag) {
      case '统一':
        return 'Unification';
      case '制度':
        return 'Institutions';
      case '帝国':
        return 'Empire';
      case '军事':
        return 'Military';
      case '边疆':
        return 'Frontier';
      case '工程':
        return 'Infrastructure';
      case '思想':
        return 'Ideas';
      case '政治':
        return 'Politics';
      case '法家':
        return 'Legalism';
      case '崩溃':
        return 'Collapse';
      case '起义':
        return 'Rebellion';
      case '帝国治理':
        return 'Imperial Governance';
      case '建国':
        return 'State Founding';
      case '楚汉战争':
        return 'Chu-Han War';
      case '制度继承':
        return 'Institutional Inheritance';
      case '治世':
        return 'Prosperous Rule';
      case '经济':
        return 'Economy';
      case '政治稳定':
        return 'Political Stability';
      case '外交':
        return 'Diplomacy';
      case '西域':
        return 'Western Regions';
      case '丝绸之路':
        return 'Silk Road';
      case '扩张':
        return 'Expansion';
      case '贸易':
        return 'Trade';
      case '交通':
        return 'Transport';
      case '篡汉':
        return 'Usurpation';
      case '政治转折':
        return 'Political Turning Point';
      case '改革':
        return 'Reform';
      case '制度实验':
        return 'Institutional Experiment';
      case '危机':
        return 'Crisis';
      case '灭亡':
        return 'Dynastic Fall';
      case '再统一':
        return 'Reunification';
      case '洛阳':
        return 'Luoyang';
      case '科技':
        return 'Technology';
      case '文化':
        return 'Culture';
      case '知识传播':
        return 'Knowledge Diffusion';
      case '宗教':
        return 'Religion';
      case '王朝衰落':
        return 'Dynastic Decline';
      case '终结':
        return 'End';
      case '三国前夜':
        return 'Eve of the Three Kingdoms';
      case '政治转型':
        return 'Political Transition';
      default:
        return tag;
    }
  }
}
