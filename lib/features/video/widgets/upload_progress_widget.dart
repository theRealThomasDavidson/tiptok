import 'package:flutter/material.dart';

class UploadProgressWidget extends StatelessWidget {
  final double progress;
  
  const UploadProgressWidget({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(value: progress),
        Text('${(progress * 100).toStringAsFixed(1)}%'),
      ],
    );
  }
} 