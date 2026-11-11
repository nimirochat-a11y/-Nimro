class AppUser {
  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  /// Treat the literal strings some older clients wrote into the database
  /// ("null", "undefined") as absent values. Without this, an avatar path of
  /// "null" is handed to the image loader and the photo disappears.
  static String? cleanText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower == 'null' || lower == 'undefined') return null;
    return text;
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
    userId =
        _toInt(json['user_id']) ?? _toInt(json['userId']) ?? _toInt(json['id']);
    identity = cleanText(json['identity']);
    username = cleanText(json['username']);
    fullname = cleanText(json['fullname']);
    profile = cleanText(json['profile']) ??
        cleanText(json['image']) ??
        cleanText(json['profile_photo']);
    isVerify = _toInt(json['is_verify'] ?? json['isVerified']);
    country = cleanText(json['country'] ?? json['country_code']);
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
