import 'package:flutter/material.dart';
import '../models/video_segment_model.dart';

class VideoSegmentEditor extends StatelessWidget {
  final VideoSegment segment;
  final double originalVideoDuration;
  final Function(VideoSegment) onSegmentChanged;
  final VoidCallback onDeleteSegment;
  final bool isActive;
  final Function(double) onSeekTo;
  final Function() onPreviewSegment;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: isActive ? Colors.orange : Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time range controls
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start: ${segment.startTime.toStringAsFixed(1)}s'),
                    Slider(
                      value: segment.startTime,
                      min: 0,
                      max: segment.endTime,
                      onChanged: (value) {
                        onSeekTo(value);
                        final newSegment = segment.copyWith(
                          startTime: value,
                        );
                        onSegmentChanged(newSegment);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End: ${segment.endTime.toStringAsFixed(1)}s'),
                    Slider(
                      value: segment.endTime,
                      min: segment.startTime,
                      max: originalVideoDuration,
                      onChanged: (value) {
                        onSeekTo(value);
                        final newSegment = segment.copyWith(
                          endTime: value,
                        );
                        onSegmentChanged(newSegment);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Preview controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: onPreviewSegment,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Preview Segment'),
              ),
            ],
          ),

          // Segment info
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Duration: ${(segment.endTime - segment.startTime).toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.grey),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  onPressed: onDeleteSegment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 