/// 一覧ヘッダの末尾(外すアイコンとケバブ)の寸法。
///
/// **読み込み帯の吹き出しがツノをアイコンへ合わせるために共有する**(`008:T30`)。
/// 帯とヘッダは別の widget なので、位置を測り合うのではなく**同じ数を使う**。
/// 合っているかどうかは widget test が実測で確かめる(ツノの中心 == アイコンの中心)ので、
/// ここの数が実体とずれたら落ちる。
library;

/// 一覧ヘッダの左右 padding。
const double headerBarHorizontalPadding = 8;

/// ヘッダのアイコン button(`やめる` / `外す`)の枠。
const double headerIconExtent = 40;

/// ヘッダのケバブの枠。`PopupMenuButton` 既定の tap target である。
const double headerMenuExtent = 48;

/// 読み込み帯の左右 padding。
const double sourceBarHorizontalPadding = 12;

/// 画面の右端から**外すアイコンの中心**までの距離。
const double removeIconCenterFromRight =
    headerBarHorizontalPadding + headerMenuExtent + headerIconExtent / 2;

/// 読み込み帯の中身の右端から**外すアイコンの中心**までの距離。
///
/// 帯の吹き出しはこの位置にツノを立てる。
const double removalHintTailInsetFromRight =
    removeIconCenterFromRight - sourceBarHorizontalPadding;
