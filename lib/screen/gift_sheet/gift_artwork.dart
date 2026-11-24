import 'package:flutter/material.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_image.dart';

/// Artwork for the 24 gifts ships inside the APK. Keeping it local makes the
/// gift store render immediately and removes 24 image downloads from the
/// critical path on slow or unstable mobile networks.
const Set<String> kBundledGiftImages = <String>{
  'tiktok_rose.webp',
  'tiktok_heart.webp',
  'tiktok_teddy.webp',
  'tiktok_diamond.webp',
  'tiktok_crown.webp',
  'tiktok_falcon.png',
  'tiktok_lion.png',
  'tiktok_game.webp',
  'tiktok_rocket.webp',
  'tiktok_castle.png',
  'tiktok_planet.webp',
  'tiktok_trophy.webp',
  'tiktok_chocolate.webp',
  'tiktok_crystal_rose.webp',
  'tiktok_balloon.webp',
  'tiktok_velvet_teddy.webp',
  'tiktok_cake.webp',
  'tiktok_ring.webp',
  'tiktok_giftbox.webp',
  'tiktok_bouquet.webp',
  'tiktok_gem.png',
  'tiktok_royal_crown.webp',
  'tiktok_star.webp',
  'tiktok_champion.webp',
};

/// Resolves a gift's API image path (e.g. `gifts/tiktok_rose.webp`) to the
/// copy bundled in the APK, or null when it is not one of the built-in gifts.
String? bundledGiftImage(String? image) {
  if (image == null || image.isEmpty) return null;
  final name = image.split('/').last;
  if (!kBundledGiftImages.contains(name)) return null;
  return 'assets/gifts/images/$name';
}

/// Draws a gift image from the bundle when possible and falls back to the
/// network for gifts added later from the admin panel.
class GiftArtwork extends StatelessWidget {
  final String? image;
  final Size size;
  final BoxFit fit;
  final double radius;

  const GiftArtwork({
    super.key,
    required this.image,
    required this.size,
    this.fit = BoxFit.contain,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final local = bundledGiftImage(image);
    if (local != null) {
      return Image.asset(
        local,
        width: size.width,
        height: size.height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return CustomImage(
      image: image?.addBaseURL(),
      size: size,
      radius: radius,
      fit: fit,
      isImageLoaderVisible: false,
    );
  }

  Widget _placeholder() {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: const Center(
        child: Icon(Icons.card_giftcard_rounded, color: Color(0x66FFFFFF)),
      ),
    );
  }
}
