import 'package:dio/dio.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/home_pager.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/friends/group_chip.dart';
import 'package:druna_app/features/groups/create_group_page.dart';
import 'package:druna_app/features/groups/group_editor.dart';
import 'package:druna_app/features/groups/group.dart';
import 'package:druna_app/features/groups/group_page.dart';
import 'package:druna_app/features/groups/groups_source.dart';
import 'package:druna_app/features/groups/orbit.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/features/invites/invites_source.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/people_backdrop.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const me = FriendInfo(id: 1, name: 'Глеб', username: 'gleb');
  const alina = DemoInvitesSource.alina;
  const mark = DemoInvitesSource.mark;

  Invite invite(List<FriendInfo> others) => Invite(
    id: 'x',
    organizer: me,
    title: 'x',
    start: DateTime(2026, 11, 9, 18),
    end: DateTime(2026, 11, 9, 20),
    participants: [
      for (final person in others) InviteParticipant(person, RsvpStatus.going),
    ],
  );

  group('group events', () {
    const group = Group(id: 'g', name: 'G', members: [alina, mark]);

    test('an invite belongs to a group only with exactly its people', () {
      expect(inviteMatchesGroup(invite([alina, mark]), group, meId: 1), true);
      expect(inviteMatchesGroup(invite([alina]), group, meId: 1), false);
      expect(
        inviteMatchesGroup(
          invite([alina, mark, DemoInvitesSource.olga]),
          group,
          meId: 1,
        ),
        false,
      );
    });
  });

  group('orbit', () {
    const box = Size(400, OrbitStyle.box);

    test('slots are spread evenly round the ellipse', () {
      expect(orbitSlot(0, 4), 0);
      expect(orbitSlot(2, 4), closeTo(3.14159, 0.0001));
    });

    test('the ellipse is centred, as wide as 75% of the page, tilted', () {
      final right = orbitPoint(box: box, angle: 0, tilt: 0);
      expect(right.dx, closeTo(200 + 400 * OrbitStyle.widthShare / 2, 0.001));
      expect(right.dy, closeTo(box.height / 2, 0.001));
      final tilted = orbitPoint(box: box, angle: 0);
      expect(tilted.dy, lessThan(box.height / 2));
    });
  });

  group('demo groups', () {
    test('create, update, remove', () async {
      final source = DemoGroupsSource(delay: Duration.zero);
      final seeded = await source.list();
      expect(seeded.single.name, 'Tugachi');
      final made = await source.create(
        const GroupDraft(name: ' Кино ', fontId: 'lobster', members: [mark]),
      );
      expect(made.name, 'Кино');
      expect(made.font.id, 'lobster');
      final updated = await source.update(
        made,
        const GroupDraft(name: 'Кино!', fontId: 'onest', members: [alina]),
      );
      expect(updated.name, 'Кино!');
      expect(updated.memberIds, {alina.id});
      await source.delete(updated);
      expect(await source.list(), hasLength(1));
    });

    test('the server says honestly what it cannot do', () async {
      final repository = DrunaRepository(
        ApiClient(
          baseUrl: 'https://example.test',
          tokenStore: MemoryTokenStore(),
          dio: Dio(),
        ),
      );
      final source = ServerGroupsSource(
        repository,
        GroupFonts(MemorySettingsStorage()),
        meId: () => 1,
      );
      const before = Group(id: '5', name: 'A', members: [alina]);
      expect(
        () => source.update(
          before,
          const GroupDraft(name: 'B', fontId: 'onest', members: [alina]),
        ),
        throwsA(isA<GroupsUnsupported>()),
      );
      expect(
        () => source.update(
          before,
          const GroupDraft(name: 'A', fontId: 'onest', members: []),
        ),
        throwsA(isA<GroupsUnsupported>()),
      );
    });
  });

  testWidgets('a group page right of the profile, then one is created and '
      'removed', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repository = DrunaRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        tokenStore: MemoryTokenStore(),
        dio: Dio(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomePager(
          session: SessionController(repository),
          settings: AppSettings(
            storage: MemorySettingsStorage(),
            demoByDefault: true,
          ),
          config: const AppConfig(apiBaseUrl: 'https://example.test'),
          demoDelay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    bool onScreen(Finder finder) {
      final rect = tester.getRect(finder);
      return rect.left >= -1 && rect.right <= 403;
    }

    Future<void> swipeLeft() async {
      await tester.flingFrom(
        const Offset(200, 120),
        const Offset(-300, 0),
        1500,
      );
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await swipeLeft();
    expect(find.byType(GroupPage), findsOneWidget);
    expect(onScreen(find.byType(GroupPage)), isTrue);
    expect(
      find.descendant(
        of: find.byType(GroupPage),
        matching: find.byKey(const ValueKey('profile-chip-demo-invite-dinner')),
      ),
      findsOneWidget,
    );

    await swipeLeft();
    expect(onScreen(find.byType(CreateGroupPage)), isTrue);
    expect(find.byKey(const ValueKey('group-save')), findsNothing);
    final riders = find.descendant(
      of: find.byType(CreateGroupPage),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is KeyedSubtree && '${widget.key}'.contains('orbit-slot-'),
      ),
    );
    expect(riders, findsNothing);
    double captionOpacity() => tester
        .widget<AnimatedOpacity>(
          find.byKey(const ValueKey('group-create-caption')),
        )
        .opacity;
    expect(captionOpacity(), 1);
    final dima = find.byKey(const ValueKey('group-friend-108'));
    await tester.ensureVisible(dima);
    await tester.tap(dima);
    await tester.pumpAndSettle();
    expect(riders, findsNWidgets(2));
    expect(captionOpacity(), 0);
    await tester.enterText(
      find.byKey(const ValueKey('group-name-input')),
      'Кино',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('group-save')));
    await tester.tap(find.byKey(const ValueKey('group-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить').last);
    await tester.pumpAndSettle();
    expect(find.byType(GroupPage), findsNWidgets(2));
    expect(onScreen(find.byType(GroupPage).last), isTrue);

    final edit = find.descendant(
      of: find.byType(GroupPage).last,
      matching: find.byKey(const ValueKey('group-edit')),
    );
    await tester.tap(edit);
    await tester.pumpAndSettle();
    final remove = find.byKey(const ValueKey('group-remove'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();
    expect(find.byType(GroupPage), findsOneWidget);
  });

  test('a group chip is never wider than four avatars', () {
    expect(closedGroupChipWidth(nameWidth: 500, people: 3), 260);
    expect(
      closedGroupChipWidth(nameWidth: 60, people: 3),
      16 + 60 + 8 + 20 + 12 * 2 + 16,
    );
    expect(openGroupChipWidth(3), 12 + 3 * 56 - 8 + 16 + 22 + 16);
  });

  testWidgets('a group in the friend bar opens, picks its people, lets one '
      'go and closes', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repository = DrunaRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        tokenStore: MemoryTokenStore(),
        dio: Dio(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomePager(
          session: SessionController(repository),
          settings: AppSettings(
            storage: MemorySettingsStorage(),
            demoByDefault: true,
          ),
          config: const AppConfig(apiBaseUrl: 'https://example.test'),
          demoDelay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chip = find.byKey(const ValueKey('group-chip-demo-group-tugachi'));
    final alina = find.bySemanticsLabel('АЛИНА СМИРНОВА');
    final rings = find.byKey(const ValueKey('friend-ring'));
    expect(chip, findsOneWidget);
    expect(tester.getRect(chip).width, lessThanOrEqualTo(260));
    expect(tester.getRect(chip).right, lessThan(tester.getRect(alina).left));
    expect(rings, findsNothing);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    final caption = find.byKey(
      const ValueKey('group-caption-demo-group-tugachi'),
    );
    expect(caption, findsOneWidget);
    expect(rings, findsNWidgets(3));
    expect(tester.getRect(alina).width, closeTo(48, 0.01));
    expect(tester.getRect(alina).left, lessThan(80));

    await tester.flingFrom(const Offset(200, 500), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(tester.getRect(alina).left, greaterThan(250));
    expect(
      tester.getRect(find.byKey(const ValueKey('group-chip-close'))).left,
      greaterThan(400),
    );
    await tester.tap(find.bySemanticsLabel('Показать занятость друзей'));
    await tester.pumpAndSettle();
    expect(tester.getRect(alina).left, lessThan(80));

    await tester.tap(alina);
    await tester.pumpAndSettle();
    expect(rings, findsNWidgets(2));
    expect(tester.getRect(alina).left, lessThan(80));

    await tester.tap(find.byKey(const ValueKey('group-chip-close')));
    await tester.pumpAndSettle();
    expect(caption, findsNothing);
    expect(rings, findsNothing);
    expect(chip, findsOneWidget);
  });

  testWidgets('a group name is at most 20 letters', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GroupNameField(
              controller: controller,
              font: avatarFontById(null),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('group-name-input')),
      'А' * 30,
    );
    expect(controller.text.length, maxGroupName);
  });

  test('the backdrop scene shows the nearest page and blends anchors', () {
    final position = ValueNotifier<double>(0);
    final scene = BackdropScene(position);
    final first = ValueNotifier<double>(100);
    final second = ValueNotifier<double>(300);
    final owner = Object();
    final other = Object();
    scene
      ..report(owner, index: 0, colors: const [Colors.red], anchor: first)
      ..report(other, index: 1, colors: const [Colors.blue], anchor: second);
    expect(scene.colors, [Colors.red]);
    position.value = 0.25;
    expect(scene.anchor.value, 150);
    position.value = 0.75;
    expect(scene.colors, [Colors.blue]);
    scene.forget(other);
    expect(scene.anchor.value, 100);
    scene.dispose();
  });
}
