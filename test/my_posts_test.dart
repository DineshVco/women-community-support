import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/core/theme/app_typography.dart';
import 'package:women_community_support/data/microcopy.dart';
import 'package:women_community_support/presentation/screens/create_post_screen.dart';
import 'package:women_community_support/presentation/screens/me/post_list_screen.dart';
import 'package:women_community_support/presentation/widgets/card_picture.dart';

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('My posts, empty: the sleeping cat, a warm line, Write a post', (
    tester,
  ) async {
    await _pump(
      tester,
      PostListScreen(
        title: 'My posts',
        load: () async => [],
        emptyMessage: Microcopy.emptyMyPosts,
        offerWrite: true,
      ),
    );
    expect(find.byKey(const ValueKey('empty-cat')), findsOneWidget);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('empty-cat')),
        matching: find.byType(Image),
      ),
    );
    expect((image.image as AssetImage).assetName, CardPictures.catSleep);
    expect(find.textContaining('When you feel ready'), findsOneWidget);

    await tester.tap(find.text('Write a post'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CreatePostScreen), findsOneWidget);
    expect(find.text('New post'), findsOneWidget);
  });

  testWidgets('Saved posts: as before, no button; the title in Newsreader', (
    tester,
  ) async {
    await _pump(
      tester,
      PostListScreen(
        title: 'Saved posts',
        load: () async => [],
        emptyMessage: Microcopy.emptySaved,
        emptyPicture: (CardPictures.yarnFull, CardPictures.yarnFullAspect),
      ),
    );
    expect(find.text('Write a post'), findsNothing);
    final title = tester.widget<Text>(find.text('Saved posts'));
    expect(title.style?.fontFamily, AppTypography.headingFont);
  });
}
