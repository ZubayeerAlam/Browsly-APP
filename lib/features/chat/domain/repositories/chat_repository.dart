import '../entities/chat.dart';

abstract interface class ChatRepository {
  Future<ConversationPage> getConversations({
    ConversationCursor? cursor,
    int limit = 20,
  });

  /// Null if there is no such chat, or the user isn't part of it.
  Future<ChatHeader?> getHeader(String conversationId);

  /// Newest first. [before] asks for messages older than that time.
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    DateTime? before,
    int limit = 30,
  });

  Future<ChatMessage> send(String conversationId, String body);

  Future<void> markRead(String conversationId);

  /// Finds or creates the chat about a product, and returns its ID.
  Future<String> startForProduct(String productId);

  /// Finds or creates the chat about one seller's part of an order.
  Future<String> startForOrder(String groupId);

  /// New messages as they arrive. Stops when the subscription is cancelled.
  Stream<ChatMessage> watchMessages(String conversationId);
}
