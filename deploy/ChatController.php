<?php

namespace App\Http\Controllers;

use App\Services\SupabaseClient;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;
use Throwable;

/**
 * Chat + app-user endpoints, proxied to Supabase through the backend.
 *
 * WHY THIS EXISTS
 * ---------------
 * The mobile app used to open a direct PostgREST connection to Supabase with
 * the publishable key baked into the APK. Because the tables had no Row Level
 * Security, any holder of that key could read every message and every user
 * row. Moving the traffic here lets Supabase keep a real secret (service_role,
 * server-side only) and lets us enable RLS without breaking the chat.
 *
 * IDENTITY
 * --------
 * Every route below sits behind the `authorizeUser` middleware, and the acting
 * user id is taken from the token resolved by that middleware - NEVER from the
 * request body.
 */
class ChatController extends Controller
{
    private SupabaseClient $sb;

    public function __construct()
    {
        try {
            $this->sb = new SupabaseClient();
        } catch (RuntimeException $e) {
            // Deferred: individual actions report 503 with a clear message.
        }
    }

    private function unconfigured(): ?JsonResponse
    {
        if (isset($this->sb)) {
            return null;
        }

        return response()->json([
            'status' => false,
            'message' => 'Chat backend is not configured yet.',
        ], 503);
    }

    private function fail(string $message, int $code = 500): JsonResponse
    {
        return response()->json(['status' => false, 'message' => $message], $code);
    }

    /** The acting user id, resolved by the authorizeUser middleware. */
    private function authUserId(Request $request): ?int
    {
        $id = $request->attributes->get('auth_user_id')
            ?? $request->get('auth_user_id');

        if ($id === null || ! preg_match('/^[1-9][0-9]*$/D', (string) $id)) {
            return null;
        }

        $userId = (int) $id;

        return $userId > 0 && (string) $userId === (string) $id ? $userId : null;
    }

    /**
     * The Flutter app's canonical room id is the two positive user ids sorted
     * numerically and joined with an underscore (e.g. "12_34").
     *
     * @return array{0:int,1:int}|null
     */
    private function conversationParticipants(string $conversationId): ?array
    {
        if (! preg_match('/^([1-9][0-9]*)_([1-9][0-9]*)$/D', $conversationId, $matches)) {
            return null;
        }

        $first = (int) $matches[1];
        $second = (int) $matches[2];

        if ($first <= 0 || $second <= $first
            || (string) $first !== $matches[1]
            || (string) $second !== $matches[2]) {
            return null;
        }

        return [$first, $second];
    }

    /**
     * Conversation document ids are directional: "ownerId_otherUserId".
     *
     * @return array{0:int,1:int}|null
     */
    private function conversationDocIdParticipants(string $docId): ?array
    {
        if (! preg_match('/^([1-9][0-9]*)_([1-9][0-9]*)$/D', $docId, $matches)) {
            return null;
        }

        $ownerId = (int) $matches[1];
        $otherId = (int) $matches[2];

        if ($ownerId <= 0 || $otherId <= 0 || $ownerId === $otherId
            || (string) $ownerId !== $matches[1]
            || (string) $otherId !== $matches[2]) {
            return null;
        }

        return [$ownerId, $otherId];
    }

    private function canonicalConversationId(int $firstUserId, int $secondUserId): string
    {
        $ids = [$firstUserId, $secondUserId];
        sort($ids, SORT_NUMERIC);

        return implode('_', $ids);
    }

    private function isConversationParticipant(string $conversationId, int $userId): bool
    {
        $participants = $this->conversationParticipants($conversationId);

        return $participants !== null && in_array($userId, $participants, true);
    }

    private function conversationNotFound(): JsonResponse
    {
        // Do not reveal whether another user's conversation exists.
        return $this->fail('Conversation not found.', 404);
    }

    // -----------------------------------------------------------------
    // Conversations
    // -----------------------------------------------------------------

