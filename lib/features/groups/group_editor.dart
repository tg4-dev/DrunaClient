import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/event_page/fit_title.dart';
import 'package:druna_app/features/friends/friend_bar.dart';
import 'package:druna_app/features/groups/orbit.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/action_pill.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/onest.dart';
import 'package:druna_app/shared/ui/page_parts.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/pill_field.dart';
import 'package:druna_app/shared/ui/profile_pickers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

abstract final class GroupStyle {
  static const titleSize = 40.0;
  static const gutter = 20.0;
  static const orbitTop = 24.0;
  static const actionsGap = PageStyle.actionsGap;
  static const actionGap = 8.0;
  static const pickersGap = 20.0;
  static const pickerGap = 14.0;
  static const captionGap = 8.0;

  static const gridColumns = 3;
  static const gridCell = 80.0;
  static const gridInset = 8.0;
  static const gridRadius = 36.0;

  static final caption = onest(20, weight: FontWeight.w600);
  static final note = onest(
    17,
    weight: FontWeight.w400,
    color: SheetStyle.muted,
  );

  static const link = 'https://druna.tg4.dev/group/';
  static const red = Color(0xFFFF3B30);
}

const maxGroupName = 20;

String groupLink(String id) => '${GroupStyle.link}$id';

TextStyle groupTitleStyle(AvatarFont font) => font
    .style(GroupStyle.titleSize, const Color(0xFFFFFFFF))
    .copyWith(height: 1.2);

TextStyle groupFieldStyle(AvatarFont font, TextStyle base) => base.copyWith(
  fontFamily: font.family,
  fontWeight: font.weight,
  fontVariations: [FontVariation('wght', font.weight.value.toDouble())],
);

Size groupTitleSize(BuildContext context, String name, AvatarFont font) {
  final painter = TextPainter(
    text: TextSpan(
      text: shownName(name.trim().isEmpty ? 'Группа' : name),
      style: groupTitleStyle(font),
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

class GroupTitle extends StatelessWidget {
  const GroupTitle({required this.name, required this.font, super.key});

  final String name;
  final AvatarFont font;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GroupStyle.gutter),
      child: FitTitle(
        text: name.trim().isEmpty ? 'Группа' : name,
        style: groupTitleStyle(font),
        maxLines: 1,
      ),
    );
  }
}

class GroupNameField extends StatelessWidget {
  const GroupNameField({
    required this.controller,
    required this.font,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final AvatarFont font;

  @override
  Widget build(BuildContext context) {
    TextStyle styled(TextStyle base) => groupFieldStyle(font, base);
    return PillField(
      key: const ValueKey('group-name-field'),
      fieldKey: const ValueKey('group-name-input'),
      controller: controller,
      focusNode: focusNode,
      hint: 'НАЗВАНИЕ',
      width: null,
      style: styled(PillFieldStyle.name),
      hintStyle: styled(PillFieldStyle.nameHint),
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      inputFormatters: [LengthLimitingTextInputFormatter(maxGroupName)],
      keepFocus: false,
    );
  }
}

class ConfirmRow extends StatelessWidget {
  const ConfirmRow({
    required this.onCancel,
    required this.onConfirm,
    required this.confirmLabel,
    super.key,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ActionPill(
          key: const ValueKey('group-cancel'),
          icon: CupertinoIcons.xmark,
          label: 'Отменить',
          kind: ActionPillKind.cancel,
          onPressed: onCancel,
        ),
        const SizedBox(width: GroupStyle.actionGap),
        ActionPill(
          key: const ValueKey('group-save'),
          icon: CupertinoIcons.checkmark_alt,
          label: confirmLabel,
          filled: true,
          onPressed: onConfirm,
        ),
      ],
    );
  }
}

class FriendGrid extends StatelessWidget {
  const FriendGrid({
    required this.friends,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final List<FriendInfo>? friends;
  final Set<int> selected;
  final ValueChanged<FriendInfo> onToggle;

  @override
  Widget build(BuildContext context) {
    final friends = this.friends;
    const inset = GroupStyle.gridInset;
    const width = ProfilePickerStyle.width;
    if (friends == null) {
      return const SizedBox(
        width: width,
        height: GroupStyle.gridCell,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (friends.isEmpty) {
      return SizedBox(
        width: width,
        child: Text(
          'Добавь друзей, чтобы собрать группу',
          textAlign: TextAlign.center,
          style: GroupStyle.note,
        ),
      );
    }
    const columns = GroupStyle.gridColumns;
    const cell = (width - 2 * inset) / columns;
    final rows = (friends.length / columns).ceil();
    return SizedBox(
      width: width,
      height: rows * GroupStyle.gridCell + 2 * inset,
      child: PillSurface(
        radius: GroupStyle.gridRadius,
        child: Stack(
          children: [
            for (var i = 0; i < friends.length; i++)
              Positioned(
                left: inset + (i % columns) * cell,
                top: inset + (i ~/ columns) * GroupStyle.gridCell,
                width: cell,
                height: GroupStyle.gridCell,
                child: Semantics(
                  button: true,
                  selected: selected.contains(friends[i].id),
                  label: friends[i].name,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: ValueKey('group-friend-${friends[i].id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onToggle(friends[i]);
                    },
                    child: Center(
                      child: SizedBox.square(
                        dimension: OrbitStyle.avatar,
                        child: RingedAvatar(
                          friend: friends[i],
                          selected: selected.contains(friends[i].id),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GroupPickers extends StatelessWidget {
  const GroupPickers({
    required this.name,
    this.caption,
    required this.font,
    required this.onFont,
    required this.friends,
    required this.selected,
    required this.onToggle,
    this.footer,
    super.key,
  });

  final String? caption;
  final String name;
  final AvatarFont font;
  final ValueChanged<AvatarFont> onFont;
  final List<FriendInfo>? friends;
  final Set<int> selected;
  final ValueChanged<FriendInfo> onToggle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (caption case final caption?) ...[
          Text(caption, style: GroupStyle.caption),
          const SizedBox(height: GroupStyle.pickerGap),
        ],
        FontPicker(
          name: name.trim().isEmpty ? 'N' : name,
          selected: font,
          onPick: onFont,
        ),
        const SizedBox(height: GroupStyle.pickerGap),
        FriendGrid(friends: friends, selected: selected, onToggle: onToggle),
        if (footer case final footer?) ...[
          const SizedBox(height: GroupStyle.pickersGap),
          footer,
        ],
      ],
    );
  }
}

class LeaveGroupButton extends StatelessWidget {
  const LeaveGroupButton({
    required this.owner,
    required this.onPressed,
    super.key,
  });

  final bool owner;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PillButton(
      key: const ValueKey('group-remove'),
      icon: owner ? CupertinoIcons.trash : CupertinoIcons.square_arrow_left,
      text: owner ? 'Удалить группу' : 'Выйти из группы',
      color: GroupStyle.red,
      onPressed: onPressed,
    );
  }
}
