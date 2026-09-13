import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/data/ai_service.dart';
import 'package:slepa_mapa/domain/level.dart';

void main() {
  test(
    'compatible HTTP request, error envelopes and no redirect following',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var status = 200;
      Object body = {
        'choices': [
          {
            'message': {'content': '{"schemaVersion":1}'},
          },
        ],
      };
      final requests = <Map<String, dynamic>>[];
      server.listen((request) async {
        requests.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.statusCode = status;
        request.response.headers.set(
          'location',
          'http://127.0.0.1:${server.port}/redirect',
        );
        request.response.write(jsonEncode(body));
        await request.response.close();
      });
      final provider = CompatibleAiProvider();
      addTearDown(provider.cancel);
      final config = AiProviderConfig(
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        model: 'test',
      );
      expect(await provider.generate(config, 'hello'), '{"schemaVersion":1}');
      expect(requests.single['messages'], [
        {'role': 'user', 'content': 'hello'},
      ]);
      for (final invalid in [
        <String, dynamic>{},
        {'choices': []},
        [],
        {
          'choices': [
            {'message': null},
          ],
        },
      ]) {
        body = invalid;
        await expectLater(
          provider.generate(config, 'x'),
          throwsA(isA<LevelValidationException>()),
        );
      }
      status = 302;
      await expectLater(
        provider.generate(config, 'x'),
        throwsA(
          isA<LevelValidationException>().having(
            (e) => e.message,
            'message',
            contains('302'),
          ),
        ),
      );
      expect(requests.length, 6);
    },
  );
}
