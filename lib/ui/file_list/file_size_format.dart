/// ファイルの大きさの書き方(`008:T48`。リネーム画面の行の補足情報と、app 内
/// browser の行の2行目)。
///
/// **有効数字3桁**(`008:T62`。2026-10-08 の開発者の決定「有効数字を 3 桁に」)。
/// 単位は 1024 刻みのまま、**値が 1000 に届いたら次の単位で書く**(Android の
/// ファイルアプリと同じ考え方)。例: `999 B`・`0.98 KB`・`2.40 MB`・`12.3 MB`・
/// `999 MB`・`0.98 GB`。最長でも7文字で、以前の `1023.0 MB`(9文字)のように
/// 狭い行で大きさが削られることがない(行の補足情報の字下げに幅を回すため)。
///
/// 以前(`T48`)は参考design(`docs/design/Bulk Renamer.html` の `fmtSize`)に
/// 合わせて、KB は整数・MB と GB は小数1桁・1024 に届くまで同じ単位だった。
///
/// **丸めで 1000 に届いたら、次の単位で出す。** `999.6 KB` は `1000 KB` ではなく
/// `0.98 MB` と書く。B は丸めないので `999 B` までで、1000 B からは KB になる。
/// **単位は EB まで持つ**ので、`int` で表せるどの大きさ(最大 約 8 EB)も有効数字3桁・
/// 7文字以下で書ける(独立review attempt 2 の P1。GB で止めると `10000 GB` の8文字になった)。
String formatFileSize(int bytes) {
  if (bytes < 1000) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB', 'PB', 'EB'];
  var value = bytes / 1024;
  for (var i = 0; i < units.length; i++) {
    final text = _threeSignificant(value);
    if (double.parse(text) < 1000) {
      return '$text ${units[i]}';
    }
    value /= 1024;
  }
  // int の最大(2^63 - 1)は 8.00 EB なので、ここへは来ない。
  throw StateError('unreachable');
}

/// [value] を有効数字3桁で書く(1000 以上は整数)。丸めで桁が上がったら
/// (`9.996` → `10.00`)小数を1桁減らして書き直す。
String _threeSignificant(double value) {
  var digits = value < 10
      ? 2
      : value < 100
      ? 1
      : 0;
  var text = value.toStringAsFixed(digits);
  while (digits > 0 && double.parse(text) >= (digits == 2 ? 10 : 100)) {
    digits--;
    text = value.toStringAsFixed(digits);
  }
  return text;
}
