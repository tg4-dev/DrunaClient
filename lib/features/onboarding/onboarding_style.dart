import 'package:druna_app/features/event_page/event_style.dart';
import 'package:druna_app/shared/ui/pill_field.dart';
import 'package:flutter/material.dart';

/// Measurements of the onboarding (design-system §9.9), taken from the
/// Figma screenshots at 393 pt wide 🟡.
abstract final class OnboardingStyle {
  /// Fields, the welcome screen's buttons, the arrows.
  static const height = PillFieldStyle.height;
  static const fieldWidth = PillFieldStyle.fieldWidth;

  /// The email field: wider, and its text smaller, so an address fits.
  static const emailWidth = 300.0;

  static const arrowWidth = 72.0;
  static const arrowGap = 10.0;
  static const buttonGap = 14.0;

  static const codeBox = Size(46, 50);
  static const codeGap = 6.0;
  static const codeRadius = 14.0;

  /// The title's top below the safe area, and its block's height.
  static const titleTop = 88.0;
  static const titleBlock = 104.0;

  /// The profile: from the title's top to the avatar's — two lines of the
  /// title and a gap (Figma).
  static const profileTitle = 2 * 28 * 1.25 + 20;

  /// Above the field: the red line. Below it: the timer or a hint.
  static const errorSlot = 34.0;
  static const hintSlot = 44.0;
  static const navGap = 30.0;

  /// The arrows stay at least this far above the keyboard…
  static const keyboardClearance = 24.0;

  /// …and without it never sink below this share of the screen.
  static const lowest = 0.68;

  /// Black under the brand colour.
  static const black = Color(0xFF000000);
  static const ink = Color(0xFF262626);
  static const danger = Color(0xFFFF3B30);
  static const success = Color(0xFF34C759);

  static final title = onest(
    28,
    weight: FontWeight.w700,
    color: Colors.white.withValues(alpha: 0.92),
    height: 1.25,
    letterSpacing: -0.4,
  );
  static final subtitle = onest(
    19,
    weight: FontWeight.w600,
    color: Colors.white.withValues(alpha: 0.6),
    height: 1.3,
  );
  static final field = PillFieldStyle.field;

  static final emailField = onest(18, weight: FontWeight.w500, height: 1.2);
  static final emailHint = onest(
    18,
    weight: FontWeight.w500,
    color: Colors.white.withValues(alpha: 0.45),
    height: 1.2,
  );

  /// The name field: bolder, it is the name friends will see (in capitals).
  static final nameField = PillFieldStyle.name;
  static final nameHint = PillFieldStyle.nameHint;
  static final digit = onest(26, weight: FontWeight.w600, height: 1);
  static final error = onest(16, weight: FontWeight.w500, color: danger);
  static final hint = onest(
    15,
    weight: FontWeight.w500,
    color: Colors.white.withValues(alpha: 0.6),
  );
  static final link = onest(15, weight: FontWeight.w500).copyWith(
    decoration: TextDecoration.underline,
    decorationColor: Colors.white,
  );

  /// A calendar on the calendar step: its name, and its account under it.
  static final calendarName = onest(17, weight: FontWeight.w600, height: 1.2);
  static final calendarAccount = onest(
    13,
    weight: FontWeight.w500,
    color: Colors.white.withValues(alpha: 0.6),
    height: 1.2,
  );

  static final tagline = onest(
    22,
    weight: FontWeight.w500,
    color: Colors.white.withValues(alpha: 0.7),
  );
  static final social = onest(
    20,
    weight: FontWeight.w600,
    color: Colors.black,
    height: 1,
    letterSpacing: -0.3,
  );
  static final footnote = onest(
    15,
    weight: FontWeight.w400,
    color: Colors.white.withValues(alpha: 0.5),
    height: 1.35,
  );

  static const move = Duration(milliseconds: 360);
  static const fade = Duration(milliseconds: 180);
  static const slide = 24.0;
}
