import 'dart:async';

import 'package:flutter/material.dart';

/// 단계별 안내 가이드(오감 그라운딩, 근육 이완 등).
///
/// [steps]의 각 문구를 [stepSec]초씩 순서대로 보여주며, 마지막 단계 후
/// 처음으로 순환한다. 탭하면 즉시 다음 단계로 넘어간다.
class StepGuide extends StatefulWidget {
  final List<String> steps;
  final int stepSec;
  final Color color;

  const StepGuide({
    super.key,
    required this.steps,
    this.stepSec = 16,
    this.color = const Color(0xFF4F8FB0),
  });

  @override
  State<StepGuide> createState() => _StepGuideState();
}

class _StepGuideState extends State<StepGuide> {
  int _index = 0;
  int _tick = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _tick++;
        if (_tick >= widget.stepSec) _advance();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _advance() {
    _index = (_index + 1) % widget.steps.length;
    _tick = 0;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_tick / widget.stepSec).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () => setState(_advance),
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: widget.color.withOpacity(0.12),
              child: Text(
                '${_index + 1}',
                style: TextStyle(
                  color: widget.color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(
                widget.steps[_index],
                key: ValueKey(_index),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Color(0xFF2C5066),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: widget.color.withOpacity(0.12),
                color: widget.color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_index + 1} / ${widget.steps.length}  ·  탭하면 다음',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
