import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vas_trend.dart';
import '../state/session_controller.dart';

/// 진행 대시보드 — 사용자가 자신의 연습 기록과 갈망 변화를 돌아보는 화면.
/// 백엔드 GET /dashboard/vas-trend(일자별 평균 pre/post/감소)를 시각화한다.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(vasTrendProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('내 기록'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C5066),
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(vasTrendProvider.future),
          child: trendAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Message(
              icon: Icons.cloud_off,
              text: '기록을 불러오지 못했어요.\n잠시 후 다시 시도해 주세요.',
            ),
            data: (points) =>
                points.isEmpty ? const _EmptyState() : _Content(points: points),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final List<VasTrendPoint> points;
  const _Content({required this.points});

  @override
  Widget build(BuildContext context) {
    final reductions =
        points.map((p) => p.avgReduction).whereType<double>().toList();
    final avgReduction = reductions.isEmpty
        ? null
        : reductions.reduce((a, b) => a + b) / reductions.length;
    final bestReduction = reductions.isEmpty
        ? null
        : reductions.reduce((a, b) => a > b ? a : b);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          '잘 해오고 있어요',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C5066),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '연습할수록 충동의 파도를 넘기기가 조금씩 수월해져요.',
          style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
        ),
        const SizedBox(height: 20),

        // 요약 통계
        Row(
          children: [
            _StatCard(
              label: '연습한 날',
              value: '${points.length}',
              unit: '일',
              color: const Color(0xFF4F8FB0),
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: '평균 갈망 감소',
              value: avgReduction == null ? '-' : avgReduction.toStringAsFixed(1),
              unit: '점',
              color: const Color(0xFF3FA796),
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: '최고 감소',
              value:
                  bestReduction == null ? '-' : bestReduction.toStringAsFixed(1),
              unit: '점',
              color: const Color(0xFFE08A3C),
            ),
          ],
        ),
        const SizedBox(height: 28),

        const Text(
          '갈망 변화 추이',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C5066),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '연습 전 → 후 갈망(0~10)과 줄어든 양',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        // 라인 그래프(연습 전/후 추이)
        _ChartLegend(),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: _TrendChart(points: points),
        ),
        const SizedBox(height: 24),

        ...points.reversed.map((p) => _TrendRow(point: p)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(fontSize: 13, color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  final VasTrendPoint point;
  const _TrendRow({required this.point});

  String get _shortDay {
    // 'YYYY-MM-DD' → 'MM/DD'
    final parts = point.day.split('-');
    return parts.length == 3 ? '${parts[1]}/${parts[2]}' : point.day;
  }

  @override
  Widget build(BuildContext context) {
    final reduction = point.avgReduction ?? 0;
    final factor = (reduction.clamp(0, 10)) / 10.0;
    final positive = reduction > 0;
    final barColor =
        positive ? const Color(0xFF3FA796) : Colors.grey.shade400;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              _shortDay,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5A7A8C),
              ),
            ),
          ),
          _vasChip(point.avgPre),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward, size: 16, color: Color(0xFF9AB4C2)),
          ),
          _vasChip(point.avgPost, highlight: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: factor == 0 ? 0.02 : factor,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFEDF2F5),
                    color: barColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  positive
                      ? '갈망 ${reduction.toStringAsFixed(1)} 감소'
                      : '변화 ${reduction.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vasChip(double? value, {bool highlight = false}) {
    final color =
        highlight ? const Color(0xFF3FA796) : const Color(0xFF5A7A8C);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        value == null ? '-' : value.toStringAsFixed(0),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        _Message(
          icon: Icons.waves,
          text: '아직 기록이 없어요.\n첫 파도타기를 마치면 여기에 변화가 쌓여요.',
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF9AB4C2)),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFF5A7A8C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 그래프 색상
const _kPreColor = Color(0xFFE08A3C); // 연습 전(주황)
const _kPostColor = Color(0xFF3FA796); // 연습 후(청록)

/// 그래프 범례.
class _ChartLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF5A7A8C))),
          ],
        );
    return Row(
      children: [
        dot(_kPreColor, '연습 전'),
        const SizedBox(width: 20),
        dot(_kPostColor, '연습 후'),
      ],
    );
  }
}

/// 연습 전/후 갈망(0~10) 추이 라인 그래프.
class _TrendChart extends StatelessWidget {
  final List<VasTrendPoint> points;
  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TrendChartPainter(points),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<VasTrendPoint> points;
  _TrendChartPainter(this.points);

  static const double _maxV = 10;

  String _shortDay(String day) {
    final p = day.split('-');
    return p.length == 3 ? '${p[1]}/${p[2]}' : day;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 26.0, padR = 10.0, padT = 10.0, padB = 22.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    double yFor(double v) => padT + (1 - (v / _maxV)) * plotH;
    double xFor(int i) =>
        points.length == 1 ? padL + plotW / 2 : padL + (i / (points.length - 1)) * plotW;

    final grid = Paint()
      ..color = const Color(0xFFE6EDF1)
      ..strokeWidth = 1;
    final axisText = TextPainter(textDirection: TextDirection.ltr);

    // 가로 그리드 + y 눈금(0,5,10)
    for (final v in [0.0, 5.0, 10.0]) {
      final y = yFor(v);
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), grid);
      axisText.text = TextSpan(
        text: v.toInt().toString(),
        style: const TextStyle(fontSize: 10, color: Color(0xFF9AB4C2)),
      );
      axisText.layout();
      axisText.paint(canvas, Offset(padL - axisText.width - 4, y - axisText.height / 2));
    }

    // x축 날짜 라벨(첫·중간·마지막)
    final labelIdx = <int>{0, points.length - 1, points.length ~/ 2};
    for (final i in labelIdx) {
      if (i < 0 || i >= points.length) continue;
      axisText.text = TextSpan(
        text: _shortDay(points[i].day),
        style: const TextStyle(fontSize: 10, color: Color(0xFF9AB4C2)),
      );
      axisText.layout();
      final x = (xFor(i) - axisText.width / 2)
          .clamp(0.0, size.width - axisText.width);
      axisText.paint(canvas, Offset(x, size.height - padB + 6));
    }

    void drawSeries(double? Function(VasTrendPoint) sel, Color color) {
      final line = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final dot = Paint()..color = color;

      Offset? prev;
      for (var i = 0; i < points.length; i++) {
        final v = sel(points[i]);
        if (v == null) {
          prev = null;
          continue;
        }
        final cur = Offset(xFor(i), yFor(v));
        if (prev != null) canvas.drawLine(prev, cur, line);
        canvas.drawCircle(cur, 3.5, dot);
        canvas.drawCircle(cur, 1.6, Paint()..color = Colors.white);
        prev = cur;
      }
    }

    drawSeries((p) => p.avgPre, _kPreColor);
    drawSeries((p) => p.avgPost, _kPostColor);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter old) =>
      old.points != points;
}
