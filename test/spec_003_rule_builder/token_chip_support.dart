// 008:T45 でチップの見た目を参考デザイン(種類名 + 1件目での値)へ変えた。
// testは従来どおりトークンの説明(`連番(2桁)`・`日時 YYYYMMDD` など。tokenLabel)で
// チップを指す。説明は `TokenChip.description` として残り、読み上げにも使われる。
import 'package:batch_rename_master/ui/rule_builder/rule_builder_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// 説明が [description] のトークンのチップ。
Finder tokenChip(String description) => find.byWidgetPredicate(
  (w) => w is TokenChip && w.description == description,
  description: 'TokenChip($description)',
);
