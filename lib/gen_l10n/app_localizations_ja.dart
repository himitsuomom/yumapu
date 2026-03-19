Future<dynamic> initializeMessages(String localeName) async {
  // This function is called by flutter gen-l10n
  // It loads the appropriate message catalog for the locale
  return _loadMessages(localeName);
}

Future<Map<String, dynamic>> _loadMessages(String locale) {
  // Return hardcoded messages since this is generated code
  return Future.value(<String, dynamic>{
    'appTitle': ('Yu-Map'),
    'commonButtonCancel': ('キャンセル'),
    'commonButtonOk': ('OK'),
    'commonButtonRetry': ('再試行'),
    'commonLabelLoading': ('読み込み中...'),
    'commonMessageNoData': ('データがありません'),
    'commonMessageError': ('エラーが発生しました'),
    'commonMessageNetworkError': ('ネットワークエラーが発生しました'),
    'userRankingTitleBeginner': ('湯めぐり初心者'),
    'userRankingTitleIntermediate': ('湯めぐり中級者'),
    'userRankingTitleExpert': ('温泉愛好家'),
    'userRankingTitleMaster': ('湯めぐり名人'),
    'userRankingTitlePro': ('湯の達人'),
    'userRankingTitleLegend': ('湯マスター'),
  });
}
