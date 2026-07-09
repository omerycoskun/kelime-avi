import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'answers.dart';
import 'words.dart';

enum TileState { empty, filled, correct, present, absent }

enum GameStatus { playing, won, lost }

class GameState extends ChangeNotifier {
  static const int wordLength = 5;
  static const int maxGuesses = 6;
  static const int hintCost = 25;
  static const int winReward = 15;
  static const int startCoins = 60;

  int coins = startCoins;
  int solved = 0; // toplam çözülen kelime (gösterim + ilerleme)
  final List<String> guesses = [];
  String current = '';
  GameStatus status = GameStatus.playing;
  final Set<int> revealed = {};

  final Random _rng = Random();
  final Set<String> _dict = kWords.toSet(); // geçerli tahmin sözlüğü (5172)
  late String _target;

  SharedPreferences? _prefs;
  final bool _persist;

  // ignore: prefer_initializing_formals
  GameState({bool persist = true}) : _persist = persist {
    _target = kAnswers[_rng.nextInt(kAnswers.length)];
    if (_persist) _load();
  }

  String get target => _target;

  @visibleForTesting
  void setTargetForTest(String w) => _target = w;

  bool get canAffordHint => coins >= hintCost;
  bool get allRevealed => revealed.length >= wordLength;

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    coins = _prefs?.getInt('coins') ?? startCoins;
    solved = _prefs?.getInt('solved') ?? 0;
    notifyListeners();
  }

  void _save() {
    if (!_persist) return;
    _prefs?.setInt('coins', coins);
    _prefs?.setInt('solved', solved);
  }

  void addLetter(String l) {
    if (status != GameStatus.playing || current.length >= wordLength) return;
    current += l;
    notifyListeners();
  }

  void removeLetter() {
    if (status != GameStatus.playing || current.isEmpty) return;
    current = current.substring(0, current.length - 1);
    notifyListeners();
  }

  /// Tahmini gönderir. Geçerli (sözlükte olan) bir kelime değilse kabul edilmez
  /// ve false döner (anlamsız kelimeler kabul olmaz).
  bool submit() {
    if (status != GameStatus.playing || current.length != wordLength) {
      return false;
    }
    if (!_dict.contains(current)) return false;
    guesses.add(current);
    if (current == target) {
      status = GameStatus.won;
      coins += winReward;
      solved++;
    } else if (guesses.length >= maxGuesses) {
      status = GameStatus.lost;
    }
    current = '';
    _save();
    notifyListeners();
    return true;
  }

  /// Bir harf ipucu açar. [free] true ise (reklam) bedava; değilse altından düşer.
  bool revealHint({required bool free}) {
    if (status != GameStatus.playing || allRevealed) return false;
    if (!free) {
      if (coins < hintCost) return false;
      coins -= hintCost;
    }
    final options = [
      for (int i = 0; i < wordLength; i++)
        if (!revealed.contains(i)) i
    ]..shuffle();
    revealed.add(options.first);
    _save();
    notifyListeners();
    return true;
  }

  /// Yeni rastgele kelime (kazanınca "sonraki", kaybedince "yeni kelime").
  void newWord() {
    _target = kAnswers[_rng.nextInt(kAnswers.length)];
    guesses.clear();
    current = '';
    revealed.clear();
    status = GameStatus.playing;
    notifyListeners();
  }

  /// Wordle değerlendirmesi (tekrar eden harf doğru: önce yeşil, sonra sarı).
  List<TileState> evaluate(String guess) {
    final result = List<TileState>.filled(wordLength, TileState.absent);
    final counts = <String, int>{};
    for (int i = 0; i < wordLength; i++) {
      final c = target[i];
      counts[c] = (counts[c] ?? 0) + 1;
    }
    for (int i = 0; i < wordLength; i++) {
      if (guess[i] == target[i]) {
        result[i] = TileState.correct;
        counts[guess[i]] = counts[guess[i]]! - 1;
      }
    }
    for (int i = 0; i < wordLength; i++) {
      if (result[i] == TileState.correct) continue;
      final c = guess[i];
      if ((counts[c] ?? 0) > 0) {
        result[i] = TileState.present;
        counts[c] = counts[c]! - 1;
      }
    }
    return result;
  }

  Map<String, TileState> get keyStates {
    final m = <String, TileState>{};
    for (final g in guesses) {
      final ev = evaluate(g);
      for (int i = 0; i < wordLength; i++) {
        final c = g[i];
        final s = ev[i];
        final cur = m[c];
        if (cur == TileState.correct) continue;
        if (s == TileState.correct) {
          m[c] = TileState.correct;
        } else if (s == TileState.present && cur != TileState.correct) {
          m[c] = TileState.present;
        } else {
          m[c] ??= s;
        }
      }
    }
    return m;
  }
}
