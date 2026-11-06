import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/paging.dart';
import '../../core/errors/error_mapper.dart';

class AdminBanner {
  const AdminBanner({
    required this.id,
    required this.imagePath,
    required this.imageUrl,
    required this.title,
    required this.sortOrder,
    required this.isActive,
    this.productId,
    this.endsAt,
  });

  final String id;
  final String imagePath;
  final String imageUrl;
  final String title;
  final String? productId;
  final int sortOrder;
  final bool isActive;
  final DateTime? endsAt;
}

class BannerInput {
  const BannerInput({
    required this.imagePath,
    required this.title,
    required this.sortOrder,
    required this.isActive,
    this.productId,
    this.endsAt,
  });

  final String imagePath;
  final String title;
  final String? productId;
  final int sortOrder;
  final bool isActive;
  final DateTime? endsAt;
}

abstract interface class BannersRepository {
  Future<ItemPage<AdminBanner>> getBanners();

  /// Returns the path to save with the banner.
  Future<String> uploadImage(Uint8List bytes, {required bool isPng});

  /// A null [id] creates a new banner.
  Future<void> save(String? id, BannerInput input);

  Future<void> delete(String id);
}

class BannersRepositoryImpl implements BannersRepository {
  const BannersRepositoryImpl(this._client);

  final SupabaseClient _client;

  StorageFileApi get _bucket => _client.storage.from('banners');

  @override
  Future<ItemPage<AdminBanner>> getBanners() {
    return guardFailures(() async {
      final rows = await _client
          .from('home_banners')
          .select(
            'id, image_path, title, product_id, sort_order, is_active, ends_at',
          )
          .order('sort_order', ascending: true);
      return ItemPage(
        items: rows.map((row) {
          final path = row['image_path'] as String;
          final endsAt = row['ends_at'] as String?;
          return AdminBanner(
            id: row['id'] as String,
            imagePath: path,
            imageUrl: _bucket.getPublicUrl(path),
            title: row['title'] as String,
            productId: row['product_id'] as String?,
            sortOrder: (row['sort_order'] as num).toInt(),
            isActive: row['is_active'] as bool,
            endsAt: endsAt == null ? null : parseTime(endsAt),
          );
        }).toList(),
      );
    });
  }

  @override
  Future<String> uploadImage(Uint8List bytes, {required bool isPng}) {
    return guardFailures(() async {
      final extension = isPng ? 'png' : 'jpg';
      final path = '${DateTime.now().microsecondsSinceEpoch}.$extension';
      await _bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: isPng ? 'image/png' : 'image/jpeg',
        ),
      );
      return path;
    });
  }

  @override
  Future<void> save(String? id, BannerInput input) {
    return guardFailures(
      () => _client.rpc<String>(
        'admin_save_banner',
        params: {
          'p_id': id,
          'p_image_path': input.imagePath,
          'p_title': input.title,
          'p_product_id': input.productId,
          'p_sort_order': input.sortOrder,
          'p_is_active': input.isActive,
          'p_ends_at': input.endsAt?.toUtc().toIso8601String(),
        },
      ),
    );
  }

  @override
  Future<void> delete(String id) {
    return guardFailures(() async {
      final path = await _client.rpc<String>(
        'admin_delete_banner',
        params: {'p_id': id},
      );
      await _bucket.remove([path]);
    });
  }
}
