import '../../domain/entities/order.dart';

typedef ImageUrlBuilder = String Function(String path);

abstract final class OrderModel {
  /// The columns [detailFromJson] needs. Commission is not readable by buyers.
  static const detailColumns =
      'id, order_number, subtotal, delivery_total, grand_total, created_at, '
      'seller_order_groups(id, shop_id, shop_name, status, subtotal, '
      'delivery_fee, shipping_address, created_at, '
      'order_items(id, product_id, product_title, variant_name, image_path, '
      'unit_price, quantity, line_total, created_at))';

  static OrderStatus statusFromJson(String value) {
    return switch (value) {
      'packaging' => OrderStatus.packaging,
      'out_for_delivery' => OrderStatus.outForDelivery,
      'completed' => OrderStatus.completed,
      'cancelled' => OrderStatus.cancelled,
      'delivery_failed' => OrderStatus.deliveryFailed,
      _ => OrderStatus.pending,
    };
  }

  static PlacedOrder placedFromJson(Map<String, dynamic> json) {
    return PlacedOrder(
      id: json['order_id'] as String,
      orderNumber: json['order_number'] as String,
    );
  }

  /// [rows] holds one extra row when another page exists.
  static OrderPage pageFromRows(
    List<Map<String, dynamic>> rows,
    int limit,
    ImageUrlBuilder imageUrl,
  ) {
    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.sublist(0, limit) : rows;
    final last = pageRows.isEmpty ? null : pageRows.last;
    return OrderPage(
      items: pageRows.map((row) => _summary(row, imageUrl)).toList(),
      next: hasMore && last != null
          ? OrderCursor(
              key: last['cursor_key'] as String,
              id: last['id'] as String,
            )
          : null,
    );
  }

  static OrderSummary _summary(
    Map<String, dynamic> json,
    ImageUrlBuilder imageUrl,
  ) {
    return OrderSummary(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      grandTotal: (json['grand_total'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      groups: (json['groups'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((group) {
            final imagePath = group['first_image_path'] as String?;
            return OrderGroupSummary(
              id: group['id'] as String,
              shopName: group['shop_name'] as String,
              status: statusFromJson(group['status'] as String),
              itemCount: (group['item_count'] as num).toInt(),
              firstTitle: group['first_title'] as String,
              firstImageUrl: imagePath == null ? null : imageUrl(imagePath),
            );
          })
          .toList(),
    );
  }

  static OrderDetail detailFromJson(
    Map<String, dynamic> json,
    ImageUrlBuilder imageUrl,
  ) {
    final groupRows = (json['seller_order_groups'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final groups = groupRows.map((group) => _group(group, imageUrl)).toList()
      ..sort((a, b) => a.shopName.compareTo(b.shopName));
    return OrderDetail(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      subtotal: (json['subtotal'] as num).toDouble(),
      deliveryTotal: (json['delivery_total'] as num).toDouble(),
      grandTotal: (json['grand_total'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      groups: groups,
      shippingAddress: groupRows.isEmpty
          ? null
          : _address(
              groupRows.first['shipping_address'] as Map<String, dynamic>,
            ),
    );
  }

  static OrderGroup _group(
    Map<String, dynamic> json,
    ImageUrlBuilder imageUrl,
  ) {
    final items = (json['order_items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    items.sort(
      (a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String),
    );
    return OrderGroup(
      id: json['id'] as String,
      shopId: json['shop_id'] as String?,
      shopName: json['shop_name'] as String,
      status: statusFromJson(json['status'] as String),
      subtotal: (json['subtotal'] as num).toDouble(),
      deliveryFee: (json['delivery_fee'] as num).toDouble(),
      items: items.map((item) => _item(item, imageUrl)).toList(),
    );
  }

  static OrderItem _item(Map<String, dynamic> json, ImageUrlBuilder imageUrl) {
    final variantName = json['variant_name'] as String;
    final imagePath = json['image_path'] as String?;
    return OrderItem(
      id: json['id'] as String,
      productId: json['product_id'] as String?,
      title: json['product_title'] as String,
      variantLabel: variantName == 'Default' ? null : variantName,
      imageUrl: imagePath == null ? null : imageUrl(imagePath),
      unitPrice: (json['unit_price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      lineTotal: (json['line_total'] as num).toDouble(),
    );
  }

  static ShippingAddress _address(Map<String, dynamic> json) {
    return ShippingAddress(
      recipientName: json['recipient_name'] as String,
      phone: json['phone'] as String?,
      line1: json['line1'] as String?,
      region: json['region'] as String?,
      postalCode: json['postal_code'] as String?,
    );
  }
}
