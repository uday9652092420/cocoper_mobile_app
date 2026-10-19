import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryLight = Color(0xFF1C352D);
  static const Color secondaryLight = Color(0xFFF66834);
  static const Color blue = Color(0xFF0C8CE9);

  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color bgBlackLight = Color(0xFF000000);
  static const Color scaffoldBackground = Color(0xFFF5F8F6);
  static const Color bgLightBlueLight = Color(0xFFEAF4FF);
  static const Color surfaceTint = Color(0xFFE7F3E4);
  static const Color fieldFill = Color(0xFFF6F8F6);
  static const Color pageGradientStart = Color(0xFFE9F3E6);
  static const Color pageGradientEnd = Color(0xFFFDFEFC);
  static const Color bgBtnDisableLight = Color(0xFFCFD1DF);
  static const Color bgLightSecondaryLight = Color(0xFFFFF5F1);
  static const Color bgLightSecondaryDark = Color(0xFFF7E9E3);

  static const Color borderLightBlueLight = Color(0xFFD0DCEC);
  static const Color borderLightGrayLight = Color(0xFFE1E8E4);
  static const Color borderGray = Color(0xFFB8C4BE);

  static const Color textDefaultLight = Color(0xFF182821);
  static const Color textWhiteLight = Color(0xFFFFFFFF);
  static const Color textLightBlueLight = Color(0xFF416B88);
  static const Color textLightGrayLight = Color(0xFF68776F);
  static const Color textGreenLight = Color(0xFF269E82);

  static const Color errorLight = Color(0xFFB3261E);
  static const Color successLight = Color(0xFF267A52);
  static const Color warningLight = Color(0xFFA8640A);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

