/// 一覧ヘッダと読み込み帯の寸法。
///
/// かつて外すアイコンへ向けた吹き出し(`008:T30`)が同じ数を共有していたが、`008:T42` で
/// 外す操作をフッターへ移し、吹き出しもやめた。
library;

/// 一覧ヘッダの左右 padding。
const double headerBarHorizontalPadding = 8;

/// ヘッダのアイコン button(`やめる`)の枠。
const double headerIconExtent = 40;

/// ヘッダのケバブの枠。`PopupMenuButton` 既定の tap target である。
const double headerMenuExtent = 48;

/// 読み込み帯の左右 padding。
const double sourceBarHorizontalPadding = 12;
