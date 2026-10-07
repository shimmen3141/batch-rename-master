/// 行に出す日時(`2026/10/1 09:05`)。リネーム画面の行の補足情報と、app 内 browser の
/// 行の2行目(`008:T58`)で**同じ書式**にする。
String formatRowDateTime(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}/${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
}
