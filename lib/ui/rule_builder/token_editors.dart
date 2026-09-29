import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../theme/app_colors.dart';
import 'token_presets.dart';

/// トークンのエディタ(ダイアログの中身)の key。
const Key tokenEditorKey = Key('token-editor');

/// 連番のエディタのゼロ埋めの切り替え(003 REQ-013)。
const Key sequenceZeroPadKey = Key('sequence-zero-pad');

/// 連番のエディタの桁数の下限の説明(003 REQ-014)。
const Key sequenceMinDigitsKey = Key('sequence-min-digits');

/// エディタの表示例(参考デザインの「表示例」。008:T44)。
const Key tokenEditorExampleKey = Key('token-editor-example');

/// 日時のフォーマットを詳しく書く入力欄(「詳細に記述」を選んだときだけ出る。008:T44)。
const Key dateTimeFormatFieldKey = Key('date-time-format-field');

/// 日時のフォーマットの「詳細に記述」のチップの文言。
const String dateTimeCustomFormatLabel = '詳細に記述';

/// エディタの高さが変わるときのアニメーションの長さ(008:T44。開発者の要望)。
const Duration tokenEditorResizeDuration = Duration(milliseconds: 220);

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

/// 文字列トークンのエディタをどの入口から開いたか(見出しと説明を変えるだけ)。
///
/// 003 REQ-011 により、`LiteralToken` は自由テキストと区切りのどちらから入ったかを
/// 持たないので、編集では両方を兼ねる見出しにする。どの入口でも文字列の入力と
/// 記号の選択の両方ができる(追加時に見せ方を分けることは REQ-011 が妨げない)。
enum LiteralEntry { freeText, separator, edit }

/// [token] を初期値にしたエディタを開き、確定された新しい [Token] を返す。
///
/// 確定以外で閉じたとき(キャンセル・戻る操作・ダイアログの外のタップ)と、設定
/// 項目の無い [OriginalNameToken] では `null` を返す。呼び出し側は null のとき列を
/// 変えない(003 REQ-008 / REQ-009 / REQ-011)。エディタは参考デザイン
/// (`docs/design/Bulk Renamer.html`)どおり**中央のダイアログ**で表示する(008:T44。
/// 以前はボトムシート)。追加と編集で同じエディタを使い、確定ボタンの文言だけを
/// [confirmLabel] で変える。
///
/// [itemCount] は一覧の件数で、連番の桁数の下限と表示例に使う(003 REQ-014)。
/// [sampleFile] は一覧の1件目で、日時の表示例に使う(無ければ表示例を出さない)。
Future<Token?> showTokenEditor(
  BuildContext context,
  Token token, {
  String confirmLabel = '確定',
  int itemCount = 0,
  FileEntry? sampleFile,
  LiteralEntry literalEntry = LiteralEntry.edit,
}) {
  if (token is OriginalNameToken) return Future<Token?>.value(null);
  return showDialog<Token>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xA8000000),
    builder: (context) => switch (token) {
      LiteralToken() => _LiteralEditor(
        token: token,
        confirmLabel: confirmLabel,
        entry: literalEntry,
      ),
      SequenceToken() => _SequenceEditor(
        token: token,
        confirmLabel: confirmLabel,
        itemCount: itemCount,
      ),
      DateTimeToken() => _DateTimeEditor(
        token: token,
        confirmLabel: confirmLabel,
        sampleFile: sampleFile,
      ),
      OriginalNameToken() => const SizedBox.shrink(),
    },
  );
}

/// エディタ共通の枠(見出し・説明・本文・表示例・キャンセル/確定)。
///
/// 参考デザインのダイアログ: 角丸18・枠線のカードに、見出しと説明、入力、区切り線の
/// 下に緑の表示例、区切り線の下にキャンセルと確定を横に並べる。
/// [onConfirm] が null のとき確定ボタンは無効化される（自由テキストの空不可など）。
class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({
    required this.title,
    required this.description,
    required this.children,
    required this.onConfirm,
    required this.confirmLabel,
    this.exampleLabel,
    this.example,
  });

  final String title;
  final String description;
  final String confirmLabel;
  final List<Widget> children;
  final VoidCallback? onConfirm;

  /// 表示例の見出しと値。どちらかが null なら表示例を出さない。
  final String? exampleLabel;
  final String? example;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final divider = BorderSide(color: Colors.white.withValues(alpha: 0.07));
    return Dialog(
      key: tokenEditorKey,
      insetPadding: const EdgeInsets.all(26),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        // ゼロ埋めの切り替えや日時の入力欄の出し入れで高さが変わる。変わること
        // 自体はよいが、急に変わらないよう滑らかにする(008:T44。開発者の要望)。
        child: AnimatedSize(
          duration: tokenEditorResizeDuration,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...children,
                      if (exampleLabel != null && example != null)
                        Container(
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.only(top: 13),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exampleLabel!,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                example!,
                                key: tokenEditorExampleKey,
                                style: TextStyle(
                                  color: colors.success,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  decoration: BoxDecoration(border: Border(top: divider)),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 10,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: colors.surfaceElevated,
                            foregroundColor: colors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: const Text('キャンセル'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 13,
                        child: FilledButton(
                          onPressed: onConfirm,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            disabledBackgroundColor: colors.surfaceElevated,
                            disabledForegroundColor: colors.textDisabled,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: Text(confirmLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 選択肢の群(参考デザインの「基準」「フォーマット」「記号」)。見出しは小さい
/// 等幅の字で、下にチップを並べる。
class _OptionGroup extends StatelessWidget {
  const _OptionGroup({required this.label, required this.options});

  final String label;
  final List<Widget> options;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(spacing: 6, runSpacing: 6, children: options),
        ],
      ),
    );
  }
}

/// 参考デザインのチップ(選ばれているものはシアンの枠と文字)。
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? colors.primary : colors.textSecondary,
        fontSize: 11.5,
        fontFamily: 'monospace',
      ),
      backgroundColor: colors.background,
      selectedColor: colors.primary.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected
            ? colors.primary.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.1),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}

/// 入力欄(参考デザインの暗い面にシアンの枠)。
InputDecoration _fieldDecoration(AppColors colors, {String? hintText}) {
  OutlineInputBorder border(double alpha) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: colors.primary.withValues(alpha: alpha)),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: colors.textDisabled, fontSize: 13),
    filled: true,
    fillColor: colors.background,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    enabledBorder: border(0.35),
    focusedBorder: border(0.7),
  );
}

/// 自由テキスト / 区切り（どちらも [LiteralToken]）のエディタ。
///
/// 文字列を入力するか記号を選ぶ。空のあいだ確定は無効（空不可）。
class _LiteralEditor extends StatefulWidget {
  const _LiteralEditor({
    required this.token,
    required this.confirmLabel,
    required this.entry,
  });

  final LiteralToken token;
  final String confirmLabel;
  final LiteralEntry entry;

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
    final (title, description) = switch (widget.entry) {
      LiteralEntry.freeText => (
        '自由テキスト',
        '固定で挿入する文字列を入力します。\n区切り文字（"_"や"-"）も含められます。',
      ),
      LiteralEntry.separator => ('区切り文字', 'トークンの間に挟む記号を選びます。文字列も入力できます。'),
      LiteralEntry.edit => ('自由テキスト / 区切り文字', '固定で挿入する文字列です。記号から選ぶこともできます。'),
    };
    return _EditorScaffold(
      confirmLabel: widget.confirmLabel,
      title: title,
      description: description,
      onConfirm: empty
          ? null
          : () => Navigator.pop(context, LiteralToken(_ctrl.text)),
      children: [
        TextField(
          controller: _ctrl,
          autofocus: widget.entry != LiteralEntry.separator,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          decoration: _fieldDecoration(colors, hintText: '"作成資料" や "旅行_" など'),
        ),
        _OptionGroup(
          label: '記号',
          options: [
            for (final preset in separatorPresets)
              _OptionChip(
                label: _separatorLabel(preset),
                selected: _ctrl.text == preset,
                onSelected: () => setState(() => _ctrl.text = preset),
              ),
          ],
        ),
      ],
    );
  }
}

String _separatorLabel(String preset) => switch (preset) {
  '-' => 'ハイフン -',
  '_' => 'アンダーバー _',
  ' ' => '半角空白 ␣',
  '　' => '全角空白 ␣',
  _ => preset,
};

/// 連番（[SequenceToken]）のエディタ。start ≥ 0・increment ≥ 1。
///
/// ゼロ埋めの有無を切り替えられ(003 REQ-013)、ゼロ埋めなしのあいだは桁数を
/// 出さない(値は保持する)。ゼロ埋めありでは桁数を下限([sequenceMinDigits])より
/// 小さくできず、下回るときは**下限まで引き上げる** — 開いたとき(件数が後から
/// 増えた場合)と、開始番号・増分を変えたとき、ゼロ埋めへ戻したとき。下限を
/// 上回る値は自動で下げない(REQ-014)。引き上げはエディタの中だけで、確定する
/// までルールは変わらない(REQ-008 / REQ-011)。
class _SequenceEditor extends StatefulWidget {
  const _SequenceEditor({
    required this.token,
    required this.confirmLabel,
    required this.itemCount,
  });

  final SequenceToken token;
  final String confirmLabel;
  final int itemCount;

  @override
  State<_SequenceEditor> createState() => _SequenceEditorState();
}

class _SequenceEditorState extends State<_SequenceEditor> {
  late int _start = widget.token.start;
  late int _digits = widget.token.digits;
  late int _increment = widget.token.increment;
  late bool _zeroPad = widget.token.zeroPad;

  int get _minDigits => sequenceMinDigits(
    start: _start,
    increment: _increment,
    itemCount: widget.itemCount,
  );

  @override
  void initState() {
    super.initState();
    _raiseDigits();
  }

  /// 桁数が下限を下回っていれば下限まで上げる。ゼロ埋めなしのあいだは触らない。
  void _raiseDigits() {
    if (_zeroPad && _digits < _minDigits) _digits = _minDigits;
  }

  /// 入力中の値で [position] 番目に振られる文字列(001 REQ-003 と同じ描き方)。
  String _render(int position) {
    final value = _start + (position - 1) * _increment;
    return _zeroPad ? value.toString().padLeft(_digits, '0') : '$value';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = widget.itemCount;
    return _EditorScaffold(
      confirmLabel: widget.confirmLabel,
      title: '連番',
      description: 'リネームリスト一覧の上から順に番号を振ります。',
      exampleLabel: count > 1 ? '表示例（一覧の $count 件に上から順に振られます）' : '表示例',
      example: count > 1 ? '${_render(1)} ～ ${_render(count)}' : _render(1),
      onConfirm: () => Navigator.pop(
        context,
        SequenceToken(
          start: _start,
          digits: _digits,
          increment: _increment,
          zeroPad: _zeroPad,
        ),
      ),
      children: [
        SwitchListTile(
          key: sequenceZeroPadKey,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            'ゼロ埋め',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            _zeroPad ? '例: 001, 002 …' : '例: 1, 2 … 10',
            style: TextStyle(color: colors.textSecondary, fontSize: 11),
          ),
          value: _zeroPad,
          onChanged: (v) => setState(() {
            _zeroPad = v;
            _raiseDigits();
          }),
          activeThumbColor: Colors.white,
          activeTrackColor: colors.success,
          inactiveThumbColor: colors.textSecondary,
          inactiveTrackColor: colors.textMuted,
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        _NumberStepper(
          label: '開始番号',
          value: _start,
          min: 0,
          onChanged: (v) => setState(() {
            _start = v;
            _raiseDigits();
          }),
        ),
        if (_zeroPad) ...[
          _NumberStepper(
            label: '桁数',
            value: _digits,
            min: _minDigits,
            onChanged: (v) => setState(() => _digits = v),
          ),
          if (_minDigits > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _increment == 1
                    ? '${widget.itemCount}件・開始$_startなので$_minDigits桁以上'
                    : '${widget.itemCount}件・開始$_start・増分$_incrementなので'
                          '$_minDigits桁以上',
                key: sequenceMinDigitsKey,
                textAlign: TextAlign.end,
                style: TextStyle(color: colors.textSecondary, fontSize: 11),
              ),
            ),
        ],
        _NumberStepper(
          label: '増分',
          value: _increment,
          min: 1,
          onChanged: (v) => setState(() {
            _increment = v;
            _raiseDigits();
          }),
        ),
      ],
    );
  }
}

