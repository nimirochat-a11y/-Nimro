import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/common_extension.dart';
import 'package:nimiro/common/widget/custom_back_button.dart';
import 'package:nimiro/common/widget/privacy_policy_text.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/request_withdrawal_screen/request_withdrawal_screen_controller.dart';
import 'package:nimiro/utilities/app_res.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';

const Color _navy = Color(0xFF14233F);
const Color _fieldBorder = Color(0xFFE3E8F2);
const Color _softBlue = Color(0xFFEAF1FF);

class RequestWithdrawalScreen extends StatelessWidget {
  const RequestWithdrawalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RequestWithdrawalScreenController());
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  CustomBackButton(color: _navy, width: 35),
                  Expanded(
                    child: Text(
                      LKey.requestWithdrawal.tr,
                      textAlign: TextAlign.center,
                      style: TextStyleCustom.unboundedMedium500(
                          color: _navy, fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 35),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  children: [
                    _BalanceCard(controller: controller),
                    const SizedBox(height: 12),
                    _RateChip(controller: controller),
                    const SizedBox(height: 14),
                    _FormCard(controller: controller),
                    const SizedBox(height: 20),
                    _SubmitButton(onTap: controller.onSubmit),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 24),
                      child: const PrivacyPolicyText(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final RequestWithdrawalScreenController controller;
  const _BalanceCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141B2A50),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => Row(
                    children: [
                      Image.asset(AssetRes.icCoin, width: 30, height: 30),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            (controller.myUser.value?.coinWallet ?? 0)
                                .numberFormat,
                            style: TextStyleCustom.unboundedExtraBold800(
                                color: _navy, fontSize: 30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  LKey.coinBalance.tr,
                  style: TextStyleCustom.outFitLight300(
                      color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            height: 42,
            width: 42,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _softBlue,
            ),
            child: Text(
              AppRes.equal,
              style: TextStyleCustom.outFitSemiBold600(
                  color: _navy, fontSize: 22),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Obx(() {
                  final double usd = (controller.myUser.value?.coinWallet ?? 0)
                          .toDouble() *
                      (controller.settings.value?.coinValue?.toDouble() ?? 0);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(controller.localFlag,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: controller.formatLocal(usd),
                                  style: TextStyleCustom.outFitExtraBold800(
                                      color: _navy, fontSize: 24),
                                ),
                                TextSpan(
                                  text: ' ${controller.localCurrencyCode}',
                                  style: TextStyleCustom.outFitRegular400(
                                      color: _navy, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 4),
                Text(
                  LKey.estimatedValue.tr,
                  style: TextStyleCustom.outFitLight300(
                      color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  final RequestWithdrawalScreenController controller;
  const _RateChip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int per = controller.coinsPerUsd;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFE9EEF8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_alt_rounded, size: 18, color: _navy),
            const SizedBox(width: 8),
            Text(
              per > 0
                  ? '${LKey.currentValue.tr} : \u2066 1 USD = $per \u2069 ${LKey.coin.tr}'
                  : '${LKey.currentValue.tr} : -',
              style: TextStyleCustom.outFitLight300(
                  color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
      );
    });
  }
}

class _FormCard extends StatelessWidget {
  final RequestWithdrawalScreenController controller;
  const _FormCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1B2A50),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(LKey.amount.tr),
          Container(
            decoration: _fieldDecoration(),
            child: TextField(
              controller: controller.amountController,
              onChanged: controller.onChanged,
              keyboardType: TextInputType.number,
              style: TextStyleCustom.outFitRegular400(
                  color: _navy, fontSize: 15),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(
                    (controller.myUser.value?.coinWallet?.toInt() ?? 0)
                        .toString()
                        .length),
              ],
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: LKey.enterCoinAmount.tr,
                hintStyle: TextStyleCustom.outFitLight300(
                    color: Colors.grey.shade500, fontSize: 15),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 15),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(AssetRes.icCoin, width: 24, height: 24),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Label(LKey.estimatedAmount.tr),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _softBlue,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      size: 19, color: Color(0xFF2F6BFF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable:
                        controller.estimatedAmountController.value,
                    builder: (context, value, child) => Text(
                      value.text,
                      style: TextStyleCustom.outFitSemiBold600(
                          color: _navy, fontSize: 19),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Obx(
                    () => Text(
                      controller.localCurrencyCode,
                      style: TextStyleCustom.outFitSemiBold600(
                          color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Label(LKey.selectGateway.tr),
          Obx(() {
            final listFromApi =
                (controller.settings.value?.redeemGateways ?? [])
                    .map((e) => e.title ?? '')
                    .toList();
            final gateways =
                listFromApi.isEmpty ? [AppRes.emptyGatewayMessage] : listFromApi;
            if (listFromApi.isNotEmpty &&
                !listFromApi.contains(controller.selectedGateway.value)) {
              controller.selectedGateway.value = listFromApi.first;
            }
            final String current = controller.selectedGateway.value.isEmpty
                ? gateways.first
                : controller.selectedGateway.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: _fieldDecoration(),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: gateways.contains(current) ? current : gateways.first,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  style: TextStyleCustom.outFitRegular400(
                      color: _navy, fontSize: 13),
                  items: gateways
                      .map((e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(
                              e.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      controller.selectedGateway.value = v ?? '',
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          _Label(LKey.accountDetails.tr),
          Container(
            decoration: _fieldDecoration(),
            child: TextField(
              controller: controller.accountDetailsController,
              maxLines: 4,
              style: TextStyleCustom.outFitRegular400(
                  color: _navy, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _fieldDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _fieldBorder),
    );

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style:
            TextStyleCustom.unboundedMedium500(color: _navy, fontSize: 14),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SubmitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        height: 56,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient: const LinearGradient(
            colors: [Color(0xFF14233F), Color(0xFF1E3A6B)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3314233F),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              LKey.submit.tr,
              style: TextStyleCustom.unboundedMedium500(
                  color: Colors.white, fontSize: 16),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
