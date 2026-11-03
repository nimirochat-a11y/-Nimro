import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/manager/internet_connection_manager.dart';
import 'package:nimiro/common/widget/text_button_custom.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// Light-weight "no internet" screen. Replaces the old full-bleed artwork
/// sheet; it blocks navigation until the connection returns and closes
/// itself the moment `InternetConnectionManager` sees a reconnect.
class NoInternetSheet extends StatelessWidget {
  const NoInternetSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: Colors.white70,
              ),
              const SizedBox(height: 14),
              Text(
                LKey.noInternetTitle.tr,
                style: TextStyleCustom.outFitMedium500(
                    color: whitePure(context), fontSize: 16),
              ),
              const SizedBox(height: 22),
              TextButtonCustom(
                onTap: () => InternetConnectionManager.instance
                    .checkInternetConnection()
                    .then((value) {
                  if (value) Get.back();
                }),
                title: LKey.retry.tr,
                titleColor: whitePure(context),
                backgroundColor: whitePure(context).withValues(alpha: .3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
