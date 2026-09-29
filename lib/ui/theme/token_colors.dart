import 'package:flutter/material.dart';

import '../../core/rename_engine.dart';
import '../rule_builder/token_presets.dart';

/// トークンの種類ごとの色(008:T45)。
///
/// 参考デザイン `docs/design/Bulk Renamer.html` の tokenChips の色相をそのまま
/// 使う(区切り=黄、元名=灰、テキスト=シアン、連番=緑、日時=紫)。チップの面は
/// この色を薄く敷き、枠と種類名はやや濃く使う。意味の色([AppColors] の
/// success / danger など)とは別の、種類を見分けるためだけの色である。
Color tokenHue(Token token) => switch (token) {
  OriginalNameToken() => const Color(0xFF94A3B8),
  LiteralToken(:final value) =>
    separatorPresets.contains(value)
        ? const Color(0xFFFBBF24)
        : const Color(0xFF22D3EE),
  SequenceToken() => const Color(0xFF4ADE80),
  DateTimeToken() => const Color(0xFFC084FC),
};