    /** List the authenticated user's inbox. */
    public function fetchMyConversations(Request $request): JsonResponse
    {
        if ($e = $this->unconfigured()) {
            return $e;
        }

        $userId = $this->authUserId($request);
        if ($userId === null) {
            return $this->fail('Unauthorized Access', 401);
        }

        try {
            $rows = $this->sb->selectConversationsForUser(
                $userId,
                ['is_deleted' => 'false'],
                200,
                'id.desc'
            );
            $rows = array_values(array_filter(
                $rows,
                function (array $row) use ($userId): bool {
                    $docParticipants = $this->conversationDocIdParticipants(
                        (string) ($row['doc_id'] ?? '')
                    );

                    // Each participant has a mirrored directional row; only
                    // the row owned by this user belongs in their inbox.
                    return $docParticipants !== null
                        && $docParticipants[0] === $userId
                        && $this->isConversationParticipant(
                            (string) ($row['conversation_id'] ?? ''),
                            $userId
                        );
                }
            ));

            return response()->json(['status' => true, 'data' => $rows]);
        } catch (Throwable $e) {
            return $this->fail('Could not load conversations.');
        }
    }

    /** Fetch one conversation row by its deterministic doc_id. */
    public function fetchConversation(Request $request): JsonResponse
    {
        if ($e = $this->unconfigured()) {
            return $e;
        }

        $userId = $this->authUserId($request);
        $otherUserId = (int) $request->input('other_user_id', 0);
        if ($userId === null || $otherUserId <= 0) {
            return $this->fail('Unauthorized Access', 401);
        }

        $docId = (string) ($request->input('doc_id') ?: $userId . '_' . $otherUserId);
        $participants = $this->conversationDocIdParticipants($docId);
        if ($participants === null
            || ! in_array($userId, $participants, true)
            || ! in_array($otherUserId, $participants, true)
            || $userId === $otherUserId) {
            return $this->conversationNotFound();
        }

        try {
            $row = $this->sb->first('conversations', ['doc_id' => $docId]);
            if ($row !== null
                && (string) ($row['conversation_id'] ?? '')
                    !== $this->canonicalConversationId($participants[0], $participants[1])) {
                return $this->conversationNotFound();
            }

            return response()->json(['status' => true, 'data' => $row]);
        } catch (Throwable $e) {
            return $this->fail('Could not load the conversation.');
        }
    }

    /** Create or update a conversation row. */
    public function upsertConversation(Request $request): JsonResponse
    {
        if ($e = $this->unconfigured()) {
            return $e;
        }

        $userId = $this->authUserId($request);
        $otherUserId = (int) $request->input('other_user_id', 0);
        if ($userId === null || $otherUserId <= 0) {
            return $this->fail('Unauthorized Access', 401);
        }

        $docId = (string) ($request->input('doc_id') ?: $userId . '_' . $otherUserId);
        $participants = $this->conversationDocIdParticipants($docId);
        if ($participants === null
            || $participants[1] !== $otherUserId
            || ! in_array($userId, $participants, true)) {
            return $this->conversationNotFound();
        }
        $conversationId = $this->canonicalConversationId($participants[0], $participants[1]);

        if ($request->has('conversation_id')
            && (string) $request->input('conversation_id') !== $conversationId) {
            return $this->fail('conversation_id does not match the participants.', 422);
        }

        // Only fields the client is allowed to influence are accepted.
        $allowed = [
            'id', 'chat_type', 'last_msg', 'msg_count',
            'is_deleted', 'deleted_id', 'request_type',
        ];

        $payload = [
            'doc_id' => $docId,
            // The directional document id is authoritative; never trust a
            // client-supplied user_id (the old proxy wrote the actor into both
            // fields when creating the recipient's mirrored inbox row).
            'user_id' => $participants[0],
            'other_user_id' => $participants[1],
            'conversation_id' => $conversationId,
        ];

        foreach ($allowed as $field) {
            if ($request->has($field)) {
                $payload[$field] = $request->input($field);
            }
        }

        if (array_key_exists('id', $payload) && $payload['id'] === null) {
            unset($payload['id']);
        }
        if (array_key_exists('id', $payload)
            && (! is_scalar($payload['id']) || ! ctype_digit((string) $payload['id']))) {
            return $this->fail('Conversation id must be numeric.', 422);
        }
        if (array_key_exists('id', $payload)) {
            $payload['id'] = (string) $payload['id'];
        }

        try {
            $existing = $this->sb->first('conversations', ['doc_id' => $docId]);
            if ($existing !== null
                && (string) ($existing['conversation_id'] ?? '') !== $conversationId) {
                return $this->fail('Conversation id conflict.', 409);
            }

            $rows = $this->sb->upsert('conversations', $payload, 'doc_id');

            return response()->json(['status' => true, 'data' => $rows[0] ?? null]);
        } catch (Throwable $e) {
            return $this->fail('Could not save the conversation.');
        }
    }

