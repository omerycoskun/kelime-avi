import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/ad_init.dart';
import 'ads/ad_interstitial.dart';
import 'ads/ad_rewarded.dart';
import 'game_screen.dart';
import 'music_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  initAds();
  AdInterstitial.instance.preload();
  AdRewarded.instance.preload();
  MusicService.instance.init(); // sakin arka plan müziği (await'siz)
  runApp(const KelimeApp());
}

class KelimeApp extends StatelessWidget {
  const KelimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelime Avı Classic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4D7CFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
