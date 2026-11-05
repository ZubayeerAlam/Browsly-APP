import '../entities/cart.dart';

/// Every change returns the updated cart, so screens never need to reload.
abstract interface class CartRepository {
  Future<Cart> getCart();

  /// One of this item, in the same shape as a cart, for Buy Now.
  Future<Cart> getBuyNow(String variantId);

  Future<Cart> addVariant(String variantId);

  /// For product cards. Fails with `VARIANT_REQUIRED` if there are choices.
  Future<Cart> addProduct(String productId);

  /// Zero removes the line.
  Future<Cart> setQuantity(String variantId, int quantity);
}
