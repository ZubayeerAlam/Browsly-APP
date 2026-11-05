import '../../../orders/data/models/order_models.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/sale.dart';

abstract final class SaleModel {
  /// The database statuses behind each tab.
  static List<String> statusesFor(SaleTab tab) {
    return switch (tab) {
      SaleTab.pending => ['pending'],
      SaleTab.packaging => ['packaging'],
      SaleTab.outForDelivery => ['out_for_delivery'],
      SaleTab.completed => ['completed'],
      SaleTab.closed => ['cancelled', 'delivery_failed'],
    };
  }

  /// [rows] holds one extra row when another page exists.
  static SalePage pageFromRows(
    List<Map<String, dynamic>> rows,
    int limit,
    ImageUrlBuilder imageUrl,
  ) {
    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.sublist(0, limit) : rows;
    return SalePage(
      items: pageRows.map((row) => _summary(row, imageUrl)).toList(),
      next: hasMore ? _cursor(pageRows.last) : null,
    );
  }

  static PageCursor _cursor(Map<String, dynamic> row) {
    return PageCursor(
      key: row['cursor_key'] as String,
      id: row['id'] as String,
    );
  }

  static SaleSummary _summary(
    Map<String, dynamic> json,
    ImageUrlBuilder imageUrl,
  ) {
    final imagePath = json['first_image_path'] as String?;
    return SaleSummary(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      status: OrderModel.statusFromJson(json['status'] as String),
      amountToCollect: (json['amount_to_collect'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      recipientName: json['recipient_name'] as String,
      itemCount: (json['item_count'] as num).toInt(),
      firstTitle: json['first_title'] as String,
      firstImageUrl: imagePath == null ? null : imageUrl(imagePath),
    );
  }

  static SaleDetail detailFromJson(
    Map<String, dynamic> json,
    ImageUrlBuilder imageUrl,
  ) {
    return SaleDetail(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      status: OrderModel.statusFromJson(json['status'] as String),
      subtotal: (json['subtotal'] as num).toDouble(),
      deliveryFee: (json['delivery_fee'] as num).toDouble(),
      commissionTotal: (json['commission_total'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      buyer: OrderModel.addressFromJson(
        json['shipping_address'] as Map<String, dynamic>,
      ),
      items: (json['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((item) => OrderModel.itemFromJson(item, imageUrl))
          .toList(),
      history: (json['history'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (event) => OrderStatusEvent(
              status: OrderModel.statusFromJson(event['status'] as String),
              note: event['note'] as String?,
              createdAt: DateTime.parse(event['created_at'] as String)
                  .toLocal(),
            ),
          )
          .toList(),
    );
  }

  static CommissionSummary summaryFromJson(Map<String, dynamic> json) {
    return CommissionSummary(
      balance: (json['balance'] as num).toDouble(),
      totalCharged: (json['total_charged'] as num).toDouble(),
      totalPaid: (json['total_paid'] as num).toDouble(),
      commissionRate: (json['commission_rate'] as num).toDouble(),
      blockLimit: (json['block_limit'] as num).toDouble(),
      isBlocked: json['is_blocked'] as bool,
    );
  }

  /// [rows] holds one extra row when another page exists.
  static CommissionPage entriesFromRows(
    List<Map<String, dynamic>> rows,
    int limit,
  ) {
    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.sublist(0, limit) : rows;
    return CommissionPage(
      items: pageRows.map(_entry).toList(),
      next: hasMore ? _cursor(pageRows.last) : null,
    );
  }

  static CommissionEntry _entry(Map<String, dynamic> json) {
    return CommissionEntry(
      id: json['id'] as String,
      type: switch (json['type'] as String) {
        'charge' => CommissionEntryType.charge,
        'settlement' => CommissionEntryType.settlement,
        _ => CommissionEntryType.adjustment,
      },
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      orderNumber: json['order_number'] as String?,
      method: switch (json['method'] as String?) {
        'bkash' => 'bKash',
        'bank' => 'Bank',
        _ => null,
      },
      reference: json['reference'] as String?,
      note: json['note'] as String?,
    );
  }
}
