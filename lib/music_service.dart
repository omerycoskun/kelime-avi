import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Arka plan müziği (sakin loop) — ayarlardan açılıp kapatılabilir, kalıcı.
class MusicService {
  MusicService._();
  static final MusicService instance = MusicService._();

  final AudioPlayer _player = AudioPlayer(playerId: 'bgm');
  bool musicOn = true;
  bool _started = false;
  SharedPreferences? _prefs;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      musicOn = _prefs?.getBool('musicOn') ?? true;
      await _player.setReleaseMode(ReleaseMode.loop);
      if (musicOn) _start();
    } catch (_) {}
  }

  void _start() {
    if (_started) return;
    _started = true;
    try {
      _player.play(AssetSource('audio/music.wav'), volume: 0.32);
    } catch (_) {
      _started = false;
    }
  }

  Future<void> toggle() async {
    musicOn = !musicOn;
    try {
      await _prefs?.setBool('musicOn', musicOn);
      if (musicOn) {
        if (_started) {
          await _player.resume();
        } else {
          _start();
        }
      } else {
        await _player.pause();
      }
    } catch (_) {}
  }
}
