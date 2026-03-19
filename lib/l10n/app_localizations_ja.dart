// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Yu-Map';

  @override
  String get commonButtonCancel => 'キャンセル';

  @override
  String get commonButtonRetry => '再試行';

  @override
  String get commonButtonOk => 'OK';

  @override
  String get commonLabelLoading => '読み込み中...';

  @override
  String get commonMessageNoData => 'データがありません';

  @override
  String get commonMessageError => 'エラーが発生しました';

  @override
  String get commonMessageNetworkError => 'ネットワークエラーが発生しました';

  @override
  String get userRankingTitleBeginner => '湯めぐり初心者';

  @override
  String get userRankingTitleIntermediate => '湯めぐり中級者';

  @override
  String get userRankingTitleExpert => '温泉愛好家';

  @override
  String get userRankingTitleMaster => '湯めぐり名人';

  @override
  String get userRankingTitlePro => '湯の達人';

  @override
  String get userRankingTitleLegend => '湯マスター';
}
