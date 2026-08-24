import 'dart:io';

import 'android_file_source.dart';
import 'desktop_file_source.dart';
import 'file_source.dart';

/// どの platform がどの [FileSource] を使うかの写像(004 REQ-011 / REQ-015)。
///
/// **Android は app 内 file browser**([AndroidFileSource])。SAF のファイル選択
/// 画面は使わない(004 REQ-015 / 013 ADR-002)。desktop は OS ピッカー
/// ([DesktopFileSource])のままで、**013 は desktop の振る舞いを変えない**。
/// それ以外は契約どおり [Failed] を返す(例外は投げない。004 REQ-001)。
///
/// **純関数として切り出してある。** `Platform.isAndroid` を条件式へ直接書くと、
/// この写像を Linux 上の test で固定できない(ADR-003)。
///
/// [pick] は Android の browser を開く操作。UI 層が供給する。
FileSource fileSourceFor({
  required bool isAndroid,
  required bool isDesktop,
  required BrowserPicker pick,
}) {
  if (isAndroid) return AndroidFileSource(pick: pick);
  if (isDesktop) return const DesktopFileSource();
  return const UnsupportedFileSource();
}

/// 実行中のプラットフォームに合う [FileSource] を返す。
FileSource createPlatformFileSource({required BrowserPicker pick}) =>
    fileSourceFor(
      isAndroid: Platform.isAndroid,
      isDesktop: Platform.isWindows || Platform.isLinux || Platform.isMacOS,
      pick: pick,
    );

/// 未対応プラットフォーム用の [FileSource]。常に [Failed] を返す(REQ-001/008)。
class UnsupportedFileSource implements FileSource {
  const UnsupportedFileSource();

  static const _error = PickError(
    PickErrorKind.unknown,
    'このプラットフォームではファイルの読み込みに対応していません',
  );

  @override
  Future<PickResult> pickFiles({List<String> mimeTypes = const []}) async =>
      const Failed(_error);

  /// 未対応プラットフォームでは実在名も列挙できない(004 REQ-014 / 005 REQ-027)。
  @override
  Future<NameListResult> listNames(String folder) async =>
      const NameListFailed(_error);
}
