import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeavi/answers.dart';
import 'package:kelimeavi/game_state.dart';
import 'package:kelimeavi/words.dart';

void main() {
  test('sözlük ve cevap havuzu tam 5 harf', () {
    for (final w in kWords) {
      expect(w.length, 5, reason: '$w 5 harf değil');
    }
    for (final w in kAnswers) {
      expect(w.length, 5);
      expect(kWords.contains(w), isTrue, reason: '$w sözlükte yok');
    }
    expect(kWords.length, greaterThan(1000));
    expect(kAnswers.length, greaterThan(50));
  });

  test('Wordle değerlendirme (tekrar eden harf dahil)', () {
    final g = GameState(persist: false);
    g.setTargetForTest('kalem');
    expect(g.evaluate('kalem'), List.filled(5, TileState.correct));
    expect(g.evaluate('metal'), const [
      TileState.present,
      TileState.present,
      TileState.absent,
      TileState.present,
      TileState.present,
    ]);
    expect(g.evaluate('kapak'), const [
      TileState.correct,
      TileState.correct,
      TileState.absent,
      TileState.absent,
      TileState.absent,
    ]);
  });

  test('anlamsız kelime kabul edilmez, geçerli kelime kabul edilir', () {
    final g = GameState(persist: false);
    g.setTargetForTest('deniz');
    for (final c in 'xxxxx'.split('')) {
      g.addLetter(c);
    }
    // 'xxxxx' sözlükte yok → kabul edilmez (harfler ekranda kalır, silinmez)
    expect(g.submit(), isFalse);
    expect(g.guesses, isEmpty);
    // temizle, geçerli tahmin gir
    while (g.current.isNotEmpty) {
      g.removeLetter();
    }
    for (final c in 'deniz'.split('')) {
      g.addLetter(c);
    }
    expect(g.submit(), isTrue);
    expect(g.status, GameStatus.won);
  });

  test('kazanma altın + çözülen sayısı artar, yeni kelime gelir', () {
    final g = GameState(persist: false);
    g.setTargetForTest('deniz');
    final coinsBefore = g.coins;
    final solvedBefore = g.solved;
    for (final c in 'deniz'.split('')) {
      g.addLetter(c);
    }
    g.submit();
    expect(g.coins, coinsBefore + GameState.winReward);
    expect(g.solved, solvedBefore + 1);
    g.newWord();
    expect(g.status, GameStatus.playing);
    expect(g.guesses, isEmpty);
  });

  test('altınla ipucu altını düşürür ve harf açar', () {
    final g = GameState(persist: false);
    g.coins = 100;
    expect(g.revealHint(free: false), isTrue);
    expect(g.coins, 100 - GameState.hintCost);
    expect(g.revealed.length, 1);
  });
}
