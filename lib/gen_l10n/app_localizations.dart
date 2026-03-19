import 'package:flutter/material.dart';

// ignore_for_file: unnecessary_brace_in_string_interps

class AppLocalizations {
  AppLocalizations(
    this.locale, {
    required this.messages,
  });

  final Locale locale;
  final Map<String, String> messages;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ja'),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    _AppLocalizationsDelegate(),
  ];

  String get appTitle => messages['appTitle'] ?? 'Yu-Map';
  String get commonButtonCancel => messages['commonButtonCancel'] ?? 'キャンセル';
  String get commonButtonOk => messages['commonButtonOk'] ?? 'OK';
  String get commonButtonRetry => messages['commonButtonRetry'] ?? '再試行';
  String get commonLabelLoading => messages['commonLabelLoading'] ?? '読み込み中...';
  String get commonMessageNoData => messages['commonMessageNoData'] ?? 'データがありません';
  String get commonMessageError => messages['commonMessageError'] ?? 'エラーが発生しました';
  String get commonMessageNetworkError => messages['commonMessageNetworkError'] ?? 'ネットワークエラーが発生しました';
  String get userRankingTitleBeginner => messages['userRankingTitleBeginner'] ?? '湯めぐり初心者';
  String get userRankingTitleIntermediate => messages['userRankingTitleIntermediate'] ?? '湯めぐり中級者';
  String get userRankingTitleExpert => messages['userRankingTitleExpert'] ?? '温泉愛好家';
  String get userRankingTitleMaster => messages['userRankingTitleMaster'] ?? '湯めぐり名人';
  String get userRankingTitlePro => messages['userRankingTitlePro'] ?? '湯の達人';
  String get userRankingTitleLegend => messages['userRankingTitleLegend'] ?? '湯マスター';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return <String>['ja'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale, messages: _loadMessages(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;

  static Map<String, String> _loadMessages(Locale locale) {
    return <String, String>{
      'appTitle': 'Yu-Map',
      'commonButtonCancel': 'キャンセル',
      'commonButtonOk': 'OK',
      'commonButtonRetry': '再試行',
      'commonLabelLoading': '読み込み中...',
      'commonMessageNoData': 'データがありません',
      'commonMessageError': 'エラーが発生しました',
      'commonMessageNetworkError': 'ネットワークエラーが発生しました',
      'userRankingTitleBeginner': '湯めぐり初心者',
      'userRankingTitleIntermediate': '湯めぐり中級者',
      'userRankingTitleExpert': '温泉愛好家',
      'userRankingTitleMaster': '湯めぐり名人',
      'userRankingTitlePro': '湯の達人',
      'userRankingTitleLegend': '湯マスター',
    };
  }
}
