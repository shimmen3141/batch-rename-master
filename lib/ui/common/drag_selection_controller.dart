import 'dart:async';

import 'package:flutter/material.dart';

/// 長押しdrag選択に共通するpointer・実在行・edge scrollの調停。
///
/// **選択の意味は所有しない。** [select] / [deselect]へ通過itemを通知するだけなので、
/// メイン一覧の「外す候補」とbrowserの「読み込むfile」を同じ状態へ混ぜない。
class DragSelectionController<T> {
  DragSelectionController({
    required this.scrollController,
    required this.viewportKey,
    required this.select,
    required this.deselect,
    required this.isMounted,
    this.displayOrder,
    this.autoScrollEdgeExtent = 48,
    this.autoScrollStep = 4,
    this.maxAutoScrollMultiplier = 4,
  });

  final ScrollController scrollController;
  final GlobalKey viewportKey;
  final void Function(T item) select;
  final void Function(T item) deselect;
  final bool Function() isMounted;

  /// 表示順。渡すと**開始 item から指の下の item までの表示順の範囲**を選ぶ
  /// (004 REQ-023。写真・動画の格子)。
  ///
  /// `null` なら**指が通った行**を選ぶ(1列の一覧。002 REQ-018 / 004 REQ-020)。
  /// 格子では指が縦に動くと1列しか通らないので、範囲で選ぶ必要がある。
  final List<T> Function()? displayOrder;
  final double autoScrollEdgeExtent;
  final double autoScrollStep;
  final double maxAutoScrollMultiplier;

  final Map<T, GlobalKey> _rowGeometryKeys = <T, GlobalKey>{};
  final Map<int, Offset> _pointerPositions = <int, Offset>{};

  _DragSession<T>? _session;
  int? _activePointer;
  Timer? _autoScrollTimer;
  double _autoScrollPixelsPerTick = 0;
  bool _traceAfterScrollPending = false;

  /// itemの実描画矩形を登録するkey。固定行高を仮定しない。
  GlobalKey rowGeometryKey(T item) =>
      _rowGeometryKeys.putIfAbsent(item, GlobalKey.new);

  /// 行の長押しが成立した時点から、同じpointerを親Listenerで追跡する。
  void start(T item, Offset position, {required Set<T> baseline}) {
    final pointer = _nearestPointerTo(position);
    finish();
    _activePointer = pointer;
    final session = displayOrder == null
        ? _DragSelectionPath<T>(baseline, position)
        : _DragSelectionRange<T>(baseline, position, anchor: item);
    _session = session;
    session.visit(item, select: select, deselect: deselect);
    _updateAutoScroll(position);
  }

  void onPointerDown(PointerDownEvent event) {
    _pointerPositions[event.pointer] = event.position;
  }

  void onPointerMove(PointerMoveEvent event) {
    _pointerPositions[event.pointer] = event.position;
    if (event.pointer != _activePointer) return;
    final session = _session;
    if (session == null) return;
    _traceSelection(session, event.position);
    _updateAutoScroll(event.position);
  }

  void onPointerUp(PointerUpEvent event) {
    _pointerPositions.remove(event.pointer);
    if (event.pointer == _activePointer) finish();
  }

  void onPointerCancel(PointerCancelEvent event) {
    _pointerPositions.remove(event.pointer);
    if (event.pointer == _activePointer) finish();
  }

  void finish() {
    _session = null;
    _activePointer = null;
    _stopAutoScroll();
  }

  /// 登録した item の位置の key をすべて捨てる。並ぶ item が丸ごと入れ替わるとき
  /// (写真・動画の絞り込みの切り替え)に呼ぶ。描画中の item は次の build で
  /// [rowGeometryKey] が登録し直す。
  void forgetRows() => _rowGeometryKeys.clear();

  /// 登録している item の位置の key の数。
  @visibleForTesting
  int get rowCount => _rowGeometryKeys.length;

  void dispose() {
    finish();
    _pointerPositions.clear();
    _rowGeometryKeys.clear();
  }

  int? _nearestPointerTo(Offset position) {
    int? result;
    var distance = double.infinity;
    for (final entry in _pointerPositions.entries) {
      final candidate = (entry.value - position).distanceSquared;
      if (candidate < distance) {
        result = entry.key;
        distance = candidate;
      }
    }
    return result;
  }

  void _traceSelection(_DragSession<T> session, Offset position) {
    if (session is _DragSelectionRange<T>) {
      // **item の間(見出し・余白)では範囲を変えない。** 直前の範囲を保つ。
      final item = _itemAt(position);
      if (item != null) {
        session.extendTo(
          item,
          displayOrder!(),
          select: select,
          deselect: deselect,
        );
      }
    } else if (session is _DragSelectionPath<T>) {
      for (final crossing in _rowsCrossed(session.pointer, position)) {
        session.visit(crossing.item, select: select, deselect: deselect);
      }
    }
    session.pointer = position;
  }

  /// [position] の下にある item。描画されている item の実矩形で決める。
  T? _itemAt(Offset position) {
    for (final entry in _rowGeometryKeys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final origin = renderObject.localToGlobal(Offset.zero);
      if ((origin & renderObject.size).contains(position)) return entry.key;
    }
    return null;
  }

  List<_RowCrossing<T>> _rowsCrossed(Offset from, Offset to) {
    final crossings = <_RowCrossing<T>>[];
    for (final entry in _rowGeometryKeys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final origin = renderObject.localToGlobal(Offset.zero);
      final t = _segmentEntry(
        Rect.fromLTWH(
          origin.dx,
          origin.dy,
          renderObject.size.width,
          renderObject.size.height,
        ),
        from,
        to,
      );
      if (t != null) crossings.add(_RowCrossing<T>(entry.key, t));
    }
    crossings.sort((a, b) => a.t.compareTo(b.t));
    return crossings;
  }

