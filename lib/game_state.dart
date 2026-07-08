import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'words.dart';

/// Bir harf karesinin durumu (Wordle renkleri).
enum TileState { empty, filled, correct, present, absent }

enum GameStatus { playing, won, lost }

class GameState extends ChangeNotifier {
  static const int wordLength = 5;
  static const int maxGuesses = 6;
  static const int hintCost = 25; // altınla ipucu
  static const int winReward = 15; // bölüm bitirince altın
  static const int startCoins = 60;

  int level = 0;
  int coins = startCoins;
  final List<String> guesses = [];
  String current = '';
  GameStatus status = GameStatus.playing;

  /// İpucu ile açılan harf pozisyonları (0-tabanlı).
  final Set<int> revealed = {};

  SharedPreferences? _prefs;
  final bool _persist;

  // ignore: prefer_initializing_formals
  GameState({bool persist = true}) : _persist = persist {
    if (_persist) _load();
  }

  String get target => kWords[level % kWords.length];
  int get displayLevel => level + 1;
  bool get canAffordHint => coins >= hintCost;
  bool get allRevealed => revealed.length >= wordLength;

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    level = _prefs?.getInt('level') ?? 0;
    coins = _prefs?.getInt('coins') ?? startCoins;
    notifyListeners();
  }

  void _save() {
    if (!_persist) return;
    _prefs?.setInt('level', level);
    _prefs?.setInt('coins', coins);
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

  void submit() {
    if (status != GameStatus.playing || current.length != wordLength) return;
    guesses.add(current);
    if (current == target) {
      status = GameStatus.won;
      coins += winReward;
    } else if (guesses.length >= maxGuesses) {
      status = GameStatus.lost;
    }
    current = '';
    _save();
    notifyListeners();
  }

  /// Bir harf ipucu açar. [free] true ise (reklam) bedava; değilse altından
  /// düşer. Açılacak pozisyon yoksa ya da altın yetmezse false döner.
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

  void nextLevel() {
    level++;
    _resetRound();
    _save();
  }

  void retryLevel() => _resetRound();

  void _resetRound() {
    guesses.clear();
    current = '';
    revealed.clear();
    status = GameStatus.playing;
    notifyListeners();
  }

  /// Bir tahminin pozisyon-başına Wordle değerlendirmesi (tekrar eden harfler
  /// doğru sayılır: önce yeşiller, sonra kalan sayıya göre sarılar).
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

  /// Klavye harf renkleri (tüm tahminlerden en iyi durum).
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
