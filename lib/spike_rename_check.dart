// ⚠️ 使い捨ての確認用コード(004 T8 の実機スパイク)。
//
// 目的: 導線 B(`OPEN_DOCUMENT` で得たドキュメント URI)で **実際に改名できるか**を
// 1ファイルだけ試して確かめる。`DocumentsContract.renameDocument` は対象が
// `FLAG_SUPPORTS_RENAME` を持つ場合のみ成功するため、文書では確定できない。
// ツリー権限(`OPEN_DOCUMENT_TREE`)で得た URI との比較も行う。
//
// **確認が終わったらこのファイルと `main.dart` の導線ごと削除する。**
// 本実装(005 のリネーム)はここではなく `lib/data/` 側に作る。
import 'package:flutter/material.dart';
import 'package:saf_util/saf_util.dart';

import 'ui/theme/app_colors.dart';

/// スパイクの結果(画面に出す。ホスト側の人間が読んで報告する)。
class SpikeResult {
  const SpikeResult({
    required this.title,
    required this.ok,
    required this.detail,
  });

  final String title;
  final bool ok;
  final String detail;
}

/// 改名スパイクの画面。ボタン2つで「ドキュメント URI」「ツリー権限」を試す。
class SpikeRenameCheckPage extends StatefulWidget {
  const SpikeRenameCheckPage({super.key});

  @override
  State<SpikeRenameCheckPage> createState() => _SpikeRenameCheckPageState();
}

class _SpikeRenameCheckPageState extends State<SpikeRenameCheckPage> {
  final _saf = SafUtil();
  final _results = <SpikeResult>[];
  bool _busy = false;

  void _add(SpikeResult r) => setState(() => _results.insert(0, r));

  /// 末尾に `_t8` を足した名前を作る(拡張子は保つ)。
  static String _renamedOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return '${name}_t8';
    return '${name.substring(0, dot)}_t8${name.substring(dot)}';
  }

  /// ① `OPEN_DOCUMENT` で選んだ1ファイルを改名してみる(導線 B の前提)。
  Future<void> _checkDocumentUri() async {
    setState(() => _busy = true);
    try {
      final files = await _saf.pickFiles(multiple: false);
      if (files == null || files.isEmpty) {
        _add(
          const SpikeResult(
            title: '① ドキュメント URI',
            ok: false,
            detail: 'キャンセルされました(何も選ばれていません)',
          ),
        );
        return;
      }
      final file = files.first;
      final newName = _renamedOf(file.name);
      try {
        final renamed = await _saf.rename(file.uri, false, newName);
        _add(
          SpikeResult(
            title: '① ドキュメント URI',
            ok: true,
            detail:
                '成功: ${file.name} → ${renamed.name}\n'
                '元 URI: ${file.uri}\n'
                '新 URI: ${renamed.uri}\n'
                'URI は${renamed.uri == file.uri ? '同じ' : '変わった'}',
          ),
        );
      } catch (error) {
        _add(
          SpikeResult(
            title: '① ドキュメント URI',
            ok: false,
            detail: '改名に失敗: $error\n対象: ${file.name}\nURI: ${file.uri}',
          ),
        );
      }
    } catch (error) {
      _add(
        SpikeResult(title: '① ドキュメント URI', ok: false, detail: '選択に失敗: $error'),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  /// ② ツリー権限で得たフォルダの1ファイルを改名してみる(比較対象)。
  Future<void> _checkTreeUri() async {
    setState(() => _busy = true);
    try {
      final dir = await _saf.pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      if (dir == null) {
        _add(
          const SpikeResult(title: '② ツリー権限', ok: false, detail: 'キャンセルされました'),
        );
        return;
      }
      final children = await _saf.list(dir.uri);
      final target = children.where((c) => !c.isDir).toList();
      if (target.isEmpty) {
        _add(
          SpikeResult(
            title: '② ツリー権限',
            ok: false,
            detail: 'フォルダ「${dir.name}」にファイルがありません',
          ),
        );
        return;
      }
      final file = target.first;
      final newName = _renamedOf(file.name);
      try {
        final renamed = await _saf.rename(file.uri, false, newName);
        _add(
          SpikeResult(
            title: '② ツリー権限',
            ok: true,
            detail:
                '成功: ${file.name} → ${renamed.name}\n'
                'フォルダ: ${dir.name}\n'
                '新 URI: ${renamed.uri}',
          ),
        );
      } catch (error) {
        _add(
          SpikeResult(
            title: '② ツリー権限',
            ok: false,
            detail: '改名に失敗: $error\n対象: ${file.name}',
          ),
        );
      }
    } catch (error) {
      _add(SpikeResult(title: '② ツリー権限', ok: false, detail: '選択に失敗: $error'));
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('[T8] 改名できるかの確認')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '選んだファイルの名前の末尾に "_t8" を付けます(拡張子は保ちます)。\n'
              'テスト用のファイルで試してください。結果をそのまま報告してください。',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _checkDocumentUri,
              child: const Text('① ファイルを選んで改名(導線 B の前提)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _checkTreeUri,
              child: const Text('② フォルダを選んで先頭の1件を改名(比較)'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = _results[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      border: Border.all(
                        color: r.ok ? colors.success : colors.danger,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.ok ? '✅' : '❌'} ${r.title}',
                          style: TextStyle(
                            color: r.ok ? colors.success : colors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          r.detail,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
