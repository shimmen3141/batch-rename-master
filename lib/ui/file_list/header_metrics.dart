/// 一覧ヘッダの末尾(外すアイコンとケバブ)の寸法。
///
/// **吹き出しがツノをアイコンへ合わせるために共有する**(`008:T30`)。吹き出しは
/// `Overlay` にあって帯やヘッダとは別の木なので、位置を測り合うのではなく**同じ数を使う**。
/// 合っているかどうかは widget test が実測で確かめる(ツノの中心 == アイコンの中心)ので、
/// ここの数が実体とずれたら落ちる。
///
/// **派生の定数はここに置かない。** かつて「画面の右端からアイコンの中心まで」を
/// ここで組み立てていたが、`Overlay` へ移して `LayerLink` が位置を決めるようになり
/// 誰も使わなくなった。しかも [removalHintTailInsetFromRight] と**同じ名前で値の違う**
/// 定数が吹き出し側にもあり、Dart は import した同名の宣言を**黙って上書きする**ので、
/// ここを直しても何も変わらないという罠になっていた(独立review attempt 2 の P2)。
library;

/// 一覧ヘッダの左右 padding。
const double headerBarHorizontalPadding = 8;

/// ヘッダのアイコン button(`やめる` / `外す`)の枠。
const double headerIconExtent = 40;

/// ヘッダのケバブの枠。`PopupMenuButton` 既定の tap target である。
const double headerMenuExtent = 48;

/// 読み込み帯の左右 padding。
const double sourceBarHorizontalPadding = 12;
