import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'audora_music.dart';
import 'repository/audio_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'data/custom_playlists.dart';
import 'data/track_best_parts.dart';
import 'data/downloads.dart';
import 'data/download_progress.dart';

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

  await Hive.initFlutter();
  await Hive.openBox('recentlyPlayed');
  await CustomPlaylists.init();
  await TrackBestParts.init();
  await Downloads.init();
  await DownloadProgressTracker.init();

  runApp(Provider.value(value: audioHandler, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: MainScreen());
  }
}
