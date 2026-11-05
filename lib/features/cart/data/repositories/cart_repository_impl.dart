import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/cart.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_remote_data_source.dart';
import '../models/cart_model.dart';

class CartRepositoryImpl implements CartRepository {
  const CartRepositoryImpl(this._dataSource);

  final CartRemoteDataSource _dataSource;

  Future<Cart> _run(Future<Map<String, dynamic>> Function() action) {
    return guardFailures(() async {
      return CartModel.fromJson(await action(), _dataSource.productImageUrl);
    });
  }

  @override
  Future<Cart> getCart() => _run(_dataSource.getCart);

  @override
  Future<Cart> getBuyNow(String variantId) {
    return _run(() => _dataSource.getBuyNow(variantId));
  }

  @override
  Future<Cart> addVariant(String variantId) {
    return _run(() => _dataSource.addVariant(variantId));
  }

  @override
  Future<Cart> addProduct(String productId) {
    return _run(() => _dataSource.addProduct(productId));
  }

  @override
  Future<Cart> setQuantity(String variantId, int quantity) {
    return _run(() => _dataSource.setQuantity(variantId, quantity));
  }
}
