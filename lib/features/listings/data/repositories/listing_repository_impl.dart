import 'dart:math';
import 'dart:typed_data';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/listing_repository.dart';
import '../datasources/listing_remote_data_source.dart';
import '../models/listing_models.dart';

class ListingRepositoryImpl implements ListingRepository {
  ListingRepositoryImpl(this._dataSource);

  final ListingRemoteDataSource _dataSource;
  final _random = Random.secure();

  @override
  Future<ListingPage> getMyListings(
    ListingTab tab, {
    ListingCursor? cursor,
    int limit = 20,
  }) {
    return guardFailures(() async {
      // One extra row shows whether another page exists.
      final rows = await _dataSource.fetchMyListings({
        'p_statuses': ListingModels.statusesForTab(tab),
        'p_cursor_key': cursor?.key,
        'p_cursor_id': cursor?.id,
        'p_limit': limit + 1,
      });
      return ListingModels.pageFromRows(rows, limit, _dataSource.photoUrl);
    });
  }

  @override
  Future<EditableListing?> getListing(String id) {
    return guardFailures(() async {
      final shopId = await _dataSource.fetchMyShopId();
      if (shopId == null) return null;
      final row = await _dataSource.fetchListing(id, shopId);
      return row == null
          ? null
          : ListingModels.editableFromJson(row, _dataSource.photoUrl);
    });
  }

  @override
  Future<String> uploadPhoto(String shopId, Uint8List jpegBytes) {
    return guardFailures(() async {
      // A random name means photos never collide or show a stale cached image.
      final name = List.generate(
        16,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final path = '$shopId/$name.jpg';
      await _dataSource.uploadPhoto(path, jpegBytes);
      return path;
    });
  }

  @override
  Future<String> save(ListingInput input) {
    return guardFailures(
      () => _dataSource.save(ListingModels.inputToParams(input)),
    );
  }

  @override
  Future<void> submitForReview(String id) {
    return guardFailures(() => _dataSource.submit(id));
  }

  @override
  Future<void> setPaused(String id, {required bool paused}) {
    return guardFailures(() => _dataSource.setPaused(id, paused));
  }

  @override
  Future<void> delete(String id) {
    return guardFailures(() async {
      final paths = await _dataSource.delete(id);
      await removePhotos(paths);
    });
  }

  @override
  Future<void> removePhotos(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _dataSource.removePhotos(paths);
    } catch (_) {
      // The listing is already updated, so a leftover file is harmless.
    }
  }
}
