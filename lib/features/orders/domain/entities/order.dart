enum OrderStatus {
  pending('Pending'),
  packaging('Packaging'),
  outForDelivery('Out for delivery'),
  completed('Complete'),
  cancelled('Cancelled'),
  deliveryFailed('Delivery failed');

  const OrderStatus(this.label);

  final String label;

  /// The server makes the final decision on this.
  bool get canCancel => this == pending || this == packaging;

  /// Nothing will be collected for this part of the order.
  bool get isClosedWithoutPayment =>
      this == cancelled || this == deliveryFailed;
}

/// One step an order has been through.
class OrderStatusEvent {
  const OrderStatusEvent({
    required this.status,
    required this.createdAt,
    this.note,
  });

  final OrderStatus status;
  final DateTime createdAt;

  /// Such as why the seller cancelled.
  final String? note;
}

/// Answers from `place_order`, and the same order when a request is retried.
class PlacedOrder {
  const PlacedOrder({required this.id, required this.orderNumber});

  final String id;
  final String orderNumber;
}

/// One seller's part of an order, as shown in My Orders.
class OrderGroupSummary {
  const OrderGroupSummary({
    required this.id,
    required this.shopName,
    required this.status,
    required this.itemCount,
    required this.firstTitle,
    this.firstImageUrl,
  });

  final String id;
  final String shopName;
  final OrderStatus status;
  final int itemCount;
  final String firstTitle;
  final String? firstImageUrl;
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.grandTotal,
    required this.createdAt,
    required this.groups,
  });

  final String id;
  final String orderNumber;
  final double grandTotal;
  final DateTime createdAt;
  final List<OrderGroupSummary> groups;
}

/// Where the next page starts. Comes from the server, and is never built here.
class OrderCursor {
  const OrderCursor({required this.key, required this.id});

  final String key;
  final String id;
}

class OrderPage {
  const OrderPage({required this.items, this.next});

  final List<OrderSummary> items;

  /// Null when this is the last page.
  final OrderCursor? next;
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.title,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.productId,
    this.variantLabel,
    this.imageUrl,
  });

  final String id;

  /// Null if the seller's account has since been deleted.
  final String? productId;
  final String title;
  final String? variantLabel;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
}

class OrderGroup {
  const OrderGroup({
    required this.id,
    required this.shopName,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.items,
    this.history = const [],
    this.shopId,
  });

  final String id;

  /// Null if the seller's account has since been deleted.
  final String? shopId;
  final String shopName;
  final OrderStatus status;
  final double subtotal;
  final double deliveryFee;
  final List<OrderItem> items;
  final List<OrderStatusEvent> history;
}

/// A copy from when the order was placed, so later edits don't change it.
class ShippingAddress {
  const ShippingAddress({
    required this.recipientName,
    this.phone,
    this.line1,
    this.region,
    this.postalCode,
  });

  final String recipientName;
  final String? phone;
  final String? line1;
  final String? region;
  final String? postalCode;

  String get fullAddress => [?line1, ?region, ?postalCode].join(', ');
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.orderNumber,
    required this.subtotal,
    required this.deliveryTotal,
    required this.grandTotal,
    required this.createdAt,
    required this.groups,
    this.shippingAddress,
  });

  final String id;
  final String orderNumber;
  final double subtotal;
  final double deliveryTotal;
  final double grandTotal;
  final DateTime createdAt;
  final List<OrderGroup> groups;
  final ShippingAddress? shippingAddress;

  /// What the buyer still pays, leaving out cancelled parts of the order.
  double get amountToPay => groups
      .where((group) => !group.status.isClosedWithoutPayment)
      .fold(0, (sum, group) => sum + group.subtotal + group.deliveryFee);

  bool get hasClosedParts =>
      groups.any((group) => group.status.isClosedWithoutPayment);
}
