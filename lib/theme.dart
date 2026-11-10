import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const String kUncategorizedId = '__uncategorized__';
const Color kColorBlack = Color(0xFF1A1612);       // warm near-black (primary text)
const Color kColorWhite = Color(0xFFF5F0EB);        // warm off-white (background)
const Color kColorGrey = Color(0xFF8C7B6E);          // warm grey (secondary text)
const Color kColorGreyLight = Color(0xFFEDE8E3);     // warm light (unselected chips, subtle borders)
const Color kColorFill = Color(0xFFFDFAF7);          // card background
const Color kColorAccent = Color(0xFFC4563A);        // burnt terracotta
const Color kColorPositive = Color(0xFF4A6741);      // forest green
const Color kColorError = kColorAccent;

const double kSpace = 10.0;
const double kElementHeight = 44.0;
const double kBorderRadius = 16.0;         // cards
const double kBorderRadiusButton = 12.0;   // buttons, inputs
const double kBorderRadiusPill = 24.0;     // category pills
const double kBorderWidth = 1.0;
const double kBorderWidthActive = 2.0;
const double kIconSize = 18.0;
const double kIconOverlaySize = 14.0;
const double kIconOverlayPadding = 3.0;
const double kSpinnerSize = 16.0;
const double kThumbnailSize = 72.0;
const double kAvatarFontSize = 28.0;
const double kAvatarFontSizeLarge = 64.0;

const double kFontSize = 15.0;

class EmojiOnlyFormatter extends TextInputFormatter {
  // Matches emoji characters (basic + extended)
  static final _emojiRegex = RegExp(
    r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}'
    r'\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}'
    r'\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}'
    r'\u{1FA70}-\u{1FAFF}\u{200D}\u{20E3}\u{E0020}-\u{E007F}]',
    unicode: true,
  );

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    // Extract only emoji characters, keep at most 1
    final emojis = _emojiRegex.allMatches(newValue.text).map((m) => m.group(0)!).join();
    if (emojis.isEmpty) return oldValue;
    // Take only the last emoji entered (so replacing works)
    final runes = emojis.runes.toList();
    final lastEmoji = String.fromCharCode(runes.last);
    return TextEditingValue(
      text: lastEmoji,
      selection: TextSelection.collapsed(offset: lastEmoji.length),
    );
  }
}

class RatingInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final value = double.tryParse(newValue.text);
    if (value == null) return oldValue;
    if (value < 0 || value > 10) return oldValue;
    return newValue;
  }
}

/// Returns red (<5) or green (>=5), with saturation increasing toward 0 and 10.
Color ratingColor(double rating) {
  final clamped = rating.clamp(0.0, 10.0);
  if (clamped >= 5.0) {
    final t = (clamped - 5.0) / 5.0;
    // Start already tinted green at 5, fully saturated at 10
    return Color.lerp(const Color(0xFF7A9A72), kColorPositive, t)!;
  } else {
    final t = (5.0 - clamped) / 5.0;
    // Start already tinted red at 4.99, fully saturated at 0
    return Color.lerp(const Color(0xFFB08070), kColorAccent, t)!;
  }
}

final BoxShadow kCardShadow = BoxShadow(
  color: kColorBlack.withValues(alpha: 0.06),
  blurRadius: 12,
  offset: const Offset(0, 2),
);

Border get kCardBorder => Border.all(
  color: kColorBlack.withValues(alpha: 0.08),
  width: kBorderWidth,
);

BorderSide get kBorderSide => BorderSide(
  color: kColorBlack.withValues(alpha: 0.08),
  width: kBorderWidth,
);

BorderSide get kBorderSideActive => const BorderSide(color: kColorBlack, width: kBorderWidth);

Widget kIconOverlay({required IconData icon, required VoidCallback onTap}) {
  return Positioned(
    top: 4,
    right: 4,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kColorBlack,
          borderRadius: BorderRadius.circular(kBorderRadiusButton),
        ),
        padding: const EdgeInsets.all(kIconOverlayPadding),
        child: Icon(icon, size: kIconOverlaySize, color: kColorWhite),
      ),
    ),
  );
}

ThemeData buildAppTheme() {
  final baseTextTheme = GoogleFonts.instrumentSansTextTheme();
  final uiStyle = GoogleFonts.instrumentSans(fontSize: kFontSize);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(kBorderRadiusButton),
    borderSide: kBorderSide,
  );

  return ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: kColorBlack,
      onPrimary: kColorWhite,
      secondary: kColorBlack,
      onSecondary: kColorWhite,
      surface: kColorWhite,
      onSurface: kColorBlack,
      surfaceTint: Colors.transparent,
    ),
    scaffoldBackgroundColor: kColorWhite,
    textTheme: baseTextTheme.copyWith(
      bodyLarge: GoogleFonts.instrumentSans(fontSize: kFontSize, color: kColorBlack),
    ),
    iconTheme: const IconThemeData(size: kIconSize, color: kColorBlack),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kColorFill,
      isCollapsed: true,
      labelStyle: GoogleFonts.instrumentSans(color: kColorBlack, fontSize: kFontSize),
      hintStyle: GoogleFonts.instrumentSans(color: kColorGrey, fontSize: kFontSize),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kBorderRadiusButton),
        borderSide: kBorderSideActive,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kBorderRadiusButton),
        borderSide: const BorderSide(color: kColorError, width: kBorderWidth),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kBorderRadiusButton),
        borderSide: const BorderSide(color: kColorError, width: kBorderWidth),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: kSpace,
        vertical: (kElementHeight - kFontSize - 2 * kBorderWidth) / 2,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kColorBlack,
        foregroundColor: kColorWhite,
        textStyle: uiStyle,
        minimumSize: const Size(0, kElementHeight),
        padding: const EdgeInsets.fromLTRB(kSpace, 0, kSpace, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadiusButton)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kColorBlack,
        textStyle: uiStyle,
        minimumSize: const Size(0, kElementHeight),
        padding: const EdgeInsets.fromLTRB(kSpace, 0, kSpace, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadiusButton)),
        side: kBorderSide,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kColorBlack,
        textStyle: uiStyle,
        minimumSize: const Size(0, kElementHeight),
        padding: const EdgeInsets.fromLTRB(kSpace, 0, kSpace, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadiusButton)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kColorBlack,
        foregroundColor: kColorWhite,
        textStyle: uiStyle,
        minimumSize: const Size(0, kElementHeight),
        padding: const EdgeInsets.fromLTRB(kSpace, 0, kSpace, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadiusButton)),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kColorFill,
        border: border,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: kColorWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(kBorderRadius),
          topRight: Radius.circular(kBorderRadius),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kColorWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kBorderRadius),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadiusPill)),
      showCheckmark: false,
      labelStyle: GoogleFonts.instrumentSans(fontSize: kFontSize, color: kColorBlack),
      padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
    ),
    navigationBarTheme: const NavigationBarThemeData(elevation: 0),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 0,
      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
      dense: true,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      shape: Border(),
      collapsedShape: Border(),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(kElementHeight, kElementHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  );
}
