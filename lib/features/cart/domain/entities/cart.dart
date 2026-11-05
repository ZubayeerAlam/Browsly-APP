/// Why a cart line can't be bought right now.
enum CartProblem { ownProduct, unavailable, outOfStock, lowStock }

class CartLine {
  const CartLine({
    required this.variantId,
    required this.productId,
    required this.title,
    required this.unitPrice,
    required this.quantity,
    required this.stock,
    this.variantLabel,
    this.imageUrl,
    this.problem,
  });

  final String variantId;
  final String productId;
  final String title;

  /// Such as "Red / M". Null for a product with no choices.
  final String? variantLabel;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;
  final int stock;
  final CartProblem? problem;

  double get lineTotal => unitPrice * quantity;
  bool get canRaiseQuantity => problem == null && quantity < stock;

  String? get problemMessage {
    return switch (problem) {
      null => null,
      CartProblem.ownProduct => 'This is your own listing',
      CartProblem.unavailable => 'No longer available',
      CartProblem.outOfStock => 'Out of stock',
      CartProblem.lowStock => 'Only $stock left. Please lower the quantity',
    };
  }
}

class CartShop {
  const CartShop({
    required this.id,
    required this.name,
    required this.deliveryFee,
    required this.subtotal,
    required this.lines,
  });

  final String id;
  final String name;
  final double deliveryFee;
  final double subtotal;
  final List<CartLine> lines;
}

/// A cart or a Buy Now item. All totals come from the server.
class Cart {
  const Cart({
    required this.shops,
    required this.subtotal,
    required this.deliveryTotal,
    required this.grandTotal,
    required this.itemCount,
    required this.canCheckout,
  });

  static const empty = Cart(
    shops: [],
    subtotal: 0,
    deliveryTotal: 0,
    grandTotal: 0,
    itemCount: 0,
    canCheckout: false,
  );

  final List<CartShop> shops;
  final double subtotal;
  final double deliveryTotal;
  final double grandTotal;
  final int itemCount;
  final bool canCheckout;

  bool get isEmpty => shops.isEmpty;
}
