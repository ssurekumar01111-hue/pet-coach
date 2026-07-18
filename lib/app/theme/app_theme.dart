import 'package:flutter/material.dart';

abstract final class AppColors {
  static const offWhite = Color(0xFFF7F8F4);
  static const nearBlack = Color(0xFF101512);
  static const energyOrange = Color(0xFFFF4D00);
  static const slate = Color(0xFF637068);
}

class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.energyOrange,
    required this.slate,
    required this.cardRadius,
  });

  final Color energyOrange;
  final Color slate;
  final BorderRadius cardRadius;

  BoxDecoration cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: cardRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      );

  @override
  AppThemeTokens copyWith(
          {Color? energyOrange, Color? slate, BorderRadius? cardRadius}) =>
      AppThemeTokens(
        energyOrange: energyOrange ?? this.energyOrange,
        slate: slate ?? this.slate,
        cardRadius: cardRadius ?? this.cardRadius,
      );

  @override
  AppThemeTokens lerp(covariant AppThemeTokens? other, double t) {
    if (other == null) return this;
    return AppThemeTokens(
      energyOrange: Color.lerp(energyOrange, other.energyOrange, t)!,
      slate: Color.lerp(slate, other.slate, t)!,
      cardRadius: BorderRadius.lerp(cardRadius, other.cardRadius, t)!,
    );
  }
}

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: AppColors.offWhite,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.energyOrange,
      brightness: Brightness.light,
      surface: AppColors.offWhite,
      onSurface: AppColors.nearBlack,
    ),
    appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.offWhite,
        foregroundColor: AppColors.nearBlack,
        elevation: 0,
        surfaceTintColor: Colors.transparent),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          color: AppColors.nearBlack,
          fontSize: 44,
          height: .96,
          fontWeight: FontWeight.w900),
      headlineLarge: TextStyle(
          color: AppColors.nearBlack,
          fontSize: 37,
          height: 1,
          fontWeight: FontWeight.w900),
      titleLarge: TextStyle(
          color: AppColors.nearBlack,
          fontSize: 19,
          fontWeight: FontWeight.w800),
      bodyLarge: TextStyle(color: AppColors.slate, fontSize: 16),
      bodyMedium: TextStyle(color: AppColors.slate, fontSize: 14),
      labelLarge: TextStyle(fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: AppColors.energyOrange,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800))),
    extensions: const [
      AppThemeTokens(
          energyOrange: AppColors.energyOrange,
          slate: AppColors.slate,
          cardRadius: BorderRadius.all(Radius.circular(24)))
    ],
  );
}
