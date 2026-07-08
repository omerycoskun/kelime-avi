import 'package:flutter/material.dart';

import 'ads/ad_banner.dart';
import 'ads/ad_interstitial.dart';
import 'ads/ad_rewarded.dart';
import 'game_state.dart';

const _kbRow1 = ['e', 'r', 't', 'y', 'u', 'ı', 'o', 'p', 'ğ', 'ü'];
const _kbRow2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ş', 'i'];
const _kbRow3 = ['z', 'c', 'ç', 'v', 'b', 'n', 'm', 'ö'];

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameState game = GameState();
  bool _busyAd = false;

  Color _tileColor(TileState s) {
    switch (s) {
      case TileState.correct:
        return const Color(0xFF54B06A);
      case TileState.present:
        return const Color(0xFFD3A93E);
      case TileState.absent:
        return const Color(0xFF3A3A4A);
      default:
        return Colors.transparent;
    }
  }

  void _onKey(String letter) => game.addLetter(letter);

  Future<void> _adHint() async {
    if (_busyAd || game.allRevealed || game.status != GameStatus.playing) return;
    setState(() => _busyAd = true);
    final ok = await AdRewarded.instance.showContinue();
    if (!mounted) return;
    setState(() => _busyAd = false);
    if (ok) game.revealHint(free: true);
  }

  void _coinHint() {
    if (!game.revealHint(free: false)) {
      _snack('Yetersiz altın (${GameState.hintCost} gerekli)');
    }
  }

  void _next() {
    game.nextLevel();
    AdInterstitial.instance.notifyGameOver(); // her 2 bölümde geçiş reklamı
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1E3D), Color(0xFF10121F)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: game,
            builder: (context, _) {
              return Column(
                children: [
                  _topBar(),
                  if (game.revealed.isNotEmpty) _hintStrip(),
                  Expanded(child: Center(child: _grid())),
                  _hintButtons(),
                  const SizedBox(height: 6),
                  _keyboard(),
                  const SizedBox(height: 6),
                  const AdBanner(),
                  if (game.status != GameStatus.playing) _resultBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Bölüm ${game.displayLevel}',
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFC93C)),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on,
                    color: Color(0xFFFFC93C), size: 20),
                const SizedBox(width: 6),
                Text('${game.coins}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintStrip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lightbulb, color: Color(0xFFFFC93C), size: 18),
          const SizedBox(width: 8),
          for (int i = 0; i < GameState.wordLength; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                game.revealed.contains(i) ? game.target[i].toUpperCase() : '•',
                style: TextStyle(
                  color: game.revealed.contains(i)
                      ? const Color(0xFFFFC93C)
                      : Colors.white38,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _grid() {
    return LayoutBuilder(builder: (context, c) {
      final tile =
          ((c.maxWidth - 40) / GameState.wordLength).clamp(0.0, 58.0);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int r = 0; r < GameState.maxGuesses; r++)
            Padding(
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int col = 0; col < GameState.wordLength; col++)
                    _tile(r, col, tile),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _tile(int row, int col, double size) {
    String letter = '';
    TileState state = TileState.empty;
    if (row < game.guesses.length) {
      final g = game.guesses[row];
      letter = g[col].toUpperCase();
      state = game.evaluate(g)[col];
    } else if (row == game.guesses.length &&
        game.status == GameStatus.playing) {
      if (col < game.current.length) {
        letter = game.current[col].toUpperCase();
        state = TileState.filled;
      }
    }
    final filled = state == TileState.filled || state == TileState.empty;
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? Colors.transparent : _tileColor(state),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: state == TileState.filled
              ? Colors.white54
              : (filled ? Colors.white24 : Colors.transparent),
          width: 2,
        ),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.48,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _hintButtons() {
    final playing = game.status == GameStatus.playing && !game.allRevealed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _hintBtn(
              icon: Icons.monetization_on,
              label: 'İpucu  ${GameState.hintCost}',
              color: const Color(0xFF4D7CFF),
              onTap: playing ? _coinHint : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _hintBtn(
              icon: Icons.ondemand_video,
              label: _busyAd ? 'Yükleniyor' : 'İpucu  Reklam',
              color: const Color(0xFF54B06A),
              onTap: (playing && !_busyAd) ? _adHint : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: FittedBox(child: Text(label)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _keyboard() {
    final ks = game.keyStates;
    Widget row(List<String> letters,
        {Widget? leading, Widget? trailing}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ?leading,
            for (final l in letters) _key(l, ks[l]),
            ?trailing,
          ],
        ),
      );
    }

    return Column(
      children: [
        row(_kbRow1),
        row(_kbRow2),
        row(
          _kbRow3,
          leading: _wideKey(Icons.keyboard_return, game.submit, const Color(0xFF4D7CFF)),
          trailing: _wideKey(Icons.backspace, game.removeLetter, const Color(0xFF3A3A4A)),
        ),
      ],
    );
  }

  Widget _key(String letter, TileState? state) {
    final bg = state == null ? const Color(0xFF2A2C42) : _tileColor(state);
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: GestureDetector(
          onTap: () => _onKey(letter),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg == Colors.transparent ? const Color(0xFF2A2C42) : bg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              letter.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wideKey(IconData icon, VoidCallback onTap, Color color) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          width: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _resultBar() {
    final won = game.status == GameStatus.won;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      color: Colors.black.withValues(alpha: 0.4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            won ? '🎉 Tebrikler!  +${GameState.winReward} 💰' : '😕 Bilemedin',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800),
          ),
          if (!won) ...[
            const SizedBox(height: 4),
            Text('Kelime: ${game.target.toUpperCase()}',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: 240,
            child: ElevatedButton(
              onPressed: won ? _next : game.retryLevel,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    won ? const Color(0xFF54B06A) : const Color(0xFF4D7CFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              child: Text(won ? 'Sonraki Bölüm' : 'Tekrar Dene'),
            ),
          ),
        ],
      ),
    );
  }
}
