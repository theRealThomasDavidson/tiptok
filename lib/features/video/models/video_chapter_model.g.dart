// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_chapter_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideoChapter _$VideoChapterFromJson(Map<String, dynamic> json) => VideoChapter(
      startTime: (json['startTime'] as num).toDouble(),
      endTime: (json['endTime'] as num).toDouble(),
      summary: json['summary'] as String,
      text: json['text'] as String,
      topics:
          (json['topics'] as List<dynamic>?)?.map((e) => e as String).toList(),
      keywords: (json['keywords'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$VideoChapterToJson(VideoChapter instance) =>
    <String, dynamic>{
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'summary': instance.summary,
      'text': instance.text,
      'topics': instance.topics,
      'keywords': instance.keywords,
    };
