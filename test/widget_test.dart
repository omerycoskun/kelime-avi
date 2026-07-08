import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeavi/game_state.dart';
import 'package:kelimeavi/words.dart';

void main() {
  test('tüm kelimeler tam 5 harf', () {
    for (final w in kWords) {
      expect(w.length, 5, reason: '$w 5 harf değil');
    }
    expect(kWords.length, greaterThan(50));
  });

  test('Wordle değerlendirme (tekrar eden harf dahil)', () {
    final g = GameState(persist: false);
    g.level = kWords.indexOf('kalem'); // hedef: kalem
    expect(g.target, 'kalem');

    expect(g.evaluate('kalem'), List.filled(5, TileState.correct));

    // 'metal' vs 'kalem': m,e,a,l kelimede var (yanlış yer)=present, t yok.
    expect(g.evaluate('metal'), const [
      TileState.present, // m
      TileState.present, // e
      TileState.absent, // t
      TileState.present, // a
      TileState.present, // l
    ]);

    // Tekrar eden harf: 'kapak' vs 'kalem' — kalem'de tek a/k olduğu için
    // ilk a/k yeşil, ikinci a ve son k absent (çift sayılmaz).
    expect(g.evaluate('kapak'), const [
      TileState.correct, // k
      TileState.correct, // a
      TileState.absent, // p
      TileState.absent, // ikinci a
      TileState.absent, // k
    ]);
  });

  test('kazanma altın verir, sonraki bölüm ilerletir', () {
    final g = GameState(persist: false);
    g.level = kWords.indexOf('deniz');
    final before = g.coins;
    for (final c in 'deniz'.split('')) {
      g.addLetter(c);
    }
    g.submit();
    expect(g.status, GameStatus.won);
    expect(g.coins, before + GameState.winReward);
    g.nextLevel();
    expect(g.level, kWords.indexOf('deniz') + 1);
    expect(g.status, GameStatus.playing);
  });

  test('altınla ipucu altını düşürür ve harf açar', () {
    final g = GameState(persist: false);
    g.coins = 100;
    final ok = g.revealHint(free: false);
    expect(ok, isTrue);
    expect(g.coins, 100 - GameState.hintCost);
    expect(g.revealed.length, 1);
  });
}
