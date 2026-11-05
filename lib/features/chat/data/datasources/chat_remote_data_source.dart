import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRemoteDataSource {
  const ChatRemoteDataSource(this._client);

  final SupabaseClient _client;

  String productImageUrl(String path) =>
      _client.storage.from('product-images').getPublicUrl(path);

  /// A seller sees the buyer's avatar, and a buyer sees the shop's logo.
  String otherImageUrl(String path, {required bool isSeller}) => _client.storage
      .from(isSeller ? 'avatars' : 'shop-assets')
      .getPublicUrl(path);

  Future<List<Map<String, dynamic>>> fetchConversations(
    Map<String, dynamic> params,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_conversations',
      params: params,
    );
    return rows.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> fetchHeader(String id) {
    return _client.rpc<Map<String, dynamic>?>(
      'get_conversation',
      params: {'p_conversation_id': id},
    );
  }

  /// RLS limits this to chats the user is part of.
  Future<List<Map<String, dynamic>>> fetchMessages(
    String id,
    DateTime? before,
    int limit,
  ) {
    var query = _client
        .from('messages')
        .select('id, conversation_id, sender_id, body, created_at')
        .eq('conversation_id', id);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    return query.order('created_at', ascending: false).limit(limit);
  }

  Future<Map<String, dynamic>> send(String id, String body) {
    return _client.rpc<Map<String, dynamic>>(
      'send_message',
      params: {'p_conversation_id': id, 'p_body': body},
    );
  }

  Future<void> markRead(String id) {
    return _client.rpc<void>(
      'mark_conversation_read',
      params: {'p_conversation_id': id},
    );
  }

  Future<String> startForProduct(String productId) {
    return _client.rpc<String>(
      'start_conversation',
      params: {'p_product_id': productId},
    );
  }

  Future<String> startForOrder(String groupId) {
    return _client.rpc<String>(
      'start_order_conversation',
      params: {'p_group_id': groupId},
    );
  }

  Stream<Map<String, dynamic>> watchMessages(String id) {
    late final RealtimeChannel channel;
    late final StreamController<Map<String, dynamic>> controller;
    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        channel = _client
            .channel('messages:$id')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: id,
              ),
              callback: (payload) => controller.add(payload.newRecord),
            )
            .subscribe();
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }
}
