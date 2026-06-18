import 'package:flutter/material.dart';

/// VAS(갈망) 0~10 슬라이더.
///
/// 0 = 갈망 없음 / 10 = 참기 매우 어려움.
/// 값에 따라 색이 차분(파랑)→강함(주황)으로 변해 직관적으로 보여준다.
class VasSlider extends StatelessWidget {
  final int value; // 0~10
  final ValueChanged<int> onChanged;

  const VasSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Color _colorFor(int v) {
    // 0~10을 파랑→주황으로 보간.
    final t = v / 10.0;
    return Color.lerp(
      const Color(0xFF4F8FB0),
      const Color(0xFFE08A3C),
      t,
    )!;
  }

  String _hint(int v) {
    if (v <= 2) return '거의 느껴지지 않아요';
    if (v <= 5) return '어느 정도 느껴져요';
    if (v <= 8) return '꽤 강하게 느껴져요';
    return '참기 매우 어려워요';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        Center(
          child: Text(
            _hint(value),
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 6,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 · 없음', style: TextStyle(color: Colors.grey.shade600)),
              Text('10 · 매우 강함',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }
}
