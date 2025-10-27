import 'dart:async';
import 'dart:convert';
import 'package:at_client/at_client.dart';

/// Transformer for sending messages to app
/// Just passes through the JSON string
class MessageSendTransformer extends StreamTransformerBase<String, String> {
  const MessageSendTransformer();

  @override
  Stream<String> bind(Stream<String> stream) {
    // Already JSON string, just pass through
    return stream;
  }
}

/// Transformer for receiving queries from app
/// Extracts JSON string from AtNotification tuple
class QueryReceiveTransformer extends StreamTransformerBase<(AtNotification, String), String> {
  const QueryReceiveTransformer();

  @override
  Stream<String> bind(Stream<(AtNotification, String)> stream) {
    // Extract the value (second element of tuple) which contains JSON
    return stream.map((tuple) => tuple.$2);
  }
}
