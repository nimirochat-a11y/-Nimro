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

        return $id === null ? null : (int) $id;
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
            $rows = $this->sb->select('conversations', [
                'user_id' => $userId,
                'is_deleted' => 'false',
            ], [], '*', 200, 'id.desc');

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

        $docId = $request->input('doc_id') ?: $userId . '_' . $otherUserId;

        try {
            $row = $this->sb->first('conversations', ['doc_id' => $docId]);

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

        $docId = $request->input('doc_id') ?: $userId . '_' . $otherUserId;

        // Only fields the client is allowed to influence are accepted.
        $allowed = [
            'conversation_id', 'chat_type', 'last_msg', 'msg_count',
            'is_deleted', 'deleted_id', 'i_blocked', 'i_am_blocked', 'request_type',
        ];

        $payload = [
            'doc_id' => $docId,
            // Ownership is forced from the token, never taken from the body.
            'user_id' => $userId,
            'other_user_id' => $otherUserId,
        ];

        foreach ($allowed as $field) {
            if ($request->has($field)) {
                $payload[$field] = $request->input($field);
            }
        }

        try {
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

        if ($this->authUserId($request) === null) {
            return $this->fail('Unauthorized Access', 401);
        }

        $conversationId = (string) $request->input('conversation_id', '');
        if ($conversationId === '') {
            return $this->fail('conversation_id is required', 422);
        }

        $limit = (int) $request->input('limit', 50);
        $limit = max(1, min($limit, 100));

        $operators = [];
        if ($cursor = $request->input('cursor_after_document_id')) {
            $operators[] = ['id', 'lt', $cursor];
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

        $allowed = [
            'message_type', 'text_message', 'image_message', 'video_message',
            'audio_message', 'post_message', 'story_reply_message', 'wave_data',
            'no_delete_ids', 'i_blocked', 'i_am_blocked',
        ];

        $payload = [
            'doc_id' => $docId,
            'conversation_id' => $conversationId,
            // Sender is the authenticated user. A body value is ignored.
            'user_id' => $userId,
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

        if ($this->authUserId($request) === null) {
            return $this->fail('Unauthorized Access', 401);
        }

        $docId = (string) $request->input('doc_id', '');
        $changes = $request->input('data', []);

        if ($docId === '' || ! is_array($changes)) {
            return $this->fail('doc_id and data are required', 422);
        }

        // Never let a caller re-assign ownership through an update.
        unset($changes['user_id'], $changes['doc_id'], $changes['id']);

        try {
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

        if ($this->authUserId($request) === null) {
            return $this->fail('Unauthorized Access', 401);
        }

        $docId = (string) $request->input('doc_id', '');
        if ($docId === '') {
            return $this->fail('doc_id is required', 422);
        }

        try {
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

        try {
            if (empty($ids)) {
                $rows = $this->sb->select('app_users', [], [], '*', 100, '');
            } else {
                // PostgREST ANDs repeated filters on the same column, so a list
                // must be expressed as one `in.(a,b,c)` operator, not as
                // several `user_id=eq.x` entries.
                $clean = array_values(array_unique(array_map('intval', $ids)));
                $rows = $this->sb->select(
                    'app_users',
                    [],
                    [['user_id', 'in', '(' . implode(',', $clean) . ')']],
                    '*',
                    100,
                    ''
                );
            }

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

        $allowed = ['username', 'fullname', 'profile', 'identity', 'is_verify'];

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
