import 'package:nimiro/model/user_model/app_user.dart';
import 'package:nimiro/model/user_model/user_model.dart';

extension UserExtension on User {
  AppUser get appUser {
    return AppUser(
        username: username,
        userId: id,
        profile: profilePhoto,
        fullname: fullname,
        isVerify: isVerify,
        identity: identity);
  }

}
