import 'dart:async';
import 'dart:convert';
import 'package:at_client/at_client.dart';

/// Transformer for sending queries to agent
/// Just passes through the JSON string
class QuerySendTransformer extends StreamTransformerBase<String, String> {
  const QuerySendTransformer();

  @override
  Stream<String> bind(Stream<String> stream) {
    // Already JSON string, just pass through
    return stream;
  }
}

/// Transformer for receiving messages from agent
/// Extracts JSON string from AtNotification tuple
class MessageReceiveTransformer extends StreamTransformerBase<(AtNotification, String), String> {
  const MessageReceiveTransformer();

  @override
  Stream<String> bind(Stream<(AtNotification, String)> stream) {
    // Extract the value (second element of tuple) which contains JSON
    return stream.map((tuple) => tuple.$2);
  }
}
