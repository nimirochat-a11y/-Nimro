import 'package:crisp_chat/crisp_chat.dart' as crisp;
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/utilities/const_res.dart';

/// Opens the Crisp live-chat used as the in-app support desk.
///
/// Only the user's display name and account ID are shared with Crisp, so the
/// conversation can be linked to the account without exposing email or phone.
class CrispSupportService {
  CrispSupportService._();

  static final CrispSupportService instance = CrispSupportService._();

  bool get isConfigured => crispWebsiteId.trim().isNotEmpty;

  Future<void> openSupportChat() async {
    if (!isConfigured) {
      throw StateError('Crisp Website ID is not configured.');
    }

    final User? user = SessionManager.instance.getUser();
    final bool isArabic = SessionManager.instance.getLang() == 'ar';
    final String? nickName = _displayName(user);

    final crisp.CrispConfig config = crisp.CrispConfig(
      websiteID: crispWebsiteId,
      tokenId: user?.id?.toString(),
      enableNotifications: false,
      user: nickName == null ? null : crisp.User(nickName: nickName),
      modalPresentationStyle: crisp.ModalPresentationStyle.fullScreen,
      localMessages: [
        crisp.CrispTextContent(
          isArabic
              ? 'مرحبًا بك في الدعم الفني لنيميرو. اكتب رسالتك وسنرد عليك في أقرب وقت ممكن.'
              : 'Welcome to Nimiro support. Write your message and we will reply as soon as possible.',
        ),
      ],
    );

    await crisp.FlutterCrispChat.openCrispChat(config: config);
  }

  /// Clears the Crisp session so the next account starts a fresh conversation.
  ///
  /// A failed reset must never block logout or account deletion.
  Future<void> resetSession() async {
    try {
      await crisp.FlutterCrispChat.resetCrispChatSession();
    } catch (_) {
      // Ignore: Crisp may not have an active session yet.
    }
  }

  String? _displayName(User? user) {
    final String fullname = user?.fullname?.trim() ?? '';
    if (fullname.isNotEmpty) return fullname;

    final String username = user?.username?.trim() ?? '';
    if (username.isNotEmpty) return username;

    return null;
  }
}
