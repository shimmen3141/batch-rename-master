// 連番の桁数の下限(003 REQ-014 / REQ-015)。widget に依存しない計算だけを置く。
//
// エディタ(REQ-014)と、件数が増えたときの自動の引き上げ(REQ-015。`RuleController`)が
// **同じ式**を使う。片方だけ変えると、エディタが許す桁数と自動で引き上げる桁数が
// 食い違う。

/// ゼロ埋めありの連番の桁数の下限(003 REQ-014)。
///
/// 最大の番号 `start + (max(itemCount, 1) − 1) × increment` の10進桁数。一覧が
/// 0件なら開始番号の桁数になる。001 の桁不足(REQ-008)と同じ数え方なので、下限
/// 以上の桁数なら、その件数では桁不足が出ない。
int sequenceMinDigits({
  required int start,
  required int increment,
  required int itemCount,
}) {
  final last = start + ((itemCount < 1 ? 1 : itemCount) - 1) * increment;
  final max = last > start ? last : start;
  return max.abs().toString().length;
}
