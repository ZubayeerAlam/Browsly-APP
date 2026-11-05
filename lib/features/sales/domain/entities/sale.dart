import '../../../orders/domain/entities/order.dart';

/// The tabs on the Sales screen.
enum SaleTab {
  pending('Pending'),
  packaging('Packaging'),
  outForDelivery('Out for delivery'),
  completed('Complete'),
  closed('Cancelled');

  const SaleTab(this.label);

  final String label;
}

/// One seller's part of an order, as shown in the Sales list.
class SaleSummary {
  const SaleSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.amountToCollect,
    required this.createdAt,
    required this.recipientName,
    required this.itemCount,
    required this.firstTitle,
    this.firstImageUrl,
  });

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final double amountToCollect;
  final DateTime createdAt;
  final String recipientName;
  final int itemCount;
  final String firstTitle;
  final String? firstImageUrl;
}

/// Where the next page starts. Comes from the server, and is never built here.
class PageCursor {
  const PageCursor({required this.key, required this.id});

  final String key;
  final String id;
}

class SalePage {
  const SalePage({required this.items, this.next});

  final List<SaleSummary> items;

  /// Null when this is the last page.
  final PageCursor? next;
}

class SaleDetail {
  const SaleDetail({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.commissionTotal,
    required this.createdAt,
    required this.buyer,
    required this.items,
    required this.history,
  });

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final double subtotal;
  final double deliveryFee;

  /// 1% of the items at the rate when ordered, excluding the delivery fee.
  final double commissionTotal;
  final DateTime createdAt;
  final ShippingAddress buyer;
  final List<OrderItem> items;
  final List<OrderStatusEvent> history;

  double get amountToCollect => subtotal + deliveryFee;
}

class CommissionSummary {
  const CommissionSummary({
    required this.balance,
    required this.totalCharged,
    required this.totalPaid,
    required this.commissionRate,
    required this.blockLimit,
    required this.isBlocked,
  });

  final double balance;
  final double totalCharged;
  final double totalPaid;
  final double commissionRate;
  final double blockLimit;
  final bool isBlocked;
}

enum CommissionEntryType { charge, settlement, adjustment }

class CommissionEntry {
  const CommissionEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.orderNumber,
    this.method,
    this.reference,
    this.note,
  });

  final String id;
  final CommissionEntryType type;

  /// Positive adds to what the seller owes, and negative lowers it.
  final double amount;
  final DateTime createdAt;
  final String? orderNumber;
  final String? method;
  final String? reference;
  final String? note;
}

class CommissionPage {
  const CommissionPage({required this.items, this.next});

  final List<CommissionEntry> items;

  /// Null when this is the last page.
  final PageCursor? next;
}