    // -----------------------------------------------------------------
    // Messages
    // -----------------------------------------------------------------

    /** Page through the messages of one conversation. */
    public function fetchMessages(Request $request): JsonResponse
    {
        if ($e = $this->unconfigured()) {
            return $e;
        }

        $userId = $this->authUserId($request);
        if ($userId === null) {
            return $this->fail('Unauthorized Access', 401);
        }

        $conversationId = (string) $request->input('conversation_id', '');
        if ($conversationId === '') {
            return $this->fail('conversation_id is required', 422);
        }
        if (! $this->isConversationParticipant($conversationId, $userId)) {
            return $this->conversationNotFound();
        }

        $limit = (int) $request->input('limit', 50);
        $limit = max(1, min($limit, 100));

        $operators = [];
        if ($cursor = $request->input('cursor_after_document_id')) {
            if (! ctype_digit((string) $cursor)
                || (int) $cursor <= 0
                || (string) (int) $cursor !== (string) $cursor) {
                return $this->fail('cursor_after_document_id must be numeric.', 422);
            }
            $operators[] = ['id', 'lt', (int) $cursor];
        }

        try {
            $rows = $this->sb->select(
                'messages',
                ['conversation_id' => $conversationId],
                $operators,
                '*',
                $limit,
                'id.desc'
            );

            return response()->json(['status' => true, 'data' => $rows]);
        } catch (Throwable $e) {
            return $this->fail('Could not load messages.');
        }
    }

    /** Fetch one message only when the authenticated user belongs to its room. */
    public function fetchMessage(Request $request): JsonResponse
    {
        if ($e = $this->unconfigured()) {
            return $e;
        }

        $userId = $this->authUserId($request);
        $docId = (string) $request->input('doc_id', '');
        if ($userId === null) {
            return $this->fail('Unauthorized Access', 401);
        }
        if ($docId === '') {
            return $this->fail('doc_id is required.', 422);
        }

        try {
            $row = $this->sb->first('messages', ['doc_id' => $docId]);
            if ($row !== null && ! $this->isConversationParticipant(
                (string) ($row['conversation_id'] ?? ''),
                $userId
            )) {
                return $this->conversationNotFound();
            }

            return response()->json(['status' => true, 'data' => $row]);
        } catch (Throwable $e) {
            return $this->fail('Could not load the message.');
        }
    }

    /** Send one message. */
    public function sendMessage(Request $request): JsonResponse
    {
        if ($e = $this->unconfigured()) {
            return $e;
        }

        $userId = $this->authUserId($request);
        $docId = (string) $request->input('doc_id', '');
        $conversationId = (string) $request->input('conversation_id', '');

        if ($userId === null) {
            return $this->fail('Unauthorized Access', 401);
        }
        if ($docId === '' || $conversationId === '') {
            return $this->fail('doc_id and conversation_id are required', 422);
        }
        if (! ctype_digit($docId) || (int) $docId <= 0 || (string) (int) $docId !== $docId) {
            return $this->fail('doc_id must be a positive numeric message id.', 422);
        }
        $participants = $this->conversationParticipants($conversationId);
        if ($participants === null || ! in_array($userId, $participants, true)) {
            return $this->conversationNotFound();
        }

        try {
            $existing = $this->sb->first('messages', ['doc_id' => $docId]);
            if ($existing !== null) {
                return $this->fail('Message id conflict.', 409);
            }
        } catch (Throwable $e) {
            return $this->fail('Could not validate the message.');
        }

        $allowed = [
            'message_type', 'text_message', 'image_message', 'video_message',
            'audio_message', 'post_message', 'story_reply_message', 'wave_data',
        ];

        $payload = [
            'doc_id' => $docId,
            'id' => (int) $docId,
            'conversation_id' => $conversationId,
            // Sender is the authenticated user. A body value is ignored.
            'user_id' => $userId,
            'no_delete_ids' => $participants,
            'i_blocked' => false,
            'i_am_blocked' => false,
        ];

        foreach ($allowed as $field) {
            if ($request->has($field)) {
                $payload[$field] = $request->input($field);
            }
        }

        try {
            $rows = $this->sb->upsert('messages', $payload, 'doc_id');

            return response()->json(['status' => true, 'data' => $rows[0] ?? null]);
        } catch (Throwable $e) {
            return $this->fail('Could not send the message.');
        }
    }

