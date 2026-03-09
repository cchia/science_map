import 'package:flutter/widgets.dart';

class AppL10n {
  const AppL10n._(this._isZh);

  // Narrative fields are currently authored in Chinese only.
  // Keep UI single-language (Chinese) until full English narrative pack is ready.
  static const bool englishNarrativeReady = false;

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

  String get appTitle => text('中国王朝图谱', 'China Dynasty Atlas');

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
}