class AppGradients {
  static const LinearGradient pageBackground = LinearGradient(
    colors: [AppColors.pageGradientStart, AppColors.pageGradientEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTypography {
  static const double amount = 20;
  static const double screenTitle = 20;
  static const double sectionTitle = 16;
  static const double body = 14;
  static const double bodyLarge = 16;
  static const double label = 12;
  static const double status = 11;
}

class AppTheme {
  static const TextTheme themeFont = TextTheme(
    displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
    displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
    displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(
      fontSize: AppTypography.screenTitle,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: AppTypography.sectionTitle,
      fontWeight: FontWeight.w600,
    ),
    titleSmall:
        TextStyle(fontSize: AppTypography.body, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: AppTypography.bodyLarge),
    bodyMedium: TextStyle(fontSize: AppTypography.body),
    bodySmall: TextStyle(fontSize: AppTypography.label),
    labelLarge:
        TextStyle(fontSize: AppTypography.body, fontWeight: FontWeight.w600),
    labelMedium:
        TextStyle(fontSize: AppTypography.label, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(
      fontSize: AppTypography.status,
      fontWeight: FontWeight.w500,
    ),
  );

  /// Light Theme
  static const _lightTheme = CustomTheme(
    primaryColor: AppColors.primaryLight,
    secondaryColor: AppColors.secondaryLight,
    blue: AppColors.blue,
    errorColor: AppColors.errorLight,
    successColor: AppColors.successLight,
    warningColor: AppColors.warningLight,
    bgColor: AppColors.bgLight,
    bgBlack: AppColors.bgBlackLight,
    bgLightBlue: AppColors.bgLightBlueLight,
    bgBtnDisable: AppColors.bgBtnDisableLight,
    bgLightSecondary: AppColors.bgLightSecondaryLight,
    bgLightSecondaryDark: AppColors.bgLightSecondaryDark,
    borderLightBlue: AppColors.borderLightBlueLight,
    borderLightGray: AppColors.borderLightGrayLight,
    borderGray: AppColors.borderGray,
    textDefault: AppColors.textDefaultLight,
    textWhiteLight: AppColors.textWhiteLight,
    textLightBlue: AppColors.textLightBlueLight,
    textLightGray: AppColors.textLightGrayLight,
    textGreen: AppColors.textGreenLight,
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    extensions: const [_lightTheme],
    textTheme: themeFont,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryLight,
      primary: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      error: AppColors.errorLight,
      surface: AppColors.bgLight,
    ),
    scaffoldBackgroundColor: AppColors.scaffoldBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgLight,
      foregroundColor: AppColors.textDefaultLight,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textDefaultLight,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: AppColors.textDefaultLight),
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgLight,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.borderLightGrayLight),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      hintStyle: const TextStyle(color: AppColors.textLightGrayLight),
      labelStyle: const TextStyle(color: AppColors.textLightGrayLight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.borderLightGrayLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.borderLightGrayLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.errorLight),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.errorLight, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        minimumSize: const Size(100, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        minimumSize: const Size(100, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        side: const BorderSide(color: AppColors.borderLightGrayLight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: AppColors.textWhiteLight,
      elevation: 2,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.scaffoldBackground,
      selectedColor: AppColors.primaryLight.withValues(alpha: 0.12),
      side: const BorderSide(color: AppColors.borderLightGrayLight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      labelStyle: const TextStyle(
        color: AppColors.textDefaultLight,
        fontSize: 12,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.bgLight,
      modalBackgroundColor: AppColors.bgLight,
      showDragHandle: true,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgLight,
      selectedItemColor: AppColors.primaryLight,
      unselectedItemColor: AppColors.textLightGrayLight,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(
        fontSize: AppTypography.label,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: AppTypography.label,
        fontWeight: FontWeight.w500,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textLightGrayLight,
      textColor: AppColors.textDefaultLight,
      minVerticalPadding: AppSpacing.sm,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.primaryLight
            : null;
      }),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm / 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textDefaultLight,
      contentTextStyle: const TextStyle(color: AppColors.textWhiteLight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bgLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderLightGrayLight,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryLight,
    ),
  );

  /// Dark Theme

  // static const _darkTheme = CustomTheme(
  //   primaryColor: AppColors.primaryLight, // Add dark colors here if available
  //   secondaryColor: AppColors.secondaryLight,
  //   errorColor: AppColors.errorLight,
  //   successColor: AppColors.successLight,
  //   warningColor: AppColors.warningLight,
  //   bgColor: Colors.black, // Example dark color
  //   bgBlack: Colors.black,
  //   bgLightBlue: Colors.grey.shade800,
  //   bgBtnDisable: Colors.grey.shade800,
  //   bgLightSecondary: Colors.grey.shade700,
  //   borderLightBlue: Colors.grey.shade600,
  //   borderLightGray: Colors.grey.shade500,
  //   textDefault: Colors.grey.shade200,
  //   textLightBlue: Colors.grey.shade400,
  //   textLightGray: Colors.grey.shade500,
  //   textGreen: Colors.green.shade300,
  // );

  // static ThemeData darkTheme = ThemeData(
  //   useMaterial3: true,
  //   extensions: [
  //     CustomTheme(
  //       primaryColor: AppColors.primaryDark,
  //       secondaryColor: AppColors.secondaryDark,
  //       errorColor: AppColors.errorDark,
  //       successColor: AppColors.successDark,
  //       warningColor: AppColors.warningDark,
  //     ),
  //   ],
  //   textTheme: themeFont,
  // );
}

class CustomTheme extends ThemeExtension<CustomTheme> {
  final Color primaryColor;
  final Color secondaryColor;
  final Color blue;
  final Color errorColor;
  final Color successColor;
  final Color warningColor;

  // Background Colors
  final Color bgColor;
  final Color bgBlack;
  final Color bgLightBlue;
  final Color bgBtnDisable;
  final Color bgLightSecondary;
  final Color bgLightSecondaryDark;

  // Border Colors
  final Color borderLightBlue;
  final Color borderLightGray;
  final Color borderGray;

  // Text Colors
  final Color textDefault;
  final Color textWhiteLight;
  final Color textLightBlue;
  final Color textLightGray;
  final Color textGreen;

  const CustomTheme({
    required this.primaryColor,
    required this.secondaryColor,
    required this.blue,
    required this.errorColor,
    required this.successColor,
    required this.warningColor,
    required this.bgColor,
    required this.bgBlack,
    required this.bgLightBlue,
    required this.bgBtnDisable,
    required this.bgLightSecondary,
    required this.bgLightSecondaryDark,
    required this.borderLightBlue,
    required this.borderLightGray,
    required this.borderGray,
    required this.textDefault,
    required this.textWhiteLight,
    required this.textLightBlue,
    required this.textLightGray,
    required this.textGreen,
  });

  @override
  CustomTheme copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    Color? blue,
    Color? errorColor,
    Color? successColor,
    Color? warningColor,
    Color? bgColor,
    Color? bgBlack,
    Color? bgLightBlue,
    Color? bgBtnDisable,
    Color? bgLightSecondary,
    Color? bgLightSecondaryDark,
    Color? borderLightBlue,
    Color? borderLightGray,
    Color? borderGray,
    Color? textDefault,
    Color? textWhiteLight,
    Color? textLightBlue,
    Color? textLightGray,
    Color? textGreen,
  }) {
    return CustomTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      blue: blue ?? this.blue,
      errorColor: errorColor ?? this.errorColor,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      bgColor: bgColor ?? this.bgColor,
      bgBlack: bgBlack ?? this.bgBlack,
      bgLightBlue: bgLightBlue ?? this.bgLightBlue,
      bgBtnDisable: bgBtnDisable ?? this.bgBtnDisable,
      bgLightSecondary: bgLightSecondary ?? this.bgLightSecondary,
      bgLightSecondaryDark: bgLightSecondaryDark ?? this.bgLightSecondaryDark,
      borderLightBlue: borderLightBlue ?? this.borderLightBlue,
      borderLightGray: borderLightGray ?? this.borderLightGray,
      borderGray: borderGray ?? this.borderGray,
      textDefault: textDefault ?? this.textDefault,
      textWhiteLight: textWhiteLight ?? this.textWhiteLight,
      textLightBlue: textLightBlue ?? this.textLightBlue,
      textLightGray: textLightGray ?? this.textLightGray,
      textGreen: textGreen ?? this.textGreen,
    );
  }

  @override
  CustomTheme lerp(ThemeExtension<CustomTheme>? other, double t) {
    if (other is! CustomTheme) return this;
    return CustomTheme(
      primaryColor: Color.lerp(primaryColor, other.primaryColor, t)!,
      secondaryColor: Color.lerp(secondaryColor, other.secondaryColor, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      errorColor: Color.lerp(errorColor, other.errorColor, t)!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      bgColor: Color.lerp(bgColor, other.bgColor, t)!,
      bgBlack: Color.lerp(bgBlack, other.bgBlack, t)!,
      bgLightBlue: Color.lerp(bgLightBlue, other.bgLightBlue, t)!,
      bgBtnDisable: Color.lerp(bgBtnDisable, other.bgBtnDisable, t)!,
      bgLightSecondary:
          Color.lerp(bgLightSecondary, other.bgLightSecondary, t)!,
      bgLightSecondaryDark:
          Color.lerp(bgLightSecondary, other.bgLightSecondaryDark, t)!,
      borderLightBlue: Color.lerp(borderLightBlue, other.borderLightBlue, t)!,
      borderLightGray: Color.lerp(borderLightGray, other.borderLightGray, t)!,
      borderGray: Color.lerp(borderGray, other.borderGray, t)!,
      // textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      // textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDefault: Color.lerp(textDefault, other.textDefault, t)!,
      textWhiteLight: Color.lerp(textWhiteLight, other.textWhiteLight, t)!,
      textLightBlue: Color.lerp(textLightBlue, other.textLightBlue, t)!,
      textLightGray: Color.lerp(textLightGray, other.textLightGray, t)!,
      textGreen: Color.lerp(textGreen, other.textGreen, t)!,
    );
  }

  // Helper method for easy access
  static CustomTheme of(BuildContext context) {
    final customTheme = Theme.of(context).extension<CustomTheme>();
    if (customTheme == null) {
      // Fallback to light theme if extension not found
      return AppTheme._lightTheme;
    }
    return customTheme;
    // // return Theme.of(context).extension<CustomTheme>()!;
    // final customTheme = Theme.of(context).extension<CustomTheme>();
    // assert(
    //   customTheme != null,
    //   'CustomTheme not found in ThemeData.extensions',
    // );
    // return customTheme ?? AppTheme._lightTheme;
    // // return customTheme ??
    // //     (Theme.of(context).brightness == Brightness.light ? AppTheme._lightTheme : AppTheme._darkTheme);
  }
}
