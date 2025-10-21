import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'audora_music.dart';
import 'repository/audio_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final audoraClient = AudoraClient();
  final player = AudoraPlayer(audoraClient);

  final audioHandler = await AudioService.init(
    builder: () => MusicAudioHandler(player),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.audora.channel.audio',
      androidNotificationChannelName: 'Audora Music',
      androidNotificationOngoing: true,
    ),
  );

  runApp(Provider.value(value: audioHandler, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: MainScreen());
  }
}