    /** Update one message (edit / read receipt / soft fields). */
    public function updateMessage(Request $request): JsonResponse
    {
        if ($e = $this->unconfigured()) {
            return $e;
        }

        $userId = $this->authUserId($request);
        if ($userId === null) {
            return $this->fail('Unauthorized Access', 401);
        }

        $docId = (string) $request->input('doc_id', '');
        $changes = $request->input('data', []);

        if ($docId === '' || ! is_array($changes) || $changes === []) {
            return $this->fail('doc_id and data are required', 422);
        }

        if (array_diff(array_keys($changes), ['no_delete_ids', 'story_reply_message']) !== []) {
            return $this->fail('Unsupported message fields.', 422);
        }

        try {
            $existing = $this->sb->first(
                'messages',
                ['doc_id' => $docId],
                'doc_id,conversation_id,user_id,no_delete_ids'
            );
            if ($existing === null) {
                return $this->conversationNotFound();
            }

            $conversationId = (string) ($existing['conversation_id'] ?? '');
            $participants = $this->conversationParticipants($conversationId);
            if ($participants === null || ! in_array($userId, $participants, true)) {
                return $this->conversationNotFound();
            }

            if (array_key_exists('no_delete_ids', $changes)) {
                if (! is_array($changes['no_delete_ids'])) {
                    return $this->fail('no_delete_ids must be an array.', 422);
                }
                $ids = [];
                foreach ($changes['no_delete_ids'] as $id) {
                    if (! is_numeric($id) || ! in_array((int) $id, $participants, true)) {
                        return $this->fail('no_delete_ids contains an invalid participant.', 422);
                    }
                    $ids[] = (int) $id;
                }
                $ids = array_values(array_unique($ids));
                $oldIds = $existing['no_delete_ids'] ?? [];
                if (! is_array($oldIds)) {
                    return $this->fail('Stored no_delete_ids is invalid.', 409);
                }
                $oldIds = array_values(array_unique(array_map('intval', $oldIds)));
                if (array_diff($ids, $oldIds) !== []
                    || array_diff(array_diff($oldIds, $ids), [$userId]) !== []) {
                    return $this->fail('You may only remove yourself from no_delete_ids.', 403);
                }
                $changes['no_delete_ids'] = $ids;
            }

            if (array_key_exists('story_reply_message', $changes)
                && ! is_string($changes['story_reply_message'])) {
                return $this->fail('story_reply_message must be a string.', 422);
            }

            $rows = $this->sb->update('messages', $changes, ['doc_id' => $docId]);

            return response()->json(['status' => true, 'data' => $rows[0] ?? null]);
        } catch (Throwable $e) {
            return $this->fail('Could not update the message.');
        }
    }

