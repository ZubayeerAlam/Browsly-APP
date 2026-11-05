/// One row in the chat list.
class Conversation {
  const Conversation({
    required this.id,
    required this.otherName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    this.otherImageUrl,
    this.productTitle,
    this.productImageUrl,
  });

  final String id;

  /// The shop for a buyer, and the buyer's first name for a seller.
  final String otherName;
  final String? otherImageUrl;
  final String? productTitle;
  final String? productImageUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
}

/// Where the next page starts. Comes from the server, and is never built here.
class ConversationCursor {
  const ConversationCursor({required this.key, required this.id});

  final String key;
  final String id;
}

class ConversationPage {
  const ConversationPage({required this.items, this.next});

  final List<Conversation> items;

  /// Null when this is the last page.
  final ConversationCursor? next;
}

/// The top of a chat room.
class ChatHeader {
  const ChatHeader({
    required this.id,
    required this.otherName,
    this.otherImageUrl,
    this.productId,
    this.productTitle,
    this.productPrice,
    this.productImageUrl,
  });

  final String id;
  final String otherName;
  final String? otherImageUrl;
  final String? productId;
  final String? productTitle;

  /// Null once the product is no longer on sale.
  final double? productPrice;
  final String? productImageUrl;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.body,
    required this.createdAt,
    this.senderId,
  });

  final String id;
  final String conversationId;

  /// Null if the sender has since deleted their account.
  final String? senderId;
  final String body;
  final DateTime createdAt;
}
