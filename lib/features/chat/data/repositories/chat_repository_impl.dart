import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/chat.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._dataSource);

  final ChatRemoteDataSource _dataSource;

  String? _productImage(Object? path) =>
      path == null ? null : _dataSource.productImageUrl(path as String);

  String? _otherImage(Map<String, dynamic> json) {
    final path = json['other_image_path'] as String?;
    return path == null
        ? null
        : _dataSource.otherImageUrl(path, isSeller: json['is_seller'] as bool);
  }

  static ChatMessage _message(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String?,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  @override
  Future<ConversationPage> getConversations({
    ConversationCursor? cursor,
    int limit = 20,
  }) {
    return guardFailures(() async {
      // One extra row shows whether another page exists.
      final rows = await _dataSource.fetchConversations({
        'p_cursor_key': cursor?.key,
        'p_cursor_id': cursor?.id,
        'p_limit': limit + 1,
      });
      final hasMore = rows.length > limit;
      final pageRows = hasMore ? rows.sublist(0, limit) : rows;
      return ConversationPage(
        items: pageRows
            .map(
              (row) => Conversation(
                id: row['id'] as String,
                otherName: row['other_name'] as String,
                otherImageUrl: _otherImage(row),
                productTitle: row['product_title'] as String?,
                productImageUrl: _productImage(row['product_image_path']),
                lastMessage: (row['last_message'] as String?) ?? '',
                lastMessageAt: DateTime.parse(row['last_message_at'] as String)
                    .toLocal(),
                unreadCount: (row['unread_count'] as num).toInt(),
              ),
            )
            .toList(),
        next: hasMore
            ? ConversationCursor(
                key: pageRows.last['cursor_key'] as String,
                id: pageRows.last['id'] as String,
              )
            : null,
      );
    });
  }

  @override
  Future<ChatHeader?> getHeader(String conversationId) {
    return guardFailures(() async {
      final json = await _dataSource.fetchHeader(conversationId);
      if (json == null) return null;
      return ChatHeader(
        id: json['id'] as String,
        otherName: json['other_name'] as String,
        otherImageUrl: _otherImage(json),
        productId: json['product_id'] as String?,
        productTitle: json['product_title'] as String?,
        productPrice: (json['product_price'] as num?)?.toDouble(),
        productImageUrl: _productImage(json['product_image_path']),
      );
    });
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    DateTime? before,
    int limit = 30,
  }) {
    return guardFailures(() async {
      final rows = await _dataSource.fetchMessages(
        conversationId,
        before,
        limit,
      );
      return rows.map(_message).toList();
    });
  }

  @override
  Future<ChatMessage> send(String conversationId, String body) {
    return guardFailures(() async {
      return _message(await _dataSource.send(conversationId, body));
    });
  }

  @override
  Future<void> markRead(String conversationId) {
    return guardFailures(() => _dataSource.markRead(conversationId));
  }

  @override
  Future<String> startForProduct(String productId) {
    return guardFailures(() => _dataSource.startForProduct(productId));
  }

  @override
  Future<String> startForOrder(String groupId) {
    return guardFailures(() => _dataSource.startForOrder(groupId));
  }

  @override
  Stream<ChatMessage> watchMessages(String conversationId) {
    return _dataSource.watchMessages(conversationId).map(_message);
  }
}
