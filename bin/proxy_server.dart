import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import '../lib/audora_music.dart';

final client = AudoraClient();
final player = AudoraPlayer(client);

Future<Response> _handler(Request request) async {
  final videoId = request.url.queryParameters['id'];
  if (videoId == null) return Response.badRequest(body: 'Missing video id');

  try {
    final visitorData = await client.getVisitorData();
    String? audioUrl = await player.getAudioUrl(
      videoId,
      visitorData: visitorData,
    );

    if (audioUrl == null) return Response.notFound('Audio URL not found');

    return Response.ok(
      jsonEncode({'url': audioUrl}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e, st) {
    return Response.internalServerError(body: 'Error: $e\n$st');
  }
}

void main() async {
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(_handler);
  final server = await io.serve(handler, '127.0.0.1', 8080);
  print('Proxy server running on http://${server.address.host}:${server.port}');
}
