/// 行の補足情報に出すファイルの大きさ(`008:T48`)。
///
/// 参考design(`docs/design/Bulk Renamer.html` の `fmtSize`)に合わせる:
/// 1024 未満は `B`、KB は整数、MB は小数1桁。**GB を足した**(参考designに無い。
/// 動画で届く)。単位は 1024 刻み。
///
/// **丸めで次の単位へ届いたら、次の単位で出す。** `1048575` を KB で丸めると
/// `1024 KB` になるが、それは `1.0 MB` と書く。
String formatFileSize(int bytes) {
  const k = 1024;
  if (bytes < k) return '$bytes B';
  final kb = (bytes / k).round();
  if (kb < k) return '$kb KB';
  final mb = bytes / (k * k);
  if (double.parse(mb.toStringAsFixed(1)) < k) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  return '${(bytes / (k * k * k)).toStringAsFixed(1)} GB';
}
