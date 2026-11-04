import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/settings_screen/settings_screen.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// Gate screen for restricted accounts. A restricted user may not use any
/// part of the app - feeds, reels, live, chat, profile - but can still open
/// the settings screen (and log out from there).
class AccountRestrictedScreen extends StatelessWidget {
  const AccountRestrictedScreen({super.key});

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
                Icons.no_accounts_outlined,
                size: 64,
                color: Colors.white70,
              ),
              const SizedBox(height: 14),
              Text(
                LKey.accountRestricted.tr,
                style: TextStyleCustom.outFitMedium500(
                    color: whitePure(context), fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                LKey.accountRestrictedDesc.tr,
                textAlign: TextAlign.center,
                style: TextStyleCustom.outFitRegular400(
                    color: whitePure(context), fontSize: 13, opacity: .7),
              ),
              const SizedBox(height: 22),
              TextButton(
                onPressed: () => Get.to(() => const SettingsScreen()),
                style: TextButton.styleFrom(
                  backgroundColor: whitePure(context).withValues(alpha: .3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                ),
                child: Text(
                  LKey.settings.tr,
                  style: TextStyleCustom.outFitMedium500(
                      color: whitePure(context), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
