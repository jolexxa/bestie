import 'dart:convert';
import 'dart:io';

/// Sends [body] as the whole JSON response.
Future<void> replyJson(
  HttpRequest request,
  Object? body, {
  int status = HttpStatus.ok,
}) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}

/// Sends [body], a JSON string already encoded.
Future<void> replyEncoded(
  HttpRequest request,
  String body, {
  int status = HttpStatus.ok,
}) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(body);
  await request.response.close();
}

/// Sends an OpenAI-style error.
Future<void> replyError(
  HttpRequest request, {
  required int status,
  required String code,
  required String message,
  String type = 'invalid_request_error',
}) => replyJson(
  request,
  openAiError(message: message, type: type, code: code),
  status: status,
);

/// The body OpenAI-compatible clients read errors from.
Map<String, Object?> openAiError({
  required String message,
  required String type,
  required String code,
}) => {
  'error': {'message': message, 'type': type, 'code': code},
};
