/// Where the next page starts. Comes from the server, and is never built here.
class PageCursor {
  const PageCursor({required this.key, required this.id});

  final String key;
  final String id;
}

class ItemPage<T> {
  const ItemPage({required this.items, this.next});

  final List<T> items;

  /// Null when this is the last page.
  final PageCursor? next;
}

/// Turns rows into a page. The functions are asked for one extra row, which
/// shows whether another page exists.
ItemPage<T> pageFromRows<T>(
  List<dynamic> result,
  int limit,
  T Function(Map<String, dynamic> row) parse,
) {
  final rows = result.cast<Map<String, dynamic>>();
  final hasMore = rows.length > limit;
  final pageRows = hasMore ? rows.sublist(0, limit) : rows;
  return ItemPage(
    items: pageRows.map(parse).toList(),
    next: hasMore
        ? PageCursor(
            key: pageRows.last['cursor_key'] as String,
            id: pageRows.last['id'] as String,
          )
        : null,
  );
}

DateTime parseTime(Object? value) => DateTime.parse(value as String).toLocal();

double parseMoney(Object? value) => (value as num? ?? 0).toDouble();
