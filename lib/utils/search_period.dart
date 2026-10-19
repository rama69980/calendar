/// 検索の期間単位 (年 / 月 / 週 / 日)
enum PeriodUnit { year, month, week, day }

extension PeriodUnitLabel on PeriodUnit {
  String get label => switch (this) {
        PeriodUnit.year => '年',
        PeriodUnit.month => '月',
        PeriodUnit.week => '週',
        PeriodUnit.day => '日',
      };
}

/// 基準日 [anchor] を含む期間。週はカレンダー表示に合わせて日曜始まり
class SearchPeriod {
  final PeriodUnit unit;
  final DateTime from; // 含む
  final DateTime to; // 含む

  const SearchPeriod._(this.unit, this.from, this.to);

  factory SearchPeriod.of(PeriodUnit unit, DateTime anchor) {
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    switch (unit) {
      case PeriodUnit.year:
        return SearchPeriod._(unit, DateTime(day.year, 1, 1), DateTime(day.year, 12, 31));
      case PeriodUnit.month:
        return SearchPeriod._(unit, DateTime(day.year, day.month, 1), DateTime(day.year, day.month + 1, 0));
      case PeriodUnit.week:
        final start = day.subtract(Duration(days: day.weekday % 7)); // 日曜 = 0
        return SearchPeriod._(unit, start, DateTime(start.year, start.month, start.day + 6));
      case PeriodUnit.day:
        return SearchPeriod._(unit, day, day);
    }
  }

  /// 前後の期間へ移動 (delta = -1 / +1)
  SearchPeriod shift(int delta) {
    switch (unit) {
      case PeriodUnit.year:
        return SearchPeriod.of(unit, DateTime(from.year + delta, 1, 1));
      case PeriodUnit.month:
        return SearchPeriod.of(unit, DateTime(from.year, from.month + delta, 1));
      case PeriodUnit.week:
        return SearchPeriod.of(unit, DateTime(from.year, from.month, from.day + 7 * delta));
      case PeriodUnit.day:
        return SearchPeriod.of(unit, DateTime(from.year, from.month, from.day + delta));
    }
  }

  bool contains(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(from) && !d.isAfter(to);
  }

  /// 画面に出す期間名 (例: 2026年 / 2026年10月 / 2026/10/18 〜 10/24 / 2026/10/20(火))
  String get label {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    switch (unit) {
      case PeriodUnit.year:
        return '${from.year}年';
      case PeriodUnit.month:
        return '${from.year}年${from.month}月';
      case PeriodUnit.week:
        return '${from.year}/${from.month}/${from.day} 〜 ${to.month}/${to.day}';
      case PeriodUnit.day:
        return '${from.year}/${from.month}/${from.day}(${weekdays[from.weekday - 1]})';
    }
  }
}
