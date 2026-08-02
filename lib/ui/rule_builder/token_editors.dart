import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../theme/app_colors.dart';
import 'token_presets.dart';

/// [token] の詳細エディタを開き、確定された新しい [Token] を返す。
///
/// キャンセル時と、設定項目の無い [OriginalNameToken] では `null` を返す
/// (呼び出し側は null のとき差し替えを行わない)。エディタはボトムシートで表示する。
Future<Token?> showTokenEditor(BuildContext context, Token token) {
  if (token is OriginalNameToken) return Future<Token?>.value(null);
  return showModalBottomSheet<Token>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: switch (token) {
        LiteralToken() => _LiteralEditor(token: token),
        SequenceToken() => _SequenceEditor(token: token),
        DateTimeToken() => _DateTimeEditor(token: token),
        OriginalNameToken() => const SizedBox.shrink(),
      },
    ),
  );
}

/// エディタ共通の枠(タイトル・本文・キャンセル/確定)。
///
/// [onConfirm] が null のとき確定ボタンは無効化される（自由テキストの空不可など）。
class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({
    required this.title,
    required this.children,
    required this.onConfirm,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'キャンセル',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor: colors.surfaceElevated,
                    disabledForegroundColor: colors.textDisabled,
                  ),
                  child: const Text('確定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 自由テキスト / 区切り（どちらも [LiteralToken]）のエディタ。
///
/// 文字列を入力するか区切りプリセットを選ぶ。空のあいだ確定は無効（空不可）。
class _LiteralEditor extends StatefulWidget {
  const _LiteralEditor({required this.token});

  final LiteralToken token;

  @override
  State<_LiteralEditor> createState() => _LiteralEditorState();
}

class _LiteralEditorState extends State<_LiteralEditor> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.token.value,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final empty = _ctrl.text.isEmpty;
    return _EditorScaffold(
      title: 'テキスト / 区切り',
      onConfirm: empty
          ? null
          : () => Navigator.pop(context, LiteralToken(_ctrl.text)),
      children: [
        TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: colors.textPrimary),
          decoration: const InputDecoration(
            labelText: '文字列',
            hintText: '例: _ , ファイル',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '区切りプリセット',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final preset in separatorPresets)
              ActionChip(
                label: Text(_separatorLabel(preset)),
                onPressed: () => setState(() => _ctrl.text = preset),
              ),
          ],
        ),
      ],
    );
  }
}

String _separatorLabel(String preset) => switch (preset) {
  '-' => '-（ハイフン）',
  '_' => '_（アンダーバー）',
  ' ' => '␣（半角空白）',
  '　' => '␣（全角空白）',
  _ => preset,
};

/// 連番（[SequenceToken]）のエディタ。start ≥ 0・digits ≥ 1・increment ≥ 1。
class _SequenceEditor extends StatefulWidget {
  const _SequenceEditor({required this.token});

  final SequenceToken token;

  @override
  State<_SequenceEditor> createState() => _SequenceEditorState();
}

class _SequenceEditorState extends State<_SequenceEditor> {
  late int _start = widget.token.start;
  late int _digits = widget.token.digits;
  late int _increment = widget.token.increment;

  @override
  Widget build(BuildContext context) {
    return _EditorScaffold(
      title: '連番',
      onConfirm: () => Navigator.pop(
        context,
        SequenceToken(start: _start, digits: _digits, increment: _increment),
      ),
      children: [
        _NumberStepper(
          label: '開始番号',
          value: _start,
          min: 0,
          onChanged: (v) => setState(() => _start = v),
        ),
        _NumberStepper(
          label: '桁数（ゼロ埋め）',
          value: _digits,
          min: 1,
          onChanged: (v) => setState(() => _digits = v),
        ),
        _NumberStepper(
          label: '増分',
          value: _increment,
          min: 1,
          onChanged: (v) => setState(() => _increment = v),
        ),
      ],
    );
  }
}

/// 数値を下限つきで増減するステッパー（負の入力を型で排除する）。
class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: colors.textSecondary,
            tooltip: '減らす',
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline),
            color: colors.primary,
            tooltip: '増やす',
          ),
        ],
      ),
    );
  }
}

/// 日時（[DateTimeToken]）のエディタ。基準の選択＋フォーマット（プリセット＋自由入力）。
class _DateTimeEditor extends StatefulWidget {
  const _DateTimeEditor({required this.token});

  final DateTimeToken token;

  @override
  State<_DateTimeEditor> createState() => _DateTimeEditorState();
}

class _DateTimeEditorState extends State<_DateTimeEditor> {
  late DateTimeSource _source = widget.token.source;
  late final TextEditingController _fmt = TextEditingController(
    text: widget.token.format,
  );

  static const List<(DateTimeSource, String)> _sources = [
    (DateTimeSource.created, '作成日時'),
    (DateTimeSource.modified, '更新日時'),
    (DateTimeSource.current, '現在日時'),
  ];

  @override
  void dispose() {
    _fmt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final empty = _fmt.text.isEmpty;
    return _EditorScaffold(
      title: '日時',
      onConfirm: empty
          ? null
          : () => Navigator.pop(
              context,
              DateTimeToken(source: _source, format: _fmt.text),
            ),
      children: [
        Text('基準', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final (source, label) in _sources)
              ChoiceChip(
                label: Text(label),
                selected: _source == source,
                onSelected: (_) => setState(() => _source = source),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fmt,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: colors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'フォーマット',
            hintText: '例: YYYYMMDD, YYYY年MM月DD日',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'プリセット',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final preset in dateTimePresets)
              ActionChip(
                label: Text(preset),
                onPressed: () => setState(() => _fmt.text = preset),
              ),
          ],
        ),
      ],
    );
  }
}
