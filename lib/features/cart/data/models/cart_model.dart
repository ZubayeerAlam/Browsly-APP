import '../../domain/entities/cart.dart';

abstract final class CartModel {
  static Cart fromJson(
    Map<String, dynamic> json,
    String Function(String path) imageUrl,
  ) {
    return Cart(
      shops: (json['shops'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((shop) => _shop(shop, imageUrl))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      deliveryTotal: (json['delivery_total'] as num).toDouble(),
      grandTotal: (json['grand_total'] as num).toDouble(),
      itemCount: (json['item_count'] as num).toInt(),
      canCheckout: json['can_checkout'] as bool,
    );
  }

  static CartShop _shop(
    Map<String, dynamic> json,
    String Function(String path) imageUrl,
  ) {
    return CartShop(
      id: json['shop_id'] as String,
      name: json['shop_name'] as String,
      deliveryFee: (json['delivery_fee'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      lines: (json['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((line) => _line(line, imageUrl))
          .toList(),
    );
  }

  static CartLine _line(
    Map<String, dynamic> json,
    String Function(String path) imageUrl,
  ) {
    final variantName = json['variant_name'] as String;
    final imagePath = json['image_path'] as String?;
    return CartLine(
      variantId: json['variant_id'] as String,
      productId: json['product_id'] as String,
      title: json['title'] as String,
      variantLabel: variantName == 'Default' ? null : variantName,
      imageUrl: imagePath == null ? null : imageUrl(imagePath),
      unitPrice: (json['unit_price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      stock: (json['stock'] as num).toInt(),
      problem: switch (json['problem'] as String?) {
        'OWN_PRODUCT' => CartProblem.ownProduct,
        'PRODUCT_UNAVAILABLE' => CartProblem.unavailable,
        'OUT_OF_STOCK' => CartProblem.outOfStock,
        'LOW_STOCK' => CartProblem.lowStock,
        _ => null,
      },
    );
  }
}
