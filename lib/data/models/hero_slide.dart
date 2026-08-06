import 'package:flutter/widgets.dart';

enum HeroOverlayStrength { light, medium, strong }

/// Public-facing slide metadata controlled later through
/// Super Admin → Website Management → Hero Slides.
class HeroSlide {
  const HeroSlide({
    required this.id,
    required this.isActive,
    required this.sortOrder,
    required this.duration,
    required this.overlayStrength,
    this.imageUrl,
    this.focalPoint = Alignment.center,
    this.title,
    this.subtitle,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? imageUrl;
  final String? title;
  final String? subtitle;
  final bool isActive;
  final int sortOrder;
  final Duration duration;
  final HeroOverlayStrength overlayStrength;
  final Alignment focalPoint;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HeroSlide copyWith({
    String? imageUrl,
    String? title,
    String? subtitle,
    bool? isActive,
    int? sortOrder,
    Duration? duration,
    HeroOverlayStrength? overlayStrength,
    Alignment? focalPoint,
    DateTime? updatedAt,
  }) => HeroSlide(
    id: id,
    imageUrl: imageUrl ?? this.imageUrl,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    isActive: isActive ?? this.isActive,
    sortOrder: sortOrder ?? this.sortOrder,
    duration: duration ?? this.duration,
    overlayStrength: overlayStrength ?? this.overlayStrength,
    focalPoint: focalPoint ?? this.focalPoint,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