  void _updateAutoScroll(Offset position) {
    final viewport = _viewportRect;
    if (viewport == null ||
        position.dx < viewport.left ||
        position.dx > viewport.right) {
      _stopAutoScroll();
      return;
    }
    final aboveTopEdge = viewport.top + autoScrollEdgeExtent - position.dy;
    final belowBottomEdge =
        position.dy - (viewport.bottom - autoScrollEdgeExtent);
    _autoScrollPixelsPerTick = aboveTopEdge > 0
        ? -_scrollStepForDepth(aboveTopEdge)
        : (belowBottomEdge > 0 ? _scrollStepForDepth(belowBottomEdge) : 0);
    if (_autoScrollPixelsPerTick == 0 ||
        !_canAutoScroll(_autoScrollPixelsPerTick)) {
      _stopAutoScroll();
      return;
    }
    _autoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _autoScrollTick(),
    );
  }

  double _scrollStepForDepth(double depth) =>
      autoScrollStep *
      (depth / autoScrollEdgeExtent).clamp(1, maxAutoScrollMultiplier);

  Rect? get _viewportRect {
    final renderObject = viewportKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    final origin = renderObject.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      origin.dx,
      origin.dy,
      renderObject.size.width,
      renderObject.size.height,
    );
  }

  bool _canAutoScroll(double direction) {
    if (!scrollController.hasClients) return false;
    final position = scrollController.position;
    return direction < 0
        ? position.pixels > position.minScrollExtent
        : position.pixels < position.maxScrollExtent;
  }

  void _autoScrollTick() {
    final session = _session;
    if (session == null || !_canAutoScroll(_autoScrollPixelsPerTick)) {
      _stopAutoScroll();
      return;
    }
    final position = scrollController.position;
    final next = (position.pixels + _autoScrollPixelsPerTick).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) {
      _stopAutoScroll();
      return;
    }
    scrollController.jumpTo(next);
    if (_traceAfterScrollPending) return;
    _traceAfterScrollPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _traceAfterScrollPending = false;
      if (isMounted() && identical(session, _session)) {
        _traceSelection(session, session.pointer);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollPixelsPerTick = 0;
  }
}

/// 1回の長押し drag。
sealed class _DragSession<T> {
  _DragSession(Set<T> baseline, this.pointer) : _baseline = Set<T>.of(baseline);

  /// drag 開始前から選択済みだった item。**drag はこれを解除しない。**
  final Set<T> _baseline;
  Offset pointer;

  void visit(
    T item, {
    required void Function(T item) select,
    required void Function(T item) deselect,
  });
}

/// 表示順で開始 item から今の item までの範囲を選ぶ(004 REQ-023)。
///
/// 範囲が縮んだら、**この drag が足した item だけ**を解除する。
final class _DragSelectionRange<T> extends _DragSession<T> {
  _DragSelectionRange(super.baseline, super.pointer, {required this.anchor});

  final T anchor;
  Set<T> _range = <T>{};

  @override
  void visit(
    T item, {
    required void Function(T item) select,
    required void Function(T item) deselect,
  }) {
    _range = {item};
    select(item);
  }

  void extendTo(
    T end,
    List<T> order, {
    required void Function(T item) select,
    required void Function(T item) deselect,
  }) {
    final from = order.indexOf(anchor);
    final to = order.indexOf(end);
    if (from < 0 || to < 0) return;
    final next = order
        .sublist(from < to ? from : to, (from < to ? to : from) + 1)
        .toSet();
    for (final left in _range.difference(next)) {
      if (!_baseline.contains(left)) deselect(left);
    }
    for (final entered in next.difference(_range)) {
      select(entered);
    }
    _range = next;
  }
}

/// 指が通った行を選ぶ(1列の一覧)。
final class _DragSelectionPath<T> extends _DragSession<T> {
  _DragSelectionPath(super.baseline, super.pointer);

  final List<T> _path = <T>[];

  @override
  void visit(
    T item, {
    required void Function(T item) select,
    required void Function(T item) deselect,
  }) {
    final previous = _path.lastIndexOf(item);
    if (previous >= 0) {
      final leaving = _path.sublist(previous + 1);
      _path.removeRange(previous + 1, _path.length);
      for (final left in leaving) {
        if (!_baseline.contains(left)) deselect(left);
      }
      return;
    }
    _path.add(item);
    select(item);
  }
}

class _RowCrossing<T> {
  const _RowCrossing(this.item, this.t);

  final T item;
  final double t;
}

/// 線分がrectへ初めて入る比率。行高を仮定せず実描画矩形だけを使う。
double? _segmentEntry(Rect rect, Offset from, Offset to) {
  var first = 0.0;
  var last = 1.0;
  final dx = to.dx - from.dx;
  final dy = to.dy - from.dy;

  bool clip(double direction, double distance) {
    if (direction == 0) return distance >= 0;
    final ratio = distance / direction;
    if (direction < 0) {
      if (ratio > last) return false;
      if (ratio > first) first = ratio;
    } else {
      if (ratio < first) return false;
      if (ratio < last) last = ratio;
    }
    return true;
  }

  if (!clip(-dx, from.dx - rect.left) ||
      !clip(dx, rect.right - from.dx) ||
      !clip(-dy, from.dy - rect.top) ||
      !clip(dy, rect.bottom - from.dy)) {
    return null;
  }
  return first;
}
