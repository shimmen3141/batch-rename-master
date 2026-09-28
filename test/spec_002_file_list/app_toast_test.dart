// 008:T25 通知(toast)を自分で閉じられるようにする。
//
// 観点: すべての通知に右上の閉じる円が出て、押すと消える。閉じる円と本文側の操作
// (「元に戻す」)は**別の当たり判定**である。重大度は先頭のアイコンと左端の色帯で
// 示す(面の色は変えない)。狭い幅・大きい文字でも崩れない。
//
// **何を伝えるか・いつ出すかは各spec**(002 REQ-017、004 REQ-008/011/012、005)で、
// その通知が実際にこの形で出ることは各specのtestが見る。
import 'package:batch_rename_master/ui/common/app_toast.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _toastKey = Key('toast-under-test');

/// 押すと [show] を呼ぶ button だけの画面。
Future<void> _pump(
  WidgetTester tester,
  void Function(ScaffoldMessengerState messenger) show,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const Key('show'),
              onPressed: () => show(ScaffoldMessenger.of(context)),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('show')));
  await tester.pumpAndSettle();
}

final _colors = appDarkTheme().extension<AppColors>()!;

void main() {
  testWidgets('閉じる円を押すと通知が消える', (tester) async {
    await _pump(
      tester,
      (m) => showAppToast(
        m,
        key: _toastKey,
        tone: ToastTone.success,
        content: const Text('3 件を改名しました'),
        persist: true,
      ),
    );
    expect(find.byKey(_toastKey), findsOneWidget);

    await tester.tap(find.byKey(toastCloseKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_toastKey), findsNothing);
  });

  testWidgets('閉じる円は支援技術から「通知を閉じる」として押せる', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      (m) => showAppToast(
        m,
        key: _toastKey,
        tone: ToastTone.info,
        content: const Text('案内'),
        persist: true,
      ),
    );

    expect(find.byTooltip('通知を閉じる'), findsOneWidget);
    tester.semantics.tap(
      find.semantics.byPredicate((node) => node.tooltip == '通知を閉じる'),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_toastKey), findsNothing);
    semantics.dispose();
  });

  for (final (tone, icon, color) in [
    (ToastTone.success, Icons.check, _colors.success),
    (ToastTone.info, Icons.info_outline, _colors.info),
    (ToastTone.danger, Icons.error_outline, _colors.danger),
  ]) {
    testWidgets('重大度 $tone はアイコンと左端の色帯で示し、面の色は同じ', (tester) async {
      await _pump(
        tester,
        (m) => showAppToast(
          m,
          key: _toastKey,
          tone: tone,
          content: const Text('本文'),
        ),
      );

      final toneIcon = tester.widget<Icon>(find.byKey(toastToneIconKey(tone)));
      expect(toneIcon.icon, icon);
      expect(toneIcon.color, color);
      expect(
        tester.widget<ColoredBox>(find.byKey(toastToneBandKey)).color,
        color,
      );
      // **面は重大度に依らず同じ**(2026-09-28 の決定。全面を塗らない)。
      final surfaces = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(AppToastCard),
              matching: find.byType(ColoredBox),
            ),
          )
          .map((box) => box.color);
      expect(surfaces, contains(_colors.surfaceElevated));
      expect(
        tester.widget<SnackBar>(find.byKey(_toastKey)).backgroundColor,
        Colors.transparent,
      );
    });
  }

  testWidgets('「元に戻す」と閉じる円は別の当たり判定で、それぞれ別のことが起きる', (tester) async {
    var undone = 0;
    await _pump(
      tester,
      (m) => showAppToast(
        m,
        key: _toastKey,
        tone: ToastTone.success,
        content: const Text('2 件を一覧から外しました'),
        persist: true,
        action: ToastAction(
          key: const Key('undo'),
          label: '元に戻す',
          onPressed: () => undone++,
        ),
      ),
    );

    final close = tester.getRect(find.byKey(toastCloseKey));
    final undo = tester.getRect(find.byKey(const Key('undo')));
    expect(close.overlaps(undo), isFalse, reason: '押し間違いで取り消しを失わない');

    // 閉じる円は取り消さない。
    await tester.tap(find.byKey(toastCloseKey));
    await tester.pumpAndSettle();
    expect(undone, 0);
    expect(find.byKey(_toastKey), findsNothing);
  });

  testWidgets('「元に戻す」を押すと、操作が1回だけ走り通知が下がる', (tester) async {
    var undone = 0;
    await _pump(
      tester,
      (m) => showAppToast(
        m,
        key: _toastKey,
        tone: ToastTone.success,
        content: const Text('3 件を改名しました'),
        action: ToastAction(label: '元に戻す', onPressed: () => undone++),
      ),
    );

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    expect(undone, 1);
    expect(find.byKey(_toastKey), findsNothing);
  });

  testWidgets('既定では自動で消え、persist なら閉じるまで残る', (tester) async {
    await _pump(
      tester,
      (m) => showAppToast(
        m,
        key: _toastKey,
        tone: ToastTone.info,
        content: const Text('自動で消える'),
        duration: const Duration(seconds: 2),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(_toastKey), findsNothing);

    await tester.tap(find.byKey(const Key('show')));
    await tester.pumpAndSettle();
    // 上の _pump の show は persist なしなので、ここで persist ありを出し直す。
    final messenger = tester.state<ScaffoldMessengerState>(
      find.byType(ScaffoldMessenger),
    );
    showAppToast(
      messenger,
      key: const Key('persist'),
      tone: ToastTone.success,
      content: const Text('残る'),
      persist: true,
      replaceCurrent: true,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('persist')), findsOneWidget);
  });

  testWidgets('閉じる円はカードの角へ一部重なり、全体が当たり判定に入る', (tester) async {
    await _pump(
      tester,
      (m) => showAppToast(
        m,
        key: _toastKey,
        tone: ToastTone.success,
        content: const Text('3 件を改名しました'),
        persist: true,
      ),
    );

    final card = tester.getRect(
      find
          .descendant(
            of: find.byType(AppToastCard),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final close = tester.getRect(find.byKey(toastCloseKey));
    // 円の中心はカードの右上の角の近く — 一部がカードの外、一部が中。
    expect(close.center.dx, closeTo(card.right, 6));
    expect(close.center.dy, closeTo(card.top, 6));
    expect(close.overlaps(card), isTrue, reason: 'カードへ一部重なる');
    expect(card.contains(close.topRight), isFalse, reason: 'カードから少しはみ出す');
    // **はみ出した部分も押せる**(親の範囲の外にしない)。
    await tester.tapAt(close.topRight + const Offset(-3, 3));
    await tester.pumpAndSettle();
    expect(find.byKey(_toastKey), findsNothing);
  });

  testWidgets('狭い幅・大きい文字でも、はみ出さず操作が押せる', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: appDarkTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const Key('show'),
                onPressed: () => showAppToast(
                  ScaffoldMessenger.of(context),
                  key: _toastKey,
                  tone: ToastTone.danger,
                  content: const Text(
                    '「すべてのファイルへのアクセス」が許可されていないため、名前を変更できませんでした。'
                    '端末の設定で許可してから、もう一度お試しください。',
                  ),
                  persist: true,
                  action: ToastAction(label: '元に戻す', onPressed: () {}),
                ),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('show')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'overflow を出さない');
    final screen = tester.getRect(find.byType(Scaffold));
    for (final finder in [
      find.byKey(toastCloseKey),
      find.text('元に戻す'),
      find.byType(AppToastCard),
    ]) {
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(screen.left));
      expect(rect.right, lessThanOrEqualTo(screen.right));
    }
    expect(
      tester
          .getRect(find.byKey(toastCloseKey))
          .overlaps(tester.getRect(find.text('元に戻す'))),
      isFalse,
    );
  });
}
