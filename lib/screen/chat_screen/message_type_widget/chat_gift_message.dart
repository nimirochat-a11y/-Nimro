import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/common_extension.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/gradient_border.dart';
import 'package:nimiro/common/widget/gradient_text.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/chat/message_data.dart';
import 'package:nimiro/screen/chat_screen/widget/chat_center_message_view.dart';
import 'package:nimiro/utilities/style_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class ChatGiftMessage extends StatelessWidget {
  final MessageData message;
  final bool isMe;

  const ChatGiftMessage({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 175,
      child: GradientBorder(
        strokeWidth: 2,
        radius: 16,
        gradient: StyleRes.themeGradient,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: ShapeDecoration(
            shape: SmoothRectangleBorder(
                borderRadius:
                    SmoothBorderRadius(cornerRadius: 15, cornerSmoothing: 1)),
            color: scaffoldBackgroundColor(context),
            shadows: messageBubbleShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CustomImage(
                  size: const Size(130, 130),
                  image: message.imageMessage?.addBaseURL(),
                  radius: 10,
                  cornerSmoothing: 1,
                  isShowPlaceHolder: true),
              GradientText(
                '${int.parse(message.textMessage ?? '0').numberFormat} ${LKey.coins.tr}',
                gradient: StyleRes.themeGradient,
                style: TextStyleCustom.unboundedMedium500(fontSize: 18),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 15, top: 3),
                child: Text(
                    isMe ? LKey.youSentAGift.tr : LKey.youReceivedAGift.tr,
                    style: TextStyleCustom.outFitRegular400(
                        color: textDarkGrey(context), fontSize: 14)),
              )
            ],
          ),
        ),
        onPressed: () {},
      ),
    );
  }
}
