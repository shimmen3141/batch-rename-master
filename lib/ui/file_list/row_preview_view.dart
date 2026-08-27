import 'package:flutter/material.dart';

import '../../core/file_entry.dart';
import '../../data/preview/file_preview.dart';
import '../theme/app_colors.dart';
import 'file_type_icon.dart';

/// 行の左に出す preview(008:T07)。
///
/// **preview は「あれば出る」ものとして扱う。** 取れないとき・まだ届かないとき・
/// 読めなかったときは種別アイコンを出し、行の高さも位置も変えない。**待っている
/// 間に spinner を出さない** — 行ごとに回る spinner は一覧を落ち着かなく見せる
/// うえ、多くの file では数十 ms で置き換わる。
///
/// [preview] が `null` なら要求そのものを行わない(demo データやこの widget を
/// 使わない画面のため)。
class RowPreviewView extends StatefulWidget {
  const RowPreviewView({
    super.key,
    required this.file,
    required this.preview,
    this.size = 40,
  });

  final FileEntry file;

  /// preview の供給元。`null` なら種別アイコンだけを出す。
  final FilePreviewPort? preview;

  /// 一辺の論理 px。
  final double size;

  @override
  State<RowPreviewView> createState() => _RowPreviewViewState();
}

class _RowPreviewViewState extends State<RowPreviewView> {
  PreviewResult? _result;

  /// 進行中の要求を識別する。応答が返ったとき、**その要求がまだ最新か**を確かめる
  /// ために使う。scroll で行が別の file を指した後に古い応答が届くと、別の file の
  /// 絵が出てしまう。
  Object? _pending;

  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // **initState では要求しない。** 実 px を決めるのに `MediaQuery` が要り、
    // それを読めるのはここからである。
    if (_requested) return;
    _requested = true;
    _request();
  }

  @override
  void didUpdateWidget(RowPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同じ位置の行が別の file を指したら作り直す。
    if (oldWidget.file.sourceHandle != widget.file.sourceHandle ||
        oldWidget.file.name != widget.file.name ||
        oldWidget.preview != widget.preview ||
        oldWidget.size != widget.size) {
      setState(() => _result = null);
      _request();
    }
  }

  Future<void> _request() async {
    final port = widget.preview;
    if (port == null) {
      _pending = null;
      return;
    }
    final token = Object();
    _pending = token;
    // 論理 px ではなく実 px で要求する(高密度の端末で粗くならないように)。
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final result = await port.thumbnail(
      widget.file,
      maxEdge: (widget.size * ratio).round(),
    );
    // 途中で行が別の file を指した、または widget が外れた。
    if (!mounted || !identical(_pending, token)) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final result = _result;
    return SizedBox(
      key: rowPreviewKey,
      width: widget.size,
      height: widget.size,
      child: switch (result) {
        PreviewReady(:final thumbnail) => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            thumbnail,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // decode 済みの thumbnail なので、ここで更に縮めない。
            errorBuilder: (context, error, stack) =>
                _icon(Icons.broken_image_outlined, colors.textMuted),
          ),
        ),
        // 読めなかった行は、preview の無い行と**別のアイコン**にする。改名でも
        // 触れない file である可能性があり、黙って同じ見た目にしない。
        PreviewFailed() => _icon(Icons.broken_image_outlined, colors.textMuted),
        // 対象外(文書・書庫、退避中の SAF ハンドル)と、まだ届いていない行。
        PreviewUnsupported() ||
        null => _icon(fileTypeIconOf(widget.file.name), colors.textMuted),
      },
    );
  }

  Widget _icon(IconData icon, Color color) => Center(
    child: Icon(icon, size: widget.size * 0.55, color: color),
  );
}

/// 行の preview 枠。**preview の有無に関わらず必ず在る**(行の高さが揺れない)。
const Key rowPreviewKey = Key('row-preview');
