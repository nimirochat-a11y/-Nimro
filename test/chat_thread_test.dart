import 'package:flutter_test/flutter_test.dart';
import 'package:nimiro/model/chat/chat_thread.dart';
import 'package:nimiro/model/user_model/app_user.dart';

void main() {
  test('parses loose row types and keeps the chat user on merge', () {
    final user = AppUser(
      userId: 104,
      fullname: 'Abdullah',
      profile: 'Nimiro/uploads/avatar.jpg',
    );
    final thread = ChatThread.fromJson(
      {
        'user_id': '104',
        'id': 1794307560363,
        'msg_count': '0',
        'chat_type': 'approved',
        'is_deleted': 'false',
        'i_blocked': 'true',
      },
      chatUser: user,
    );

    expect(thread.userId, 104);
    expect(thread.id, '1794307560363');
    expect(thread.isDeleted, isFalse);
    expect(thread.iBlocked, isTrue);
    expect(thread.chatUser?.profile, 'Nimiro/uploads/avatar.jpg');

    thread.updateFromJson({
      'user_id': 104,
      'last_msg': 'hello',
      'is_deleted': true,
    });

    expect(thread.lastMsg, 'hello');
    expect(thread.isDeleted, isTrue);
    expect(thread.chatUser?.profile, 'Nimiro/uploads/avatar.jpg');
  });

  test('treats the literal null profile as absent', () {
    final user = AppUser.fromJson({
      'user_id': 44,
      'profile': 'null',
      'image': 'Nimiro/uploads/real.jpg',
    });

    expect(user.profile, 'Nimiro/uploads/real.jpg');
  });
}
