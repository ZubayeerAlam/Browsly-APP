import 'dart:typed_data';

import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/features/catalog/domain/entities/category.dart';
import 'package:browsly_app/features/listings/data/models/listing_models.dart';
import 'package:browsly_app/features/listings/domain/entities/listing.dart';
import 'package:browsly_app/features/listings/presentation/providers/my_listings_provider.dart';
import 'package:browsly_app/features/listings/presentation/providers/product_form_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

final original = Uint8List.fromList([1, 2, 3]);
final prepared = Uint8List.fromList([9, 9]);

void main() {
  late FakeListingRepository listings;
  late FakeCatalogRepository catalog;
  late FakeShopRepository shops;

  ProductFormProvider build({String? editId}) => ProductFormProvider(
    listings,
    catalog,
    shops,
    editId: editId,
    preparePhoto: (_) async => prepared,
  );

  Future<ProductFormProvider> filled() async {
    final form = build();
    await form.load();
    await form.addPhotos([original]);
    form
      ..title = 'Good Lamp'
      ..description = 'A very good lamp.'
      ..categoryId = 'leaf'
      ..price = 500
      ..stock = 3;
    return form;
  }

  setUp(() {
    listings = FakeListingRepository();
    shops = FakeShopRepository();
    catalog = FakeCatalogRepository()
      ..categories = const [
        Category(id: 'parent', name: 'Home', icon: 'chair', productCount: 0),
        Category(
          id: 'leaf',
          parentId: 'parent',
          name: 'Kitchen',
          icon: 'chair',
          productCount: 0,
        ),
        Category(id: 'books', name: 'Books', icon: 'book', productCount: 0),
      ];
  });

  group('loading', () {
    test('asks for a shop first when the seller has none', () async {
      shops.shop = null;
      final form = build();

      await form.load();

      expect(form.loadState, FormLoadState.needsShop);
    });

    test('offers only the most specific categories', () async {
      final form = build();

      await form.load();

      expect(form.categories.map((choice) => choice.label), [
        'Books',
        'Home › Kitchen',
      ]);
    });

    test('a failure can be retried', () async {
      shops.failWith = const NetworkFailure();
      final form = build();
      await form.load();
      expect(form.loadState, FormLoadState.failed);

      shops.failWith = null;
      await form.load();
      expect(form.loadState, FormLoadState.ready);
    });

    test('a listing that is not available says so', () async {
      final form = build(editId: 'gone');

      await form.load();

      expect(form.loadState, FormLoadState.notFound);
    });
  });

  group('photos', () {
    test('only prepared bytes are ever kept or uploaded', () async {
      final form = await filled();

      await form.saveDraft();

      expect(form.photos.single.bytes, prepared);
      expect(listings.uploads.single, prepared);
      expect(listings.uploads.single, isNot(original));
    });

    test(
      'a photo that cannot be prepared is left out, and explained',
      () async {
        final form = ProductFormProvider(
          listings,
          catalog,
          shops,
          preparePhoto: (_) => Future.error(Exception('bad file')),
        );
        await form.load();

        await form.addPhotos([original]);

        expect(form.photos, isEmpty);
        expect(form.failure, contains('not added'));
      },
    );

    test('stops at five photos', () async {
      final form = build();
      await form.load();

      await form.addPhotos(List.filled(7, original));

      expect(form.photos, hasLength(5));
      expect(form.failure, contains('up to 5'));
    });

    test('a retry does not upload the same photo again', () async {
      final form = await filled();
      listings.failWith = const NetworkFailure();
      expect(await form.saveDraft(), isFalse);

      listings.failWith = null;
      expect(await form.saveDraft(), isTrue);

      expect(listings.uploads, hasLength(1));
    });

    test('a removed photo is deleted only after the save works', () async {
      listings.editable['p'] = const EditableListing(
        id: 'p',
        title: 'Lamp',
        description: 'A very good lamp.',
        categoryId: 'leaf',
        isNew: true,
        status: ListingStatus.active,
        photos: [ListingPhotoRef(path: 'shop-1/old.jpg', url: 'u')],
        variants: [ListingVariant(price: 5, stock: 1)],
      );
      final form = build(editId: 'p');
      await form.load();
      form.removePhoto(form.photos.single);

      listings.failWith = const NetworkFailure();
      await form.saveDraft();
      expect(listings.removedPaths, isEmpty);

      listings.failWith = null;
      await form.saveDraft();
      expect(listings.removedPaths, ['shop-1/old.jpg']);
    });
  });

  group('colours and sizes', () {
    test('no options means one default variant', () async {
      final form = await filled();

      await form.saveDraft();

      final variant = listings.saves.single.variants.single;
      expect(variant.colour, isNull);
      expect(variant.price, 500);
      expect(variant.stock, 3);
    });

    test('options make every combination, from the main price', () async {
      final form = await filled();
      form
        ..addColour('Red')
        ..addColour('Blue')
        ..addSize('M');

      expect(form.rows.map((row) => row.label), ['Red / M', 'Blue / M']);
      expect(form.rows.first.price, 500);
    });

    test('typed values survive adding another option', () async {
      final form = await filled();
      form.addColour('Red');
      form.setRowPrice(form.rows.single, 750);

      form.addColour('Blue');

      expect(form.rows.first.price, 750);
    });

    test('duplicates and blanks are ignored', () async {
      final form = await filled();

      form
        ..addColour('Red')
        ..addColour(' red ')
        ..addColour('   ');

      expect(form.colours, ['Red']);
    });

    test('stops at 50 combinations', () async {
      final form = await filled();
      for (var i = 0; i < 10; i++) {
        form.addColour('C$i');
      }
      for (var i = 0; i < 6; i++) {
        form.addSize('S$i');
      }

      expect(form.rows, hasLength(50));
      expect(form.failure, contains('50'));
    });

    test('removing the last option returns to one variant', () async {
      final form = await filled();
      form.addSize('M');

      form.removeSize('M');

      expect(form.hasOptions, isFalse);
      expect(form.rows, isEmpty);
    });

    test('a discount is only sent where it is really a discount', () async {
      final form = await filled();
      form.compareAtPrice = 600;
      form.addColour('Red');
      form.addColour('Gold');
      form.setRowPrice(form.rows.last, 800);

      await form.saveDraft();

      final variants = listings.saves.single.variants;
      expect(variants[0].compareAtPrice, 600);
      expect(variants[1].compareAtPrice, isNull);
    });

    test('a combination without a price cannot be saved', () async {
      final form = await filled();
      form.addColour('Red');
      form.setRowPrice(form.rows.single, null);

      expect(await form.saveDraft(), isFalse);
      expect(form.failure, contains('price for Red'));
      expect(listings.saves, isEmpty);
    });
  });

  group('submitting', () {
    test('saves and then sends a new listing to review', () async {
      final form = await filled();

      expect(await form.submit(), isTrue);

      expect(listings.saves, hasLength(1));
      expect(listings.submitted, ['new-listing']);
      expect(form.status, ListingStatus.inReview);
    });

    test('a save then submit keeps the same listing', () async {
      final form = await filled();
      await form.saveDraft();

      await form.submit();

      expect(listings.saves.last.id, 'new-listing');
    });

    test('a rejected listing can be sent again', () async {
      listings.editable['p'] = const EditableListing(
        id: 'p',
        title: 'Lamp',
        description: 'A very good lamp.',
        categoryId: 'leaf',
        isNew: true,
        status: ListingStatus.rejected,
        photos: [ListingPhotoRef(path: 'a.jpg', url: 'u')],
        variants: [ListingVariant(price: 5, stock: 1)],
      );
      final form = build(editId: 'p');
      await form.load();

      await form.submit();

      expect(listings.submitted, ['p']);
    });

    test('a live listing is saved, and the server decides on review', () async {
      listings.editable['p'] = const EditableListing(
        id: 'p',
        title: 'Lamp',
        description: 'A very good lamp.',
        categoryId: 'leaf',
        isNew: true,
        status: ListingStatus.active,
        photos: [ListingPhotoRef(path: 'a.jpg', url: 'u')],
        variants: [ListingVariant(price: 5, stock: 1)],
      );
      final form = build(editId: 'p');
      await form.load();

      await form.submit();

      expect(listings.saves, hasLength(1));
      expect(listings.submitted, isEmpty);
    });

    test('no photo cannot be submitted, but can be drafted', () async {
      final form = build();
      await form.load();
      form
        ..title = 'Good Lamp'
        ..description = 'A very good lamp.'
        ..categoryId = 'leaf'
        ..price = 500
        ..stock = 3;

      expect(await form.submit(), isFalse);
      expect(form.failure, contains('photo'));
      expect(listings.saves, isEmpty);

      expect(await form.saveDraft(), isTrue);
    });

    test('a short description cannot be submitted', () async {
      final form = await filled();
      form.description = 'Short';

      expect(await form.submit(), isFalse);
      expect(listings.submitted, isEmpty);
    });

    test('server refusals become clear messages', () async {
      final form = await filled();
      listings.failSubmitWith = const ServerFailure(
        'That did not work.',
        code: 'SUBMISSION_LIMIT',
      );

      expect(await form.submit(), isFalse);

      expect(form.failure, contains('limit'));
    });

    test('a draft cannot be saved without the basics', () async {
      final form = build();
      await form.load();

      expect(await form.saveDraft(), isFalse);

      expect(form.failure, contains('name, category'));
      expect(listings.saves, isEmpty);
    });

    test('double taps run once', () async {
      final form = await filled();

      final results = await Future.wait([form.submit(), form.submit()]);

      expect(results, [true, false]);
      expect(listings.saves, hasLength(1));
    });
  });

  group('editing', () {
    test('fills the form, including colours and sizes', () async {
      listings.editable['p'] = const EditableListing(
        id: 'p',
        title: 'Lamp',
        description: 'A very good lamp.',
        categoryId: 'leaf',
        isNew: false,
        status: ListingStatus.active,
        photos: [ListingPhotoRef(path: 'a.jpg', url: 'u')],
        variants: [
          ListingVariant(colour: 'Red', size: 'M', price: 5, stock: 1),
          ListingVariant(colour: 'Red', size: 'L', price: 6, stock: 2),
        ],
      );
      final form = build(editId: 'p');

      await form.load();

      expect(form.title, 'Lamp');
      expect(form.isNew, isFalse);
      expect(form.colours, ['Red']);
      expect(form.sizes, ['M', 'L']);
      expect(form.rows.last.price, 6);
      expect(form.warnsAboutReview, isTrue);
      expect(form.isDirty, isFalse);
    });
  });

  group('models', () {
    test('both review statuses look the same to a seller', () {
      expect(
        ListingModels.statusFromJson('pending_review'),
        ListingStatus.inReview,
      );
      expect(
        ListingModels.statusFromJson('admin_review'),
        ListingStatus.inReview,
      );
    });

    test('each tab asks for the right statuses', () {
      expect(ListingModels.statusesForTab(ListingTab.all), isNull);
      expect(ListingModels.statusesForTab(ListingTab.active), [
        'active',
        'paused',
      ]);
      expect(ListingModels.statusesForTab(ListingTab.inReview), [
        'pending_review',
        'admin_review',
      ]);
    });

    test('variants become the save parameters', () {
      final params = ListingModels.inputToParams(
        const ListingInput(
          id: null,
          title: 'T',
          description: 'D',
          categoryId: 'c',
          isNew: false,
          photoPaths: ['a.jpg'],
          variants: [
            ListingVariant(price: 5, stock: 1),
            ListingVariant(
              colour: 'Red',
              price: 6,
              stock: 2,
              compareAtPrice: 9,
            ),
          ],
        ),
      );

      expect(params['p_condition'], 'used');
      final variants = params['p_variants'] as List<dynamic>;
      expect(variants[0]['options'], <String, dynamic>{});
      expect(variants[1]['options'], {'colour': 'Red'});
      expect(variants[1]['compare_at_price'], 9);
    });
  });

  group('My Posts', () {
    test('changing tab asks for that tab', () async {
      final provider = MyListingsProvider(listings);
      await provider.load();

      await provider.setTab(ListingTab.draft);

      expect(listings.tabsRequested.last, ListingTab.draft);
    });

    test('a failed action is explained and keeps the list', () async {
      listings.listings.add(
        const ListingSummary(id: 'a', title: 'A', status: ListingStatus.draft),
      );
      final provider = MyListingsProvider(listings);
      await provider.load();
      listings.failWith = const ServerFailure(
        'x',
        code: 'PRODUCT_NOT_PAUSABLE',
      );

      await provider.setPaused(listings.listings.single, paused: true);

      expect(provider.actionFailure, contains('live listings'));
      expect(provider.state.data, hasLength(1));
    });

    test('deleting refreshes the list', () async {
      listings.listings.add(
        const ListingSummary(id: 'a', title: 'A', status: ListingStatus.draft),
      );
      final provider = MyListingsProvider(listings);
      await provider.load();

      await provider.delete(listings.listings.single);

      expect(listings.deleted, ['a']);
      expect(provider.state.data, isNull);
    });
  });
}
