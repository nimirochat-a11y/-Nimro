import 'package:get/get.dart';

import 'const_res.dart';

class WebService {
  static var user = _User();
  static var setting = _Setting();
  static var addPostStory = _AddPostStory();
  static var post = _Post();
  static var google = _Google();
  static var notification = _Notification();
  static var giftWallet = _GiftWallet();
  static var search = _Search();
  static var moderation = _Moderation();
  static var common = _Common();
}

class _Common {
  // SECURITY (S1/S2): was plain http:// which leaked the caller's IP in
  // cleartext and only worked because transport security was disabled.
  String ipApi = "https://ip-api.com/json/";
}
