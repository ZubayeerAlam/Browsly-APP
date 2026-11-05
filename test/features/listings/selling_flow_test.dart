import 'package:browsly_app/features/listings/domain/entities/listing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> pumpTall(
  WidgetTester tester, {
  FakeShopRepository? shops,
  FakeListingRepository? listings,
}) async {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    auth: FakeAuthRepository(user: verifiedUser),
    addresses: FakeAddressRepository(),
    shops: shops,
    listings: listings,
  );
}

Future<void> openMyPosts(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('My Posts'));
  await tester.pumpAndSettle();
}

void main() {
  group('opening a shop', () {
    testWidgets('a new seller opens a shop, then reaches the form', (
      tester,
    ) async {
      final shops = FakeShopRepository(shop: null);
      await pumpTall(tester, shops: shops);

      await tester.tap(navItem('Post'));
      await tester.pumpAndSettle();
      expect(find.text('Open your shop'), findsOneWidget);

      await tester.tap(find.text('Open shop'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your shop name'), findsOneWidget);
      expect(find.text('Please accept to continue'), findsOneWidget);
      expect(shops.creates, 0);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Shop name'),
        'My Shop',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Delivery fee (৳)'),
        '60',
      );
      await tester.tap(find.text('Division'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dhaka').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('District'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gazipur').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Open shop'));
      await tester.pumpAndSettle();

      expect(shops.lastInput?.name, 'My Shop');
      expect(shops.lastInput?.regionId, 'gazipur');
      expect(shops.lastAcceptedTerms, isTrue);
      expect(find.text('Create Your Listing'), findsOneWidget);
    });
  });

  group('the Post form', () {
    testWidgets('checks the first step before moving on', (tester) async {
      await pumpTall(tester);

      await tester.tap(navItem('Post'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next: Add Description'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter at least 3 characters'), findsOneWidget);
      expect(find.text('Step 1 of 4: Basics'), findsOneWidget);
    });

    testWidgets('leaving with unsaved changes asks first', (tester) async {
      await pumpTall(tester);
      await tester.tap(navItem('Post'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Product name'),
        'Lamp',
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Create Your Listing'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets(
      'editing a live listing warns about review, and walks to save',
      (tester) async {
        final listings = FakeListingRepository();
        listings.listings.add(
          const ListingSummary(
            id: 'p',
            title: 'Lamp',
            status: ListingStatus.paused,
          ),
        );
        listings.editable['p'] = const EditableListing(
          id: 'p',
          title: 'Lamp',
          description: 'A very good lamp.',
          categoryId: 'leaf',
          isNew: true,
          status: ListingStatus.paused,
          photos: [ListingPhotoRef(path: 'a.jpg', url: 'u')],
          variants: [ListingVariant(price: 5, stock: 1)],
        );
        final catalog = FakeCatalogRepository();
        tester.view.physicalSize = const Size(420, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpApp(
          tester,
          auth: FakeAuthRepository(user: verifiedUser),
          listings: listings,
          catalog: catalog,
        );

        await openMyPosts(tester);
        await tester.tap(find.text('Lamp'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Your Listing'), findsOneWidget);
        expect(find.textContaining('sends this listing back'), findsOneWidget);
      },
    );
  });

  group('My Posts', () {
    FakeListingRepository seeded() => FakeListingRepository()
      ..listings.addAll(const [
        ListingSummary(
          id: 'a',
          title: 'Active Lamp',
          status: ListingStatus.active,
          price: 500,
          totalStock: 3,
        ),
        ListingSummary(
          id: 'r',
          title: 'Rejected Lamp',
          status: ListingStatus.rejected,
          rejectionReason: 'The brand looks fake.',
        ),
        ListingSummary(
          id: 'd',
          title: 'Draft Lamp',
          status: ListingStatus.draft,
        ),
        ListingSummary(
          id: 'i',
          title: 'Waiting Lamp',
          status: ListingStatus.inReview,
        ),
      ]);

    testWidgets('shows statuses and the rejection reason', (tester) async {
      await pumpTall(tester, listings: seeded());

      await openMyPosts(tester);

      expect(find.text('Active'), findsWidgets);
      expect(find.text('৳500 · 3 in stock'), findsOneWidget);
      expect(
        find.text('Why it was rejected: The brand looks fake.'),
        findsOneWidget,
      );
      expect(find.text('In review'), findsWidgets);
      expect(find.text('Post New Product'), findsOneWidget);
    });

    testWidgets('tabs filter the list', (tester) async {
      await pumpTall(tester, listings: seeded());
      await openMyPosts(tester);

      await tester.tap(find.widgetWithText(Tab, 'Draft'));
      await tester.pumpAndSettle();

      expect(find.text('Draft Lamp'), findsOneWidget);
      expect(find.text('Active Lamp'), findsNothing);
    });

    testWidgets('pausing is offered only on live listings', (tester) async {
      final listings = seeded();
      await pumpTall(tester, listings: listings);
      await openMyPosts(tester);

      await tester.tap(find.byTooltip('Listing actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(listings.pausedCalls.single, ('a', true));

      await tester.tap(find.byTooltip('Listing actions').at(2));
      await tester.pumpAndSettle();
      expect(find.text('Pause'), findsNothing);
    });

    testWidgets('deleting asks first', (tester) async {
      final listings = seeded();
      await pumpTall(tester, listings: listings);
      await openMyPosts(tester);

      await tester.tap(find.byTooltip('Listing actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this listing?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(listings.deleted, isEmpty);

      await tester.tap(find.byTooltip('Listing actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(listings.deleted, ['a']);
      expect(find.text('Active Lamp'), findsNothing);
    });

    testWidgets('guests cannot open My Posts', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      expect(find.byTooltip('Account'), findsNothing);
    });
  });
}
