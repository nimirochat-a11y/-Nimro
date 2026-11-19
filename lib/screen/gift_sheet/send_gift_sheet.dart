import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/common_extension.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/full_name_with_blue_tick.dart';
import 'package:nimiro/common/widget/gift_media_viewer.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/user_model/app_user.dart';
import 'package:nimiro/screen/gift_sheet/send_gift_sheet_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';

/// TikTok-style gift store: a pure black sheet with compact tabs, a four
/// column gift grid and a sticky send bar. The selected gift gets TikTok's
/// signature red outline (#FE2C55).
class SendGiftSheet extends StatefulWidget {
  final GiftType giftType;
  final BattleView battleViewType;
  final int? userId;
  final List<AppUser> streamUsers;

  const SendGiftSheet(
      {super.key,
      this.giftType = GiftType.none,
      this.battleViewType = BattleView.red,
      required this.userId,
      this.streamUsers = const []});

  @override
  State<SendGiftSheet> createState() => _SendGiftSheetState();
}

const Color _kTiktokBg = Color(0xFF0B0B0F);
const Color _kSurface = Color(0xFF17171C);
const Color _kSurfaceHigh = Color(0xFF212127);
const Color _kBorder = Color(0xFF2A2A32);
const Color _kAccent = Color(0xFFFE2C55);
const Color _kTextSecondary = Color(0xFF9A9AA5);

class _SendGiftSheetState extends State<SendGiftSheet> {
  late final SendGiftSheetController controller;

  int _tab = 0;
  Gift? _selectedGift;

  bool get _isArabic => SessionManager.instance.getLang() == 'ar';

  @override
  void initState() {
    super.initState();
    controller = Get.put(SendGiftSheetController(
        widget.giftType, widget.userId, widget.streamUsers));
  }

  List<Gift> _allGifts() {
    final gifts =
        List<Gift>.from(controller.settings.value?.gifts ?? const <Gift>[]);
    gifts.sort((a, b) => (a.coinPrice ?? 0).compareTo(b.coinPrice ?? 0));
    return gifts;
  }

  List<Gift> _visibleGifts(List<Gift> all) {
    switch (_tab) {
      case 1:
        return all.where((gift) => (gift.coinPrice ?? 0) >= 1000).toList();
      case 2:
        return all;
      default:
        return all.where((gift) => (gift.coinPrice ?? 0) < 1000).toList();
    }
  }

  Gift? _selectedFrom(List<Gift> all) {
    final selected = _selectedGift;
    if (selected != null) {
      for (final gift in all) {
        if (gift.id == selected.id) return gift;
      }
      return null;
    }
    return all.isEmpty ? null : all.first;
  }

