import 'package:flutter/material.dart';
import '../app/game_controller.dart';
import '../game/models.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({required this.controller, super.key});
  final GameController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.loading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      final state = controller.state;
      return Scaffold(
        appBar: AppBar(
          title: const Text('DEAD DAY',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
          actions: [
            IconButton(
              tooltip: '새 게임',
              icon: const Icon(Icons.restart_alt),
              onPressed: () => _confirmReset(context),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('DAY ' + state.currentDay.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold)),
              Text('생존 ' + state.daysSurvived.toString() +
                '일 · 최고 ' + state.bestDays.toString() + '일',
                style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _Stat('체력', state.health.toString() + '/100', Icons.favorite),
                _Stat('식량', state.food.toString(), Icons.restaurant),
                _Stat('식수', state.water.toString(), Icons.water_drop),
                _Stat('의약품', state.medicine.toString(), Icons.medication),
                _Stat('무기', state.weaponLevel.toString() + '/2', Icons.shield),
              ]),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('오늘의 기록',
                        style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Text(state.log, style: const TextStyle(height: 1.6)),
                      if (controller.aiText != null) ...[
                        const Divider(),
                        Text(controller.aiText!),
                      ],
                    ],
                  ),
                ),
              ),
              if (controller.error != null)
                Text(controller.error!,
                  style: const TextStyle(color: Colors.orangeAccent)),
              const SizedBox(height: 16),
              if (state.gameOver)
                _gameOver()
              else if (state.pendingRecruitment)
                _recruitment()
              else if (state.encounter != null)
                _encounter(state.encounter!)
              else
                _mainActions(state),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(state.companion == null
                    ? '동료: 없음'
                    : '동료: ' + state.companion!.name +
                      ' · 신뢰 ' + state.companion!.trust.toString() +
                      ' · 친밀 ' + state.companion!.affection.toString()),
                ),
              ),
              const SizedBox(height: 16),
              const Text('오프라인 플레이 가능 · 로컬 AI는 아직 미연결',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ),
      );
    },
  );

  Widget _mainActions(GameState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('오늘의 행동',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      for (final zone in Zone.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FilledButton.tonal(
            onPressed: () => controller.explore(zone),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(children: [
                Text(zone.label),
                Text(zone.description,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ]),
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: controller.rest,
        icon: const Icon(Icons.bedtime),
        label: const Text('거점에서 휴식 (하루 경과)'),
      ),
      OutlinedButton.icon(
        onPressed: state.medicine > 0 && state.health < 100
          ? controller.useMedicine : null,
        icon: const Icon(Icons.healing),
        label: const Text('의약품 사용 (+30 체력, 날짜 경과 없음)'),
      ),
    ],
  );

  Widget _encounter(Encounter encounter) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('위험: 좀비 ' + encounter.zombies.toString() + '마리',
        style: const TextStyle(color: Colors.redAccent,
          fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: () => controller.resolve(EncounterAction.fight),
        child: const Text('싸운다 — 위험하지만 물자 획득 가능'),
      ),
      FilledButton.tonal(
        onPressed: () => controller.resolve(EncounterAction.sneak),
        child: const Text('숨는다 — 성공하면 물자 획득'),
      ),
      OutlinedButton(
        onPressed: () => controller.resolve(EncounterAction.flee),
        child: const Text('도망친다 — 물자 포기'),
      ),
    ],
  );

  Widget _recruitment() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('새로운 생존자',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 8),
      const Text('의료 지식이 있는 서윤을 영입하면 매일 식량과 식수가 '
        '1개씩 추가 소모되지만 휴식 회복량이 늘어난다.'),
      FilledButton(
        onPressed: () => controller.recruit(true),
        child: const Text('서윤을 받아들인다'),
      ),
      OutlinedButton(
        onPressed: () => controller.recruit(false),
        child: const Text('거절한다'),
      ),
    ],
  );

  Widget _gameOver() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Text('GAME OVER',
          style: TextStyle(color: Colors.redAccent,
            fontSize: 24, fontWeight: FontWeight.bold)),
        Text('최종 생존 ' + controller.state.daysSurvived.toString() + '일'),
        FilledButton(
          onPressed: controller.newGame,
          child: const Text('다시 시작'),
        ),
      ]),
    ),
  );

  Future<void> _confirmReset(BuildContext context) async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('새 게임 시작'),
        content: const Text('현재 기록은 종료되고 최고 생존 일수는 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('새 게임'),
          ),
        ],
      ),
    );
    if (reset == true) await controller.newGame();
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 106,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF1A2527),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      Icon(icon, size: 19, color: const Color(0xFF93C5B5)),
      const SizedBox(height: 5),
      Text(label,
        style: const TextStyle(fontSize: 12, color: Colors.white70)),
      Text(value,
        style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );
}
