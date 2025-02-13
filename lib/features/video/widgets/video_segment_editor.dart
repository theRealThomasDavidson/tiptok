import 'package:flutter/material.dart';
import '../models/video_segment_model.dart';

class VideoSegmentEditor extends StatelessWidget {
  final VideoSegment segment;
  final double originalVideoDuration;
  final Function(VideoSegment) onSegmentChanged;
  final VoidCallback onDeleteSegment;
  final bool isActive;
  final Function(double) onSeekTo;
  final VoidCallback onPreviewSegment;

  const VideoSegmentEditor({
    super.key,
    required this.segment,
    required this.originalVideoDuration,
    required this.onSegmentChanged,
    required this.onDeleteSegment,
    required this.onSeekTo,
    required this.onPreviewSegment,
    this.isActive = false,
  });

  String _formatDuration(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    final minutes = duration.inMinutes;
    final remainingSeconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final tenths = ((seconds * 10) % 10).round();
    return '$minutes:$remainingSeconds.$tenths';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.withOpacity(0.1) : null,
        border: Border.all(
          color: isActive ? Colors.blue : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview and time display
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isActive ? Icons.pause : Icons.play_arrow,
                  color: isActive ? Colors.blue : Colors.grey,
                ),
                onPressed: onPreviewSegment,
              ),
              Expanded(
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // Progress bar background
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: LinearProgressIndicator(
                          value: segment.endTime / originalVideoDuration,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.withOpacity(0.3),
                          ),
                        ),
                      ),
                      // Time markers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              _formatDuration(segment.startTime),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              _formatDuration(segment.endTime),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDeleteSegment,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Time range sliders
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start Time',
                      style: TextStyle(fontSize: 12),
                    ),
                    Slider(
                      value: segment.startTime,
                      min: 0,
                      max: segment.endTime,
                      onChanged: (value) {
                        onSeekTo(value);
                        onSegmentChanged(segment.copyWith(startTime: value));
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'End Time',
                      style: TextStyle(fontSize: 12),
                    ),
                    Slider(
                      value: segment.endTime,
                      min: segment.startTime,
                      max: originalVideoDuration,
                      onChanged: (value) {
                        onSeekTo(value);
                        onSegmentChanged(segment.copyWith(endTime: value));
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Segment info
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Duration: ${(segment.endTime - segment.startTime).toStringAsFixed(1)}s',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
} 