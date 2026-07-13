import 'package:flutter/material.dart';

/// Sendsar chat color + typography tokens. Resolved from [ThemeExtension].
@immutable
class SendsarChatTheme extends ThemeExtension<SendsarChatTheme> {
  const SendsarChatTheme({
    required this.border,
    required this.surface,
    required this.sidebarBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.bubbleSelf,
    required this.bubblePeer,
    required this.bubbleSelfText,
    required this.bubblePeerText,
    required this.online,
    required this.error,
    required this.connectingBg,
    required this.connectingBorder,
    required this.unreadBadge,
    required this.unreadBadgeText,
    required this.skeleton,
    required this.skeletonMuted,
  });

  final Color border;
  final Color surface;
  final Color sidebarBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color bubbleSelf;
  final Color bubblePeer;
  final Color bubbleSelfText;
  final Color bubblePeerText;
  final Color online;
  final Color error;
  final Color connectingBg;
  final Color connectingBorder;
  final Color unreadBadge;
  final Color unreadBadgeText;
  final Color skeleton;
  final Color skeletonMuted;

  static const light = SendsarChatTheme(
    border: Color(0xFFE2E8F0),
    surface: Color(0xFFFFFFFF),
    sidebarBg: Color(0xFFF8FAFC),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0xFFEFF6FF),
    bubbleSelf: Color(0xFF2563EB),
    bubblePeer: Color(0xFFF1F5F9),
    bubbleSelfText: Color(0xFFFFFFFF),
    bubblePeerText: Color(0xFF0F172A),
    online: Color(0xFF22C55E),
    error: Color(0xFFDC2626),
    connectingBg: Color(0xFFFFFBEB),
    connectingBorder: Color(0xFFFDE68A),
    unreadBadge: Color(0xFF2563EB),
    unreadBadgeText: Color(0xFFFFFFFF),
    skeleton: Color(0xFFE2E8F0),
    skeletonMuted: Color(0xFFF1F5F9),
  );

  static const dark = SendsarChatTheme(
    border: Color(0xFF334155),
    surface: Color(0xFF0F172A),
    sidebarBg: Color(0xFF1E293B),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    accent: Color(0xFF3B82F6),
    accentSoft: Color(0xFF1E3A5F),
    bubbleSelf: Color(0xFF2563EB),
    bubblePeer: Color(0xFF334155),
    bubbleSelfText: Color(0xFFFFFFFF),
    bubblePeerText: Color(0xFFF8FAFC),
    online: Color(0xFF22C55E),
    error: Color(0xFFF87171),
    connectingBg: Color(0xFF422006),
    connectingBorder: Color(0xFF78350F),
    unreadBadge: Color(0xFF3B82F6),
    unreadBadgeText: Color(0xFFFFFFFF),
    skeleton: Color(0xFF334155),
    skeletonMuted: Color(0xFF1E293B),
  );

  TextStyle get titleStyle => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  TextStyle get subtitleStyle => TextStyle(fontSize: 13, color: textMuted);

  TextStyle get typingStyle => TextStyle(
        fontSize: 13,
        color: accent,
        fontStyle: FontStyle.italic,
      );

  BoxDecoration get shellDecoration => BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: textPrimary.withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      );

  @override
  SendsarChatTheme copyWith({
    Color? border,
    Color? surface,
    Color? sidebarBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentSoft,
    Color? bubbleSelf,
    Color? bubblePeer,
    Color? bubbleSelfText,
    Color? bubblePeerText,
    Color? online,
    Color? error,
    Color? connectingBg,
    Color? connectingBorder,
    Color? unreadBadge,
    Color? unreadBadgeText,
    Color? skeleton,
    Color? skeletonMuted,
  }) {
    return SendsarChatTheme(
      border: border ?? this.border,
      surface: surface ?? this.surface,
      sidebarBg: sidebarBg ?? this.sidebarBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      bubbleSelf: bubbleSelf ?? this.bubbleSelf,
      bubblePeer: bubblePeer ?? this.bubblePeer,
      bubbleSelfText: bubbleSelfText ?? this.bubbleSelfText,
      bubblePeerText: bubblePeerText ?? this.bubblePeerText,
      online: online ?? this.online,
      error: error ?? this.error,
      connectingBg: connectingBg ?? this.connectingBg,
      connectingBorder: connectingBorder ?? this.connectingBorder,
      unreadBadge: unreadBadge ?? this.unreadBadge,
      unreadBadgeText: unreadBadgeText ?? this.unreadBadgeText,
      skeleton: skeleton ?? this.skeleton,
      skeletonMuted: skeletonMuted ?? this.skeletonMuted,
    );
  }

  @override
  SendsarChatTheme lerp(ThemeExtension<SendsarChatTheme>? other, double t) {
    if (other is! SendsarChatTheme) return this;
    return SendsarChatTheme(
      border: Color.lerp(border, other.border, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      sidebarBg: Color.lerp(sidebarBg, other.sidebarBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      bubbleSelf: Color.lerp(bubbleSelf, other.bubbleSelf, t)!,
      bubblePeer: Color.lerp(bubblePeer, other.bubblePeer, t)!,
      bubbleSelfText: Color.lerp(bubbleSelfText, other.bubbleSelfText, t)!,
      bubblePeerText: Color.lerp(bubblePeerText, other.bubblePeerText, t)!,
      online: Color.lerp(online, other.online, t)!,
      error: Color.lerp(error, other.error, t)!,
      connectingBg: Color.lerp(connectingBg, other.connectingBg, t)!,
      connectingBorder: Color.lerp(connectingBorder, other.connectingBorder, t)!,
      unreadBadge: Color.lerp(unreadBadge, other.unreadBadge, t)!,
      unreadBadgeText: Color.lerp(unreadBadgeText, other.unreadBadgeText, t)!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
      skeletonMuted: Color.lerp(skeletonMuted, other.skeletonMuted, t)!,
    );
  }
}

extension SendsarChatThemeContext on BuildContext {
  SendsarChatTheme get sendsarTheme {
    final override = SendsarThemeOverride.maybeOf(this);
    if (override != null) return override;
    final ext = Theme.of(this).extension<SendsarChatTheme>();
    if (ext != null) return ext;
    return Theme.of(this).brightness == Brightness.dark
        ? SendsarChatTheme.dark
        : SendsarChatTheme.light;
  }
}

/// Optional per-scope theme override from [SendsarScope].
class SendsarThemeOverride extends InheritedWidget {
  const SendsarThemeOverride({
    super.key,
    required this.theme,
    required super.child,
  });

  final SendsarChatTheme theme;

  static SendsarChatTheme? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SendsarThemeOverride>()
        ?.theme;
  }

  @override
  bool updateShouldNotify(SendsarThemeOverride oldWidget) =>
      theme != oldWidget.theme;
}