/// 数値を下限つきで増減するステッパー（負の入力を型で排除する）。
///
/// 参考デザイン: ラベル、枠のついた四角い −/＋、シアンの太い等幅の値。
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
    ButtonStyle style() => IconButton.styleFrom(
      backgroundColor: colors.background,
      disabledBackgroundColor: colors.background,
      foregroundColor: colors.textPrimary,
      disabledForegroundColor: colors.textDisabled,
      fixedSize: const Size(34, 34),
      minimumSize: const Size(34, 34),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 16),
            style: style(),
            tooltip: '減らす',
          ),
          SizedBox(
            width: 46,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add, size: 16),
            style: style(),
            tooltip: '増やす',
          ),
        ],
      ),
    );
  }
}

/// 日時（[DateTimeToken]）のエディタ。基準の選択＋フォーマット（プリセット＋自由入力）。
///
/// 自由入力の欄は「詳細に記述」のチップを選んだときだけ出す(008:T44。開発者の要望)。
class _DateTimeEditor extends StatefulWidget {
  const _DateTimeEditor({
    required this.token,
    required this.confirmLabel,
    required this.sampleFile,
  });

  final DateTimeToken token;
  final String confirmLabel;
  final FileEntry? sampleFile;

  @override
  State<_DateTimeEditor> createState() => _DateTimeEditorState();
}

class _DateTimeEditorState extends State<_DateTimeEditor> {
  late DateTimeSource _source = widget.token.source;
  late final TextEditingController _fmt = TextEditingController(
    text: widget.token.format,
  );

  /// 「詳細に記述」を選んでいるか。プリセットに無いフォーマットで開いたときは
  /// 選んだ状態で開く(入力欄にそのフォーマットが入っている)。
  late bool _custom = !dateTimePresets.contains(widget.token.format);

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

  /// 1つ目のファイルで描いた表示例と、その見出し。描けないときは null。
  (String, String)? _example() {
    final file = widget.sampleFile;
    if (file == null || _fmt.text.isEmpty) return null;
    final rendered = DateTimeToken(
      source: _source,
      format: _fmt.text,
    ).render(RenameContext(file: file, position: 1, now: DateTime.now()));
    final label = _source == DateTimeSource.current
        ? '表示例（現在日時）'
        : '表示例（1つ目のファイルの${_sources.firstWhere((e) => e.$1 == _source).$2}）';
    return (label, rendered.isEmpty ? '（日時が不明）' : rendered);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final empty = _fmt.text.isEmpty;
    final example = _example();
    return _EditorScaffold(
      confirmLabel: widget.confirmLabel,
      title: '日時',
      description: '基準となる日時とフォーマットを選んでください。',
      exampleLabel: example?.$1,
      example: example?.$2,
      onConfirm: empty
          ? null
          : () => Navigator.pop(
              context,
              DateTimeToken(source: _source, format: _fmt.text),
            ),
      children: [
        _OptionGroup(
          label: '基準',
          options: [
            for (final (source, label) in _sources)
              _OptionChip(
                label: label,
                selected: _source == source,
                onSelected: () => setState(() => _source = source),
              ),
          ],
        ),
        _OptionGroup(
          label: 'フォーマット',
          options: [
            for (final preset in dateTimePresets)
              _OptionChip(
                label: preset,
                selected: !_custom && _fmt.text == preset,
                onSelected: () => setState(() {
                  _custom = false;
                  _fmt.text = preset;
                }),
              ),
            // 選ぶと入力欄が出る。入力欄には直前に選ばれていたフォーマットが
            // そのまま入っている(開発者の要望)。
            _OptionChip(
              label: dateTimeCustomFormatLabel,
              selected: _custom,
              onSelected: () => setState(() => _custom = true),
            ),
          ],
        ),
        if (_custom) ...[
          const SizedBox(height: 10),
          TextField(
            key: dateTimeFormatFieldKey,
            controller: _fmt,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            decoration: _fieldDecoration(colors, hintText: 'YYYY年MM月DD日 など'),
          ),
        ],
      ],
    );
  }
}
