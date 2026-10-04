import 'package:flutter/material.dart';
import 'package:nimiro/common/extensions/common_extension.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/model/post_story/post_model.dart';
import 'package:nimiro/screen/post_screen/post_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class PostViewActionButton extends StatelessWidget {
  final Post post;
  final PostScreenController controller;
  final GlobalKey likeKey;
  final void Function(Function trigger)? onTriggerReady;

  const PostViewActionButton(
      {super.key,
      required this.post,
      required this.controller,
      required this.likeKey,
      this.onTriggerReady});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      // Row + Expanded instead of Wrap: all buttons always share the single
      // line, so the views button can never drop to a second line on narrow
      // screens. Counts scale down gracefully instead of pushing the row.
      child: Row(
        children: [
          Expanded(
            child: PostViewIconWithCount(
                key: likeKey,
                onTap: () => controller.onLike(post),
                color: post.isLiked ?? false ? ColorRes.likeRed : null,
                image: post.isLiked ?? false
                    ? AssetRes.icFillHeart
                    : AssetRes.icHeart,
                count: post.likes),
          ),
          if (post.canComment == 1)
            Expanded(
              child: PostViewIconWithCount(
                  onTap: controller.onComment,
                  image: AssetRes.icPostComment,
                  count: post.comments),
            ),
          Expanded(
            child: PostViewIconWithCount(
                onTap: () => controller.onRepost(post),
                image: AssetRes.icPostShare,
                iconBuilder: (c) => RepostIcon(color: c),
                color: post.isReposted ?? false ? const Color(0xFF1FA85B) : null,
                count: post.reposts),
          ),
          Expanded(
            child: PostViewIconWithCount(
                onTap: () => controller.onSaved(post),
                image: post.isSaved ?? false
                    ? AssetRes.icFillBookmark
                    : AssetRes.icPostBookmark,
                count: post.saves),
          ),
          if (post.userId != SessionManager.instance.getUserID())
            Expanded(
              child: PostViewIconWithCount(
                onTap: () => controller.onGiftTap(post),
                image: AssetRes.icGift_2,
                isCountVisible: false,
              ),
            ),
          Expanded(
            child: PostViewIconWithCount(
                onTap: () {},
                image: AssetRes.icPostViews,
                iconBuilder: (c) => OutlinedBarsIcon(color: c),
                count: post.views),
          ),
        ],
      ),
    );
  }
}

class PostViewIconWithCount extends StatelessWidget {
  final String image;
  final Widget Function(Color color)? iconBuilder;
  final num? count;
  final VoidCallback onTap;
  final Color? color;
  final bool isCountVisible;
  final Key? likeKey;

  const PostViewIconWithCount(
      {super.key,
      required this.image,
      this.iconBuilder,
      this.count,
      required this.onTap,
      this.color,
      this.isCountVisible = true,
      this.likeKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 3,
      children: [
        InkWell(
          onTap: onTap,
          child: iconBuilder != null
              ? SizedBox(
                  height: 23,
                  width: 23,
                  child: iconBuilder!(color ?? textDarkGrey(context)))
              : Image.asset(
              key: likeKey,
              image,
              color: color ?? textDarkGrey(context),
              height: 23,
              width: 23),
        ),
        if (isCountVisible)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                (count ?? 0).numberFormat,
                maxLines: 1,
                style: TextStyleCustom.outFitRegular400(
                    fontSize: 12.5, color: textDarkGrey(context)),
              ),
            ),
          )
      ],
    );
  }
}

class OutlinedBarsIcon extends StatelessWidget {
  final Color color;
  const OutlinedBarsIcon({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _OutlinedBarsPainter(color));
  }
}

class _OutlinedBarsPainter extends CustomPainter {
  final Color color;
  _OutlinedBarsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = size.width * 0.075;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final double barW = size.width * 0.26;
    final double gap = size.width * 0.07;
    final double total = barW * 3 + gap * 2;
    final double startX = (size.width - total) / 2;
    final List<double> heights = [0.46, 0.92, 0.66];
    for (int i = 0; i < 3; i++) {
      final double h = size.height * heights[i];
      final double left = startX + i * (barW + gap);
      final rect = Rect.fromLTWH(
          left + stroke / 2, size.height - h + stroke / 2,
          barW - stroke, h - stroke - size.height * 0.04);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(barW * 0.32)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OutlinedBarsPainter old) => old.color != color;
}

class RepostIcon extends StatelessWidget {
  final Color color;
  const RepostIcon({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RepostPainter(color));
  }
}

class _RepostPainter extends CustomPainter {
  final Color color;
  _RepostPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final top = Path()
      ..moveTo(w * 0.20, h * 0.44)
      ..lineTo(w * 0.20, h * 0.36)
      ..quadraticBezierTo(w * 0.20, h * 0.26, w * 0.30, h * 0.26)
      ..lineTo(w * 0.80, h * 0.26);
    canvas.drawPath(top, paint);
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.68, h * 0.14)
          ..lineTo(w * 0.80, h * 0.26)
          ..lineTo(w * 0.68, h * 0.38),
        paint);

    final bottom = Path()
      ..moveTo(w * 0.80, h * 0.56)
      ..lineTo(w * 0.80, h * 0.64)
      ..quadraticBezierTo(w * 0.80, h * 0.74, w * 0.70, h * 0.74)
      ..lineTo(w * 0.20, h * 0.74);
    canvas.drawPath(bottom, paint);
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.32, h * 0.62)
          ..lineTo(w * 0.20, h * 0.74)
          ..lineTo(w * 0.32, h * 0.86),
        paint);
  }

  @override
  bool shouldRepaint(covariant _RepostPainter old) => old.color != color;
}
