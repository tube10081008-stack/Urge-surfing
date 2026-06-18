import 'package:flutter/material.dart';

/// 항상 노출되는 SOS 버튼.
///
/// 위기 상황에서 즉시 도움을 받을 수 있도록 화면 어디에서나 접근 가능해야 한다.
/// 1336 = 한국 도박문제 예방치유원(상담 전화).
/// PoC에서는 실제 전화 대신 안내 다이얼로그를 띄운다.
class SosButton extends StatelessWidget {
  /// FloatingActionButton 형태로 쓸지(true), 인라인 버튼으로 쓸지(false)
  final bool floating;

  const SosButton({super.key, this.floating = true});

  void _showDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Color(0xFFE0607A)),
            SizedBox(width: 8),
            Text('도움 요청'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '지금 힘드시다면 혼자 견디지 않아도 괜찮아요.\n'
              '도박문제 전문 상담을 무료로 받을 수 있어요.',
              style: TextStyle(height: 1.5),
            ),
            SizedBox(height: 16),
            Text(
              '한국도박문제예방치유원',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              '☎ 1336 (24시간 · 무료)',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4F8FB0),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '※ PoC 데모에서는 실제 발신되지 않습니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (floating) {
      return FloatingActionButton.extended(
        heroTag: 'sos',
        backgroundColor: const Color(0xFFE0607A),
        foregroundColor: Colors.white,
        onPressed: () => _showDialog(context),
        icon: const Icon(Icons.support_agent),
        label: const Text('도움요청 1336'),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFE0607A),
        side: const BorderSide(color: Color(0xFFE0607A)),
      ),
      onPressed: () => _showDialog(context),
      icon: const Icon(Icons.support_agent),
      label: const Text('도움요청 1336'),
    );
  }
}