    /** Delete one message. */
    public function deleteMessage(Request $request): JsonResponse
    {
        if ($e = $this->unconfigured()) {
            return $e;
        }

        $userId = $this->authUserId($request);
        if ($userId === null) {
            return $this->fail('Unauthorized Access', 401);
        }

        $docId = (string) $request->input('doc_id', '');
        if ($docId === '') {
            return $this->fail('doc_id is required', 422);
        }

        try {
            $message = $this->sb->first(
                'messages',
                ['doc_id' => $docId],
                'doc_id,conversation_id,no_delete_ids'
            );
            if ($message === null || ! $this->isConversationParticipant(
                (string) ($message['conversation_id'] ?? ''),
                $userId
            )) {
                return $this->conversationNotFound();
            }
            $remainingUsers = $message['no_delete_ids'] ?? [];
            if (! is_array($remainingUsers)) {
                return $this->fail('Stored no_delete_ids is invalid.', 409);
            }
            $remainingUsers = array_values(array_unique(array_map('intval', $remainingUsers)));
            if (count($remainingUsers) >= 2
                || (count($remainingUsers) === 1 && $remainingUsers[0] !== $userId)) {
                return $this->fail('Both participants must hide the message before permanent deletion.', 409);
            }

            $this->sb->delete('messages', ['doc_id' => $docId]);

            return response()->json(['status' => true]);
        } catch (Throwable $e) {
            return $this->fail('Could not delete the message.');
        }
    }

    // -----------------------------------------------------------------
    // App users (chat profile mirror)
    // -----------------------------------------------------------------

    /** Fetch chat profile rows for the given ids. */
    public function fetchAppUsers(Request $request): JsonResponse
    {
        if ($e = $this->unconfigured()) {
            return $e;
        }

        if ($this->authUserId($request) === null) {
            return $this->fail('Unauthorized Access', 401);
        }

        $ids = $request->input('user_ids', []);
        if (is_string($ids)) {
            $ids = array_filter(explode(',', $ids));
        }
        if (! is_array($ids)) {
            return $this->fail('user_ids must be a list of numeric ids.', 422);
        }

        $clean = [];
        foreach ($ids as $id) {
            if (! ctype_digit((string) $id)
                || (int) $id <= 0
                || (string) (int) $id !== (string) $id) {
                return $this->fail('user_ids must contain positive numeric ids.', 422);
            }
            $clean[] = (int) $id;
        }
        $clean = array_values(array_unique($clean));
        if ($clean === [] || count($clean) > 100) {
            return $this->fail('Provide between 1 and 100 user ids.', 422);
        }

        try {
            // Do not expose `identity` (which may contain an email/login value)
            // to other users; chat UI only needs the public profile fields.
            $rows = $this->sb->select(
                'app_users',
                [],
                [['user_id', 'in', '(' . implode(',', $clean) . ')']],
                'user_id,username,fullname,profile,is_verify',
                100,
                ''
            );

            return response()->json(['status' => true, 'data' => $rows]);
        } catch (Throwable $e) {
            return $this->fail('Could not load chat profiles.');
        }
    }

    /**
     * Upsert a chat profile row.
     *
     * The row is always written for the authenticated user, so a client cannot
     * overwrite somebody else's profile.
     */
    public function upsertAppUser(Request $request): JsonResponse
    {
        if ($e = $this->unconfigured()) {
            return $e;
        }

        $userId = $this->authUserId($request);
        if ($userId === null) {
            return $this->fail('Unauthorized Access', 401);
        }

        // Authentication identity and verification status are managed by the
        // trusted auth/profile backend, not by a mobile client request.
        $allowed = ['username', 'fullname', 'profile'];

        $payload = [
            'doc_id' => (string) $userId,
            'user_id' => $userId,
        ];

        foreach ($allowed as $field) {
            if ($request->has($field)) {
                $payload[$field] = $request->input($field);
            }
        }

        try {
            $rows = $this->sb->upsert('app_users', $payload, 'doc_id');

            return response()->json(['status' => true, 'data' => $rows[0] ?? null]);
        } catch (Throwable $e) {
            return $this->fail('Could not save the chat profile.');
        }
    }

    /** Delete the authenticated user's own chat profile row. */
    public function deleteAppUser(Request $request): JsonResponse
    {
        if ($e = $this->unconfigured()) {
            return $e;
        }

        $userId = $this->authUserId($request);
        if ($userId === null) {
            return $this->fail('Unauthorized Access', 401);
        }

        try {
            $this->sb->delete('app_users', ['doc_id' => (string) $userId]);

            return response()->json(['status' => true]);
        } catch (Throwable $e) {
            return $this->fail('Could not delete the chat profile.');
        }
    }
}
