import 'package:cached_network_image/cached_network_image.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/style_res.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// The ONE cover renderer for every profile surface.
///
/// WHY THIS EXISTS: the profile header is mounted from several routes (my own
/// profile, another user's profile, and the profile opened from chat, search,
/// a notification, or a QR scan). Each used to draw its own hero area, and
/// anything drawn twice drifts apart. This widget is the single place that
/// decides what a cover looks like, so those surfaces cannot disagree.
///
/// COLOURS: everything resolves through the app's own identity — [ColorRes] via
/// the `theme_res.dart` accessors, plus [StyleRes.themeGradient]. No colour is
/// taken from any reference design; only the layout was.
///
/// COVER ART: the brand gradient. [coverImageUrl] is the single seam for a real
/// cover image and is currently never populated, because `tbl_users` has no
/// cover column (verified: 50 columns, no cover/cover_photo). When that column
/// and its upload endpoint exist, only the caller has to start passing this —
/// the widget itself needs no further change.
class ProfileCover extends StatelessWidget {
  /// Cover height as a fraction of its width — 16:9.
  static const double aspectRatio = 16 / 9;

  /// Outer diameter of the avatar that straddles the cover's lower edge.
  static const double avatarDiameter = 84;

  /// How far the avatar hangs BELOW the cover. This widget reserves exactly
  /// this much extra height, so whoever follows it starts clear of the avatar
  /// and nothing has to paint outside its own box.
  static const double avatarOverlap = 30;

  /// Corner radius of the cover's bottom edge.
  static const double bottomRadius = 24;

  final User? user;

  /// Controls painted on top of the cover (back, share, …). Laid out with
  /// `space-between`, so pass at most two.
  final List<Widget> overlayActions;

  /// Shown for the profile's owner: a small camera affordance on the cover.
  final bool showEditHint;

  /// Invoked by the camera affordance. Required for the hint to render.
  final VoidCallback? onTapEditCover;

  /// Avatar drawn overlapping the bottom edge, or null for a bare cover.
  final Widget? avatar;

  /// Reserved seam for a real cover image once the backend exposes one.
  final String? coverImageUrl;

  const ProfileCover({
    super.key,
    this.user,
    this.overlayActions = const [],
    this.showEditHint = false,
    this.onTapEditCover,
    this.avatar,
    this.coverImageUrl,
  });

  static const SmoothBorderRadius _bottomSmoothRadius = SmoothBorderRadius.only(
    bottomLeft: SmoothRadius(cornerRadius: bottomRadius, cornerSmoothing: 1),
    bottomRight: SmoothRadius(cornerRadius: bottomRadius, cornerSmoothing: 1),
  );

  static const BorderRadius _bottomRadius = BorderRadius.only(
    bottomLeft: Radius.circular(bottomRadius),
    bottomRight: Radius.circular(bottomRadius),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double coverHeight = width / aspectRatio;
        final double totalHeight =
            coverHeight + (avatar == null ? 0 : avatarOverlap);

        return SizedBox(
          width: width,
          height: totalHeight,
          child: Stack(
            children: [
              PositionedDirectional(
                start: 0,
                end: 0,
                top: 0,
                height: coverHeight,
                child: _coverSurface(context, width, coverHeight),
              ),
              // Scrim. Light overlay controls over media need a dark wash
              // underneath — the same reasoning as `mediaScrim` in
              // theme_res.dart. Without it the controls vanish on a bright
              // cover, and this is the one place a colour intentionally does
              // not follow the light theme.
              PositionedDirectional(
                start: 0,
                end: 0,
                top: 0,
                height: coverHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _bottomRadius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        mediaScrim(context).withValues(alpha: .30),
                        mediaScrim(context).withValues(alpha: .02),
                        mediaScrim(context).withValues(alpha: .24),
                      ],
                      stops: const [0, .5, 1],
                    ),
                  ),
                ),
              ),
              if (showEditHint && onTapEditCover != null)
                PositionedDirectional(
                  end: 12,
                  top: 12,
                  child: _CoverCameraHint(onTap: onTapEditCover!),
                ),
              if (overlayActions.isNotEmpty)
                PositionedDirectional(
                  start: 4,
                  end: 4,
                  top: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: overlayActions,
                  ),
                ),
              if (avatar != null)
                PositionedDirectional(
                  start: 20,
                  top: coverHeight - (avatarDiameter - avatarOverlap),
                  child: avatar!,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _coverSurface(BuildContext context, double width, double height) {
    final String? cover = coverImageUrl;
    if (cover != null && cover.isNotEmpty) {
      return ClipSmoothRect(
        radius: _bottomSmoothRadius,
        child: CachedNetworkImage(
          fit: BoxFit.cover,
          imageUrl: cover,
          cacheKey: cover,
          width: width,
          height: height,
          placeholder: (context, url) => Container(
            width: width,
            height: height,
            color: bgGrey(context),
          ),
          errorWidget: (context, error, stackTrace) => const _BrandGradient(),
        ),
      );
    }
    return const ClipSmoothRect(
      radius: _bottomSmoothRadius,
      child: _BrandGradient(),
    );
  }
}

/// The app-identity gradient used whenever there is no cover image. Identical
/// for every user, and deliberately NOT derived from the name, so the surface
/// stays stable no matter who is being viewed.
class _BrandGradient extends StatelessWidget {
  const _BrandGradient();

  @override
  Widget build(BuildContext context) {
    // StyleRes.themeGradient is a non-const `static Gradient`, so this cannot
    // be a const DecoratedBox.
    return DecoratedBox(
      decoration: BoxDecoration(gradient: StyleRes.themeGradient),
    );
  }
}

/// Circular translucent camera affordance shown on the cover of my profile.
class _CoverCameraHint extends StatelessWidget {
  final VoidCallback onTap;

  const _CoverCameraHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: LKey.editCover.tr,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          height: 34,
          width: 34,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: const CircleBorder(),
            color: mediaScrim(context).withValues(alpha: .38),
          ),
          child: Image.asset(
            AssetRes.icCamera,
            height: 17,
            width: 17,
            color: onMediaText(context),
          ),
        ),
      ),
    );
  }
}

/// Circular translucent control for [ProfileCover.overlayActions] (back/share).
class CoverOverlayButton extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  final double size;

  const CoverOverlayButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        height: 38,
        width: 38,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: const CircleBorder(),
          color: mediaScrim(context).withValues(alpha: .32),
        ),
        child: Image.asset(
          icon,
          height: size,
          width: size,
          color: onMediaText(context),
        ),
      ),
    );
  }
}
