import 'package:path/path.dart' as p;

import 'file_source.dart';

/// 保存場所(004 REQ-015)。
///
/// **プラットフォームが共有ストレージのボリュームとして列挙する単位**である。
/// Android では内部共有ストレージと、装着されている SD カード・USB のそれぞれ。
/// [root] より上位へは辿れない — **この境界は全ファイルアクセス権限が与える範囲
/// そのもの**で、`/storage` や `/` には到達経路が無い。
class StorageLocation {
  const StorageLocation({required this.name, required this.root});

  /// 利用者へ見せる名前(「内部ストレージ」「SD カード」など)。
  final String name;

  /// この保存場所の root の絶対 path。**ここより上へは辿れない。**
  final String root;
}

/// [StorageBrowserPort.locations] の結果。
///
/// **「これだけは分かった」と「取れなかった」を1つの値で運ぶ。** 保存場所は
/// 内部共有ストレージだけでも成立するので、取得の失敗は**全滅ではなく欠落**である。
///
/// **黙って欠落させない。** `013:T08` の実機観測まで、「取り外し可能な媒体が無い
/// 端末」と「列挙できていない」を誰も区別できず、**装着されている SD カードが
/// 保存場所に並ばないことに気づけなかった**(004 REQ-015 / 代表例26e)。
class StorageLocations {
  const StorageLocations(this.locations, {this.failure});

  /// 見つかった保存場所。**空にはしない** — 内部共有ストレージは常に返す。
  final List<StorageLocation> locations;

  /// 一部を取得できなかったときの理由。取得できていれば `null`。
  final String? failure;
}

/// browser に並ぶ1件(004 REQ-017: 絞り込まずにそのまま見せる)。
class BrowserEntry {
  const BrowserEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
  });

  final String name;
  final String path;
  final bool isDirectory;
}

/// [StorageBrowserPort.list] の結果。
///
/// **「列挙できなかった」と「entry が無い」を型で区別する**(004 REQ-014 と同じ理由)。
sealed class DirectoryListing {
  const DirectoryListing();
}

class DirectoryListed extends DirectoryListing {
  const DirectoryListed(this.entries);

  final List<BrowserEntry> entries;
}

class DirectoryListingFailed extends DirectoryListing {
  const DirectoryListingFailed(this.error);

  final PickError error;
}

/// 保存場所と folder の中身を答える port(004 REQ-015 / REQ-017)。
///
/// **実 filesystem を触るのはこの実装だけ**である。UI も判定も port 越しに動くので、
/// Linux 上の test で階層移動・選択・注記をすべて再現できる。
abstract interface class StorageBrowserPort {
  /// 保存場所の一覧(004 REQ-015)。
  Future<StorageLocations> locations();

  /// [folder] の直下の entry。**絞り込まない**(004 REQ-017)。
  Future<DirectoryListing> list(String folder);
}

/// browser を開いたときに、いきなり中へ入る保存場所(004 REQ-015)。
///
/// **保存場所が1つだけのときは一覧を挟まない** — 選択肢が1つしかない画面を
/// 1回押させないためである。複数あるときは `null` を返し、一覧から始める。
///
/// **`failure` があるときも `null` を返す。** 一部を列挙できていない状態では
/// 「1つだけ」と言い切れず、**取れなかったことを知らせる notice も一覧の側にある**
/// (`013:T08` の実機観測: 装着している SD カードが並ばないことに気づけなかった)。
StorageLocation? soleLocation(StorageLocations locations) {
  if (locations.failure != null) return null;
  if (locations.locations.length != 1) return null;
  return locations.locations.single;
}

/// [folder] から1つ上へ辿れるか(004 REQ-015: 上限は保存場所の root)。
///
/// **root そのものからは辿れない。** `/storage` や `/` へは到達経路が無い —
/// 絞り込みで隠すのではなく、辿れないことで達成する(REQ-017 と両立させるため)。
bool canGoUp({required String folder, required String root}) {
  final normalized = p.normalize(folder);
  final normalizedRoot = p.normalize(root);
  if (normalized == normalizedRoot) return false;
  return p.isWithin(normalizedRoot, normalized);
}

/// [folder] の1つ上。[canGoUp] が `false` のときは呼ばない。
String parentOf(String folder) => p.dirname(p.normalize(folder));

/// パンくずの1区切り(`008:T38` の現在地の帯)。
///
/// [path] は区切りが指す folder で、**tap したときの移動先**になる(`008:T40`)。
typedef BreadcrumbSegment = ({String name, String path});

/// [folder] までのパンくず。先頭は保存場所の root で、名前は保存場所名になる。
///
/// **root より上の区切りは作らない**(004 REQ-015: 上限は保存場所の root)。
/// [folder] が root の外なら root だけを返す — 辿れない場所を名指ししない。
List<BreadcrumbSegment> breadcrumbOf(StorageLocation location, String folder) {
  final root = p.normalize(location.root);
  final segments = <BreadcrumbSegment>[(name: location.name, path: root)];
  final normalized = p.normalize(folder);
  if (!p.isWithin(root, normalized)) return segments;
  var path = root;
  for (final part in p.split(p.relative(normalized, from: root))) {
    path = p.join(path, part);
    segments.add((name: part, path: path));
  }
  return segments;
}

/// **`/Android/` 配下を表示しているとき**、改名できない可能性を示すか
/// (004 REQ-018)。
///
/// **これは注記であって判定ではない。** 一次資料が「大半の」としか書いておらず
/// 境界が文書化されていないため、**この注記が出ない場所でも改名に失敗しうるし、
/// 出た場所で成功しうる**。最終的な可否は実行結果が示す(005 REQ-013)。
///
/// **どこで示し、どこでは示さないかは 004 spec の REQ-018 が正本**である。
/// ここはその実装で、判定に使う名前は必然的にコードへ現れる — 説明を増やさず、
/// 範囲を知りたい人は REQ-018 を読むこと。
bool showsRestrictedNotice(String folder) {
  final parts = p.split(p.normalize(folder));
  final index = parts.indexOf('Android');
  if (index < 0) return false;
  // `/Android` 直下と、その下の何か。
  final rest = parts.sublist(index + 1);
  if (rest.isEmpty) return true;
  return rest.first != 'media';
}