  String _displayName(Gift gift) {
    final name = gift.nameFor(isArabic: _isArabic);
    return name.isEmpty ? LKey.gift.tr : name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height * .84,
      margin: EdgeInsets.only(top: Get.height * .06),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: _kTiktokBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildGrabber(),
            _buildHeader(),
            if (widget.giftType == GiftType.battle &&
                widget.streamUsers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: _BattleBanner(
                  battleViewType: widget.battleViewType,
                  streamUser: widget.streamUsers.first,
                ),
              ),
            if ((widget.giftType == GiftType.livestream ||
                    widget.giftType == GiftType.battle) &&
                widget.streamUsers.isNotEmpty)
              GiftForLiveStream(
                controller: controller,
                streamUsers: widget.streamUsers,
              ),
            const SizedBox(height: 6),
            _buildTabs(),
            Expanded(
              child: Obx(() {
                final all = _allGifts();
                if (all.isEmpty) {
                  return const _EmptyGifts();
                }
                final visible = _visibleGifts(all);
                final selected = _selectedFrom(all);
                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      LKey.noGiftsAvailable.tr,
                      style: TextStyleCustom.outFitMedium500(
                          fontSize: 13, color: _kTextSecondary),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: visible.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisExtent: 112,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (context, index) {
                    final gift = visible[index];
                    return _GiftTile(
                      gift: gift,
                      name: _displayName(gift),
                      selected: selected?.id == gift.id,
                      onTap: () {
                        setState(() => _selectedGift = gift);
                      },
                      onPlay: (gift.video?.isNotEmpty ?? false)
                          ? () => GiftMediaViewer.open(
                              context, gift.video!.addBaseURL())
                          : null,
                    );
                  },
                );
              }),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    return Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A44),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.close_rounded,
            onTap: () => Get.back(),
          ),
          Expanded(
            child: Center(
              child: Text(
                LKey.giftsTitle.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyleCustom.outFitBold700(
                    fontSize: 18, color: Colors.white),
              ),
            ),
          ),
          Obx(() {
            final coins = controller.myUser.value?.coinWallet ?? 0;
            return Container(
              constraints: const BoxConstraints(maxWidth: 112),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(AssetRes.icCoin, width: 16, height: 16),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      coins.numberFormat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyleCustom.outFitBold700(
                          fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      LKey.popularTab.tr,
      LKey.luxuryTab.tr,
      LKey.allGifts.tr,
    ];
    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < tabs.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tab = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Text(
                          tabs[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyleCustom.outFitSemiBold600(
                            fontSize: 13,
                            color: _tab == i ? Colors.white : _kTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 7),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 3,
                          width: _tab == i ? 24 : 0,
                          decoration: BoxDecoration(
                            color: _kAccent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        Container(height: .5, color: _kBorder),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Obx(() {
      final all = _allGifts();
      final selected = _selectedFrom(all);
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(
          color: _kSurface,
          border: Border(top: BorderSide(color: _kBorder)),
        ),
        child: Row(
          children: [
            if (selected == null)
              Expanded(
                child: Text(
                  LKey.chooseGift.tr,
                  style: TextStyleCustom.outFitMedium500(
                      fontSize: 13, color: _kTextSecondary),
                ),
              )
            else ...[
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kSurfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: CustomImage(
                  image: selected.image?.addBaseURL(),
                  size: const Size(34, 34),
                  radius: 0,
                  fit: BoxFit.contain,
                  isImageLoaderVisible: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(selected),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyleCustom.outFitSemiBold600(
                          fontSize: 14, color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Image.asset(AssetRes.icCoin, width: 13, height: 13),
                        const SizedBox(width: 4),
                        Text(
                          (selected.coinPrice ?? 0).numberFormat,
                          style: TextStyleCustom.outFitMedium500(
                              fontSize: 12, color: _kTextSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SendButton(
                onTap: () => controller.onGiftTap(selected, context),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: _kSurface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  final Gift gift;
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onPlay;

  const _GiftTile({
    required this.gift,
    required this.name,
    required this.selected,
    required this.onTap,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color:
                selected ? _kAccent.withValues(alpha: .10) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _kAccent : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomImage(
                      image: gift.image?.addBaseURL(),
                      size: const Size(56, 56),
                      radius: 0,
                      fit: BoxFit.contain,
                      isImageLoaderVisible: false,
                    ),
                    if (onPlay != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: onPlay,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyleCustom.outFitMedium500(
                    fontSize: 11, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(AssetRes.icCoin, width: 11, height: 11),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      (gift.coinPrice ?? 0).numberFormat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyleCustom.outFitMedium500(
                          fontSize: 10.5, color: _kTextSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kAccent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  LKey.send.tr,
                  style: TextStyleCustom.outFitSemiBold600(
                      fontSize: 14, color: Colors.white),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.send_rounded, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BattleBanner extends StatelessWidget {
  final BattleView battleViewType;
  final AppUser streamUser;

  const _BattleBanner({required this.battleViewType, required this.streamUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            battleViewType.color,
            battleViewType.color.withValues(alpha: .72)
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CustomImage(
              size: const Size(32, 32),
              image: streamUser.profile?.addBaseURL(),
              fullName: streamUser.fullname,
              strokeColor: Colors.white,
              strokeWidth: 1.2),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FullNameWithBlueTick(
                    username: streamUser.fullname,
                    fontColor: Colors.white,
                    fontSize: 12,
                    isVerify: streamUser.isVerify),
                const SizedBox(height: 2),
                Text(
                    LKey.youAreSendingCoinsTo
                        .trParams({'color': battleViewType.value}),
                    style: TextStyleCustom.outFitLight300(
                        color: Colors.white.withValues(alpha: .92),
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGifts extends StatelessWidget {
  const _EmptyGifts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: _kSurface,
              shape: BoxShape.circle,
            ),
            child: Image.asset(AssetRes.icGift_1),
          ),
          const SizedBox(height: 12),
          Text(
            LKey.noGiftsAvailable.tr,
            textAlign: TextAlign.center,
            style: TextStyleCustom.outFitMedium500(
                fontSize: 13, color: _kTextSecondary),
          ),
        ],
      ),
    );
  }
}

class GiftForLiveStream extends StatelessWidget {
  final SendGiftSheetController controller;
  final List<AppUser> streamUsers;

  const GiftForLiveStream(
      {super.key, required this.controller, required this.streamUsers});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final giftUser = controller.livestreamController.selectedGiftUser.value;
      if (giftUser == null) return const SizedBox();
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                LKey.sendingGiftTo.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyleCustom.outFitMedium500(
                    fontSize: 11.5, color: _kTextSecondary),
              ),
            ),
            const SizedBox(width: 8),
            streamUsers.length <= 1
                ? _GiftUserChip(user: giftUser)
                : PopupMenuButton<AppUser>(
                    initialValue: giftUser,
                    onSelected: (AppUser value) {
                      controller.livestreamController.selectedGiftUser.value =
                          value;
                    },
                    color: const Color(0xFF1C1C22),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    position: PopupMenuPosition.under,
                    constraints:
                        const BoxConstraints(minWidth: 210, maxWidth: 280),
                    itemBuilder: (BuildContext context) {
                      return List.generate(
                        streamUsers.length,
                        (index) => PopupMenuItem(
                          value: streamUsers[index],
                          child: _GiftUserChip(
                              user: streamUsers[index], compact: true),
                        ),
                      );
                    },
                    child: _GiftUserChip(user: giftUser, showArrow: true),
                  ),
          ],
        ),
      );
    });
  }
}

class _GiftUserChip extends StatelessWidget {
  final AppUser user;
  final bool showArrow;
  final bool compact;

  const _GiftUserChip(
      {required this.user, this.showArrow = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 24.0 : 26.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomImage(
          size: Size(size, size),
          image: user.profile?.addBaseURL(),
          fullName: user.fullname,
          strokeColor: _kBorder,
          strokeWidth: 1,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: FullNameWithBlueTick(
            username: user.fullname,
            fontColor: Colors.white,
            fontSize: 12,
            iconSize: 12,
            isVerify: user.isVerify,
          ),
        ),
        if (showArrow) ...[
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: _kTextSecondary),
        ],
      ],
    );
  }
}

enum GiftType { none, livestream, battle }

enum BattleView {
  red('red'),
  blue('blue');

  final String value;

  const BattleView(this.value);

  Color get color {
    switch (this) {
      case BattleView.red:
        return ColorRes.likeRed;
      case BattleView.blue:
        return ColorRes.battleProgressColor;
    }
  }
}
