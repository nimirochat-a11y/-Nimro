class AppUser {
  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  int? userId;
  String? username;
  String? fullname;
  String? profile;
  int? isVerify;
  String? identity;
  String? country;

  AppUser(
      {this.userId,
      this.username,
      this.fullname,
      this.profile,
      this.isVerify,
      this.identity,
      this.country});

  AppUser.fromJson(Map<String, dynamic> json) {
    // FIX(v13): the Laravel room registry and the chat proxy emit the camelCase
    // chat contract (`userId` / `image` / `isVerified`), while this parser only
    // read the snake_case names. Every AppUser therefore came back with a null
    // id and a null photo: host cards were blank, and `getAllUsers()` matched
    // nothing so the live screen fell through to its empty view. Both spellings
    // are now accepted.
    userId = _toInt(json['user_id'] ?? json['userId'] ?? json['id']);
    identity = json['identity'];
    username = json['username'];
    fullname = json['fullname'];
    profile = json['profile'] ?? json['image'] ?? json['profile_photo'];
    isVerify = _toInt(json['is_verify'] ?? json['isVerified']);
    country = json['country'] ?? json['country_code'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_id'] = userId;
    data['identity'] = identity;
    data['username'] = username;
    data['fullname'] = fullname;
    data['profile'] = profile;
    data['is_verify'] = isVerify;
    data['country'] = country;
    return data;
  }
}
