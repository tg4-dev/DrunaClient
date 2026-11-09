import 'dart:ui';

abstract final class ProfileHeaderStyle {
  static const avatarTop = 24.0;
  static const avatar = 120.0;
  static const nameGap = 18.0;

  static const row = 44.0;
  static const rowAvatar = 36.0;
  static const rowGap = 8.0;

  static const gutter = 20.0;
}

typedef HeaderFrame = ({
  double collapse,
  Offset avatarCenter,
  double avatarScale,
  Offset name,
});

double headerNameTop() =>
    ProfileHeaderStyle.avatarTop +
    ProfileHeaderStyle.avatar +
    ProfileHeaderStyle.nameGap;

double headerCollapseDistance(double nameHeight) =>
    headerNameTop() - (ProfileHeaderStyle.row - nameHeight) / 2;

HeaderFrame headerFrame({
  required double width,
  required double offset,
  required Size name,
}) {
  final distance = headerCollapseDistance(name.height);
  final collapse = distance <= 0
      ? 1.0
      : (offset / distance).clamp(0.0, 1.0).toDouble();
  final rowTop = (ProfileHeaderStyle.row - name.height) / 2;
  final nameTop = (headerNameTop() - offset).clamp(rowTop, double.infinity);

  final rowWidth =
      ProfileHeaderStyle.rowAvatar + ProfileHeaderStyle.rowGap + name.width;
  final rowLeft = (width - rowWidth) / 2;
  final nameLeft = _lerp(
    (width - name.width) / 2,
    rowLeft + ProfileHeaderStyle.rowAvatar + ProfileHeaderStyle.rowGap,
    collapse,
  );

  final open =
      ProfileHeaderStyle.avatarTop + ProfileHeaderStyle.avatar / 2 - offset;
  final nameCenter = nameTop + name.height / 2;
  final centerY = _lerp(open, nameCenter, collapse);
  final centerX = _lerp(
    width / 2,
    rowLeft + ProfileHeaderStyle.rowAvatar / 2,
    collapse,
  );
  final size = _lerp(
    ProfileHeaderStyle.avatar,
    ProfileHeaderStyle.rowAvatar,
    collapse,
  );
  return (
    collapse: collapse,
    avatarCenter: Offset(centerX, centerY),
    avatarScale: size / ProfileHeaderStyle.avatar,
    name: Offset(nameLeft, nameTop),
  );
}

double stickyLabelTop({
  required double headingTop,
  required double? nextHeadingTop,
  required double labelHeight,
}) {
  final pinned = ProfileHeaderStyle.row;
  if (headingTop > pinned) return headingTop;
  final next = nextHeadingTop;
  if (next == null) return pinned;
  return (next - labelHeight).clamp(double.negativeInfinity, pinned);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

const stickyRamp = 24.0;

double stickyProgress(double headingTop) =>
    ((ProfileHeaderStyle.row + stickyRamp - headingTop) / stickyRamp)
        .clamp(0.0, 1.0)
        .toDouble();
