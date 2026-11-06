import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/paging.dart';
import '../../core/errors/error_mapper.dart';

class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.sortOrder,
    required this.isActive,
    required this.productCount,
    this.parentId,
  });

  final String id;
  final String? parentId;
  final String name;
  final String slug;
  final String icon;
  final int sortOrder;
  final bool isActive;
  final int productCount;
}

class CategoryInput {
  const CategoryInput({
    required this.name,
    required this.slug,
    required this.icon,
    required this.sortOrder,
    required this.isActive,
    this.parentId,
  });

  final String? parentId;
  final String name;
  final String slug;
  final String icon;
  final int sortOrder;
  final bool isActive;
}

abstract interface class CategoriesRepository {
  Future<ItemPage<AdminCategory>> getCategories();

  /// A null [id] creates a new category.
  Future<void> save(String? id, CategoryInput input);
}

class CategoriesRepositoryImpl implements CategoriesRepository {
  const CategoriesRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<ItemPage<AdminCategory>> getCategories() {
    return guardFailures(() async {
      final rows = await _client.rpc<List<dynamic>>('admin_list_categories');
      return ItemPage(
        items: rows.cast<Map<String, dynamic>>().map((row) {
          return AdminCategory(
            id: row['id'] as String,
            parentId: row['parent_id'] as String?,
            name: row['name'] as String,
            slug: row['slug'] as String,
            icon: row['icon'] as String,
            sortOrder: (row['sort_order'] as num).toInt(),
            isActive: row['is_active'] as bool,
            productCount: (row['product_count'] as num).toInt(),
          );
        }).toList(),
      );
    });
  }

  @override
  Future<void> save(String? id, CategoryInput input) {
    return guardFailures(
      () => _client.rpc<String>(
        'admin_save_category',
        params: {
          'p_id': id,
          'p_parent_id': input.parentId,
          'p_name': input.name,
          'p_slug': input.slug,
          'p_icon': input.icon,
          'p_sort_order': input.sortOrder,
          'p_is_active': input.isActive,
        },
      ),
    );
  }
}
