/// 改名失敗の理由(005 spec: OP-004 の `errors`)。
enum RenameErrorKind {
  /// 権限が無い・失効した。
  permissionDenied,

  /// 対象が見つからない(古い=stale なハンドルを渡した場合を含む)。
  notFound,

  /// 同名のファイルが既に存在する。
  nameConflict,

  /// 入出力に失敗した。
  io,

  /// プラットフォームが未対応。
  unsupportedPlatform,

  /// 上記に分類できない失敗。
  unknown,
}

/// 改名失敗の理由と任意のメッセージ(005 REQ-002 が実行結果に含める「理由」)。
class RenameError {
  const RenameError(this.kind, [this.message]);

  /// 失敗の分類。
  final RenameErrorKind kind;

  /// 補足メッセージ(実装が提供できる場合)。
  final String? message;

  @override
  String toString() =>
      'RenameError($kind${message == null ? '' : ', $message'})';
}

/// [RenameExecutor.rename] の結果(005 spec: OP-004)。
///
/// 例外を投げず、成功か失敗を型で区別する(REQ-017)。004 の `PickResult` と
/// 同じ作りにしてあり、呼び出し側は `switch` で網羅的に分岐できる。
sealed class RenameResult {
  const RenameResult();
}

/// 改名に成功した。実体の名前は要求した目標名になっている。
class Renamed extends RenameResult {
  const Renamed(this.newHandle, {this.name = ''});

  /// 改名後のハンドル。**改名前とは別の値になりうる**(REQ-001 / INV-005)。
  ///
  /// デスクトップはハンドルが絶対パスなので名前の変更に伴って変わる。
  /// Android SAF production renameはrevision 2で安全な未対応となる。将来の
  /// Android境界が別のハンドルを返す場合にも、呼び出し側は以降の操作でこの値を使う。
  final String newHandle;

  /// ポートが返した改名後の名前。**空になりうる**。
  ///
  /// platform portは空文字列を返しうる。したがってこの値を表示や後続処理の
  /// 入力にしてはならない — 改名後の名前は要求した目標名を正とする(REQ-018)。
  final String name;
}

/// 改名に失敗した。実体は変化していない(OP-004 の事後条件)。
class RenameFailed extends RenameResult {
  const RenameFailed(this.error);

  /// 失敗の理由。
  final RenameError error;
}

/// 実ファイルを1件改名する抽象ポート(FEAT-005 / OP-004)。
///
/// プラットフォーム固有の手段(Android SAFは安全な未対応、デスクトップは
/// 排他的native rename)は実装の内側に隠す。**例外は投げず**、結果は [RenameResult] で
/// 返す(REQ-017)。004 の `FileSource` と同じ分離で、実ファイルへの作用を
/// この実装だけが持つ(CON-001)。
abstract interface class RenameExecutor {
  /// [handle] が指す実体を [newName] へ改名する。
  ///
  /// [handle] はこの実行の中で最後に得られた値でなければならない(INV-005)。
  /// 成功時は改名後のハンドルを含む [Renamed] を、失敗時は理由を含む
  /// [RenameFailed] を返す(REQ-017)。
  Future<RenameResult> rename(String handle, String newName);
}

/// 改名後の実体へ更新日時を書き込める実装だけが実装する能力(005 REQ-014〜016)。
///
/// [RenameExecutor] 本体には含めない。更新日時を設定する手段はプラットフォームに
/// よって**存在しない**(Android SAF には API が無い)ので、必須メソッドにすると
/// 「呼べるが必ず失敗する」実装を全プラットフォームへ強いることになる。能力を
/// 別に切っておくと、`executor is ModifiedAtWriter` がそのまま「この端末で
/// 更新日時をずらせるか」になり、REQ-015(設定できないプラットフォームでは
/// 設定を提示しない)を実装の形から満たせる。
abstract interface class ModifiedAtWriter {
  /// [handle] が指す実体の更新日時を [value] にする。
  ///
  /// **例外は投げない**(REQ-017 と同じ約束)。成功なら `null`、失敗なら理由を
  /// 返す。更新日時の設定は改名の副次処理なので、失敗しても呼び出し側は改名を
  /// 成功として扱い、実行を止めない(REQ-016)。
  Future<RenameError?> setModifiedAt(String handle, DateTime value);
}

/// 未対応プラットフォーム用の [RenameExecutor]。常に失敗を返す(REQ-017)。
class UnsupportedRenameExecutor implements RenameExecutor {
  const UnsupportedRenameExecutor();

  static const _error = RenameError(
    RenameErrorKind.unsupportedPlatform,
    'このプラットフォームではファイルの改名に対応していません',
  );

