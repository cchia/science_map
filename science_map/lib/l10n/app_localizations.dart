import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // 界面文本
  String get appTitle => locale.languageCode == 'zh' ? '科学发展地图' : 'Science History Map';
  String get playButton => locale.languageCode == 'zh' ? '播放' : 'Play';
  String get pauseButton => locale.languageCode == 'zh' ? '暂停' : 'Pause';
  String get resetButton => locale.languageCode == 'zh' ? '重置' : 'Reset';
  String get year => locale.languageCode == 'zh' ? '年份' : 'Year';
  String get eventsCount => locale.languageCode == 'zh' ? '个事件' : 'events';
  String get linesCount => locale.languageCode == 'zh' ? '条连线' : 'lines';
  String get learningPath => locale.languageCode == 'zh' ? '学习路径' : 'Learning Path';
  String get selectTheme => locale.languageCode == 'zh' ? '选择一个主题' : 'Select a theme';
  String get allEvents => locale.languageCode == 'zh' ? '全部事件' : 'All Events';
  String get startLearning => locale.languageCode == 'zh' ? '开始学习' : 'Start Learning';
  String get fieldClassification => locale.languageCode == 'zh' ? '学科分类' : 'Field Classification';
  String get close => locale.languageCode == 'zh' ? '关闭' : 'Close';
  String get introduction => locale.languageCode == 'zh' ? '简介' : 'Introduction';
  String get story => locale.languageCode == 'zh' ? '故事' : 'Story';
  String get funFact => locale.languageCode == 'zh' ? '趣味知识' : 'Fun Fact';
  String get simpleExplanation => locale.languageCode == 'zh' ? '简单解释' : 'Simple Explanation';
  String get impact => locale.languageCode == 'zh' ? '影响' : 'Impact';
  String get influenceStory => locale.languageCode == 'zh' ? '知识传承故事' : 'Knowledge Legacy';
  String get relatedConcepts => locale.languageCode == 'zh' ? '相关概念' : 'Related Concepts';
  String get knowledgeTransfer => locale.languageCode == 'zh' ? '知识传承' : 'Knowledge Transfer';
  String get influencedBy => locale.languageCode == 'zh' ? '受以下影响' : 'Influenced By';
  String get influenced => locale.languageCode == 'zh' ? '影响了以下' : 'Influenced';
  String get quiz => locale.languageCode == 'zh' ? '小测验' : 'Quiz';
  String get correct => locale.languageCode == 'zh' ? '太棒了！答对了！🎉' : 'Great! Correct! 🎉';
  String get tryAgain => locale.languageCode == 'zh' ? '再想想，试试其他选项！' : 'Try again!';
  String get completedLearning => locale.languageCode == 'zh' ? '完成学习！' : 'Completed!';
  String get congratulations => locale.languageCode == 'zh' ? '恭喜你完成了' : 'Congratulations on completing';
  String get awesome => locale.languageCode == 'zh' ? '太棒了！' : 'Awesome!';
  
  String showingEvents(int count) => locale.languageCode == 'zh' 
      ? '显示 $count 个事件' 
      : 'Showing $count events';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}