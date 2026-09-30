/// 一覧ヘッダと読み込み帯の寸法。
///
/// かつて外すアイコンへ向けた吹き出し(`008:T30`)が同じ数を共有していたが、`008:T42` で
/// 外す操作をフッターへ移し、吹き出しもやめた。
library;

/// 一覧ヘッダの左右 padding。
const double headerBarHorizontalPadding = 8;

/// 一覧ヘッダの右の padding。**ケバブの tap target が中のアイコンより 14 広い**ので、
/// 左(8 + 件数の 8)と見た目を揃えるには右を詰める(`008:T02`)。
const double headerBarRightPadding = 2;

/// 一覧ヘッダの左の文字(件数・選択件数)が取れる幅の上限(帯の幅に対する割合)。
/// 残りは並び順とケバブが使う。
const double headerTextMaxWidthFraction = 0.4;

/// ヘッダのアイコン button(`やめる`)の枠。
const double headerIconExtent = 40;

/// ヘッダのケバブの枠。`PopupMenuButton` 既定の tap target である。
const double headerMenuExtent = 48;

/// 読み込み帯の左右 padding。
const double sourceBarHorizontalPadding = 12;