  @override
  Future<RenameResult> rename(String handle, String newName) async =>
      const RenameFailed(_error);
}

/// 改名後のハンドルの作り方(プラットフォームごとに異なる)。
typedef RenamedHandleBuilder = String Function(String handle, String newName);

/// 失敗の注入(`null` を返すと通常どおり改名する)。
typedef RenameFailureInjector =
    RenameError? Function(String handle, String newName);

/// パス風ハンドル(デスクトップの絶対パス)の改名後ハンドル。
///
/// 最後の `/` 以降を [newName] で置き換える。区切りが無ければ [newName] 自体。
String pathRenamedHandle(String handle, String newName) {
  final i = handle.lastIndexOf('/');
  return i < 0 ? newName : '${handle.substring(0, i + 1)}$newName';
}

/// [FakeRenameExecutor] が保持する1ファイルの状態。
///
/// [id] と [content] は改名で変化しない(INV-001 の観測点: 実体の個数・内容が
/// 変わらないことを、ハンドルと名前の変化と切り離して確認できる)。
class FakeFileState {
  const FakeFileState({
    required this.id,
    required this.name,
    required this.content,
  });

  /// 実体の同一性。改名しても変わらない。
  final String id;

  /// 現在の名前。
  final String name;

  /// 内容。改名しても変わらない。
  final String content;

  /// [newName] へ改名した後の状態。
  FakeFileState renamedTo(String newName) =>
      FakeFileState(id: id, name: newName, content: content);

  @override
  String toString() => 'FakeFileState($id, $name)';
}

/// 1フォルダぶんの実体を模した [RenameExecutor] 実装(サンドボックス検証用の fake)。
///
/// **本物より親切にしない**ことを設計方針とする(仕様「境界 > 外部依存が実際に
/// 供給できる値」):
///
/// - 改名すると**ハンドルが変わる**([renamedHandle] が作る)。古いハンドルで
///   呼ぶと [RenameErrorKind.notFound] を返す。
/// - 戻り値の [Renamed.name] は既定で**空文字列**([returnedName])。
///   portの最小値域を検査するため、名前情報を提供しない実装を模す。
/// - 同名のファイルが既にあれば [RenameErrorKind.nameConflict] を返し、
///   **既存を上書きしない**(INV-002 を実体側でも守る)。
class FakeRenameExecutor implements RenameExecutor {
  /// [files] は「ハンドル → 現在の名前」。同一フォルダ内のファイルとして扱う。
  FakeRenameExecutor({
    required Map<String, String> files,
    this.renamedHandle = pathRenamedHandle,
    this.returnedName = '',
    this.failWhen,
  }) : _files = {
         for (final e in files.entries)
           e.key: FakeFileState(
             id: e.key,
             name: e.value,
             content: 'content-of:${e.key}',
           ),
       };

  final Map<String, FakeFileState> _files;

  /// 改名後のハンドルの作り方(既定はパス風)。
  final RenamedHandleBuilder renamedHandle;

  /// 成功時に返す名前。既定は空文字列(実機の最悪ケース。REQ-018)。
  final String returnedName;

  /// 失敗の注入。`null` を返した呼び出しは通常どおり改名される。
  final RenameFailureInjector? failWhen;

  /// 実行された改名の記録(`ハンドル -> 新しい名前`)。
  ///
  /// 改名以外の操作をこの fake は持たないため、この記録が実行の全副作用にあたる
  /// (INV-001)。
  final List<String> calls = [];

  /// 現在の実体(ハンドル → 状態)。
  Map<String, FakeFileState> get files => Map.unmodifiable(_files);

  /// 現在の名前の一覧(登録順)。
  List<String> get names => [for (final f in _files.values) f.name];

  @override
  Future<RenameResult> rename(String handle, String newName) async {
    calls.add('$handle -> $newName');

    final injected = failWhen?.call(handle, newName);
    if (injected != null) return RenameFailed(injected);

    final target = _files[handle];
    if (target == null) {
      return const RenameFailed(
        RenameError(RenameErrorKind.notFound, '対象が見つかりません(古いハンドル)'),
      );
    }

    final occupied = _files.entries.any(
      (e) => e.key != handle && e.value.name == newName,
    );
    if (occupied) {
      return const RenameFailed(
        RenameError(RenameErrorKind.nameConflict, '同名のファイルが既に存在します'),
      );
    }

    final next = renamedHandle(handle, newName);
    _files.remove(handle);
    _files[next] = target.renamedTo(newName);
    return Renamed(next, name: returnedName);
  }
}
