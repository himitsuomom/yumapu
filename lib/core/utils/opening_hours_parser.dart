// lib/core/utils/opening_hours_parser.dart
//
// OSM（OpenStreetMap）形式の営業時間文字列を日本語表示に変換するパーサー。
//
// OSM形式の例:
//   "Mo-Fr 10:00-21:00"
//   "Mo-Fr 10:00-21:00; Sa,Su 10:00-22:00"
//   "24/7"
//   "Mo-Fr 10:00-21:00; PH off"
//   "Tu off"
//
// 変換後の例:
//   "月〜金 10:00〜21:00"
//   "月〜金 10:00〜21:00 / 土・日 10:00〜22:00"
//   "24時間営業"
//   "月〜金 10:00〜21:00 / 祝 定休日"
//   "火 定休日"
//
// 解析できない形式はそのまま返す（安全側）。

/// OSM形式の営業時間文字列を日本語に変換する。
///
/// [raw] が null または空文字列の場合は null を返す。
/// 解析不能な場合は元の文字列を返す。
String? parseOsmOpeningHours(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final trimmed = raw.trim();

  // 24時間営業
  if (trimmed == '24/7') return '24時間営業';

  // セミコロンで区切られた複数のルールを処理
  final rules = trimmed.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty);
  final parsedRules = <String>[];

  for (final rule in rules) {
    final parsed = _parseRule(rule);
    if (parsed == null) {
      // 解析不能なルールがあった場合は元の文字列を返す（安全側）
      return trimmed;
    }
    parsedRules.add(parsed);
  }

  if (parsedRules.isEmpty) return trimmed;
  return parsedRules.join(' / ');
}

/// 1つのルール（例: "Mo-Fr 10:00-21:00"）を日本語に変換する。
/// 解析できない場合は null を返す。
String? _parseRule(String rule) {
  // 空ルール
  if (rule.isEmpty) return null;

  // "off" のみ → 定休日
  if (rule.toLowerCase() == 'off') return '定休日';

  // 曜日部分と時間部分を分割（スペースで分割）
  // "Mo-Fr 10:00-21:00" → days="Mo-Fr", times="10:00-21:00"
  // "Mo-Fr" のみ（時間なし） → days="Mo-Fr", times=""
  final spaceIndex = rule.indexOf(' ');
  final String daysPart;
  final String timesPart;

  if (spaceIndex == -1) {
    // スペースがない場合: 曜日のみ or 時間のみ or "off" など
    daysPart = rule;
    timesPart = '';
  } else {
    daysPart = rule.substring(0, spaceIndex).trim();
    timesPart = rule.substring(spaceIndex + 1).trim();
  }

  // 曜日を日本語に変換
  final daysJa = _parseDays(daysPart);
  if (daysJa == null) return null;

  // 時間部分の変換
  if (timesPart.isEmpty || timesPart.toLowerCase() == 'off') {
    // 時間なし or "off" → "定休日"
    return '$daysJa 定休日';
  }

  final timesJa = _parseTimes(timesPart);
  if (timesJa == null) return null;

  return '$daysJa $timesJa';
}

/// 曜日部分（例: "Mo-Fr", "Sa,Su", "PH", "Mo"）を日本語に変換する。
/// 解析できない場合は null を返す。
String? _parseDays(String days) {
  if (days.isEmpty) return null;

  // カンマ区切り（例: "Sa,Su"）は「土・日」のように「・」で結合
  if (days.contains(',')) {
    final parts = days.split(',').map((d) => d.trim());
    final jaList = <String>[];
    for (final part in parts) {
      final ja = _parseDays(part);
      if (ja == null) return null;
      jaList.add(ja);
    }
    return jaList.join('・');
  }

  // ハイフン区切り（例: "Mo-Fr"）は「月〜金」のように「〜」で結合
  if (days.contains('-')) {
    final dashIndex = days.indexOf('-');
    final from = days.substring(0, dashIndex).trim();
    final to = days.substring(dashIndex + 1).trim();
    final fromJa = _dayCode(from);
    final toJa = _dayCode(to);
    if (fromJa == null || toJa == null) return null;
    return '$fromJa〜$toJa';
  }

  // 単一曜日または特殊コード
  return _dayCode(days);
}

/// 単一の曜日コードを日本語1文字に変換する。
String? _dayCode(String code) {
  switch (code.trim()) {
    case 'Mo':
      return '月';
    case 'Tu':
      return '火';
    case 'We':
      return '水';
    case 'Th':
      return '木';
    case 'Fr':
      return '金';
    case 'Sa':
      return '土';
    case 'Su':
      return '日';
    case 'PH':
      return '祝';
    default:
      return null; // 未知のコードは変換不能
  }
}

/// 時間部分（例: "10:00-21:00", "10:00-21:00,22:00-23:00"）を日本語に変換する。
/// 解析できない場合は null を返す。
String? _parseTimes(String times) {
  if (times.isEmpty) return null;

  // "off" → 定休日（呼び出し元で処理済みだが念のため）
  if (times.toLowerCase() == 'off') return '定休日';

  // カンマ区切りの複数時間帯（例: "10:00-14:00,18:00-22:00"）
  if (times.contains(',')) {
    final parts = times.split(',').map((t) => t.trim());
    final jaList = <String>[];
    for (final part in parts) {
      final ja = _parseSingleTimeRange(part);
      if (ja == null) return null;
      jaList.add(ja);
    }
    return jaList.join('・');
  }

  return _parseSingleTimeRange(times);
}

/// 単一の時間帯（例: "10:00-21:00"）を日本語形式に変換する。
/// "10:00〜21:00" のように「-」を「〜」に置換する。
/// "HH:MM-HH:MM" 形式でない場合は null を返す。
String? _parseSingleTimeRange(String timeRange) {
  // OSMの時間形式は "HH:MM-HH:MM"
  final timeRangeRegex = RegExp(
    r'^(\d{1,2}:\d{2})-(\d{1,2}:\d{2})$',
  );
  final match = timeRangeRegex.firstMatch(timeRange.trim());
  if (match == null) return null;
  final from = match.group(1)!;
  final to = match.group(2)!;
  return '$from〜$to';
}
