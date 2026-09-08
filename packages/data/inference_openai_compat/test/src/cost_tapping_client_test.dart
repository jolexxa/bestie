import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inference_openai_compat/src/cost_tapping_client.dart';
import 'package:test/test.dart';

void main() {
  group('CostTappingClient', () {
    late List<double> charges;
    late int innerCloses;

    setUp(() {
      charges = [];
      innerCloses = 0;
    });

    CostTappingClient tap(List<String> chunks) => CostTappingClient(
      _CountingClient(
        MockClient.streaming(
          (request, body) async => http.StreamedResponse(
            Stream.fromIterable([
              for (final chunk in chunks) utf8.encode(chunk),
            ]),
            200,
          ),
        ),
        onClose: () => innerCloses++,
      ),
      onCost: charges.add,
    );

    Future<String> drain(CostTappingClient client) async {
      final response = await client.send(
        http.Request('POST', Uri.parse('https://example.test/v1/chat')),
      );
      return response.stream.bytesToString();
    }

    test('passes the wire through untouched', () async {
      const body = 'data: {"usage": {"cost": 0.5}}\n\ndata: [DONE]\n\n';

      expect(await drain(tap([body])), body);
      expect(charges, [0.5]);
    });

    test('ignores a charge it cannot read', () async {
      await drain(tap(['data: {"usage": {"cost": nope\n\n']));

      expect(charges, isEmpty);
    });

    test('ignores lines that mention a cost elsewhere', () async {
      await drain(tap(['data: {"choices": [], "cost": 1}\n\n']));

      expect(charges, isEmpty);
    });

    test('closes the wire once', () {
      tap([])
        ..close()
        ..close();

      expect(innerCloses, 1);
    });
  });
}

final class _CountingClient extends http.BaseClient {
  _CountingClient(this._inner, {required this.onClose});

  final http.Client _inner;
  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    onClose();
    _inner.close();
  }
}
