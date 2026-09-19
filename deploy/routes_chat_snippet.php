<?php

/*
|--------------------------------------------------------------------------
| Chat routes (Supabase proxy)
|--------------------------------------------------------------------------
|
| Append this block to routes/api.php, INSIDE the existing
| Route::middleware('checkHeader')->group(function () { ... }) block,
| because createMessage/upsertConversation/upsertAppUser write data.
|
| The route names mirror the ChatRepository methods in the Flutter app, so
| ChatApiRepository (the client replacement) maps 1:1 onto them.
|
| Every route is protected by `authorizeUser`, which resolves the real user
| behind the token and records it as `auth_user_id`. ChatController reads the
| acting user from THERE, never from the request body.
*/

use App\Http\Controllers\ChatController;

Route::prefix('chat')->group(function () {

    // ---- Conversations -------------------------------------------------
    Route::post('fetchMyConversations', [ChatController::class, 'fetchMyConversations'])->middleware('authorizeUser');
    Route::post('fetchConversation', [ChatController::class, 'fetchConversation'])->middleware('authorizeUser');
    Route::post('upsertConversation', [ChatController::class, 'upsertConversation'])->middleware('authorizeUser');

    // ---- Messages ------------------------------------------------------
    Route::post('fetchMessages', [ChatController::class, 'fetchMessages'])->middleware('authorizeUser');
    Route::post('sendMessage', [ChatController::class, 'sendMessage'])->middleware('authorizeUser');
    Route::post('updateMessage', [ChatController::class, 'updateMessage'])->middleware('authorizeUser');
    Route::post('deleteMessage', [ChatController::class, 'deleteMessage'])->middleware('authorizeUser');

    // ---- App users (chat profile mirror) --------------------------------
    Route::post('fetchAppUsers', [ChatController::class, 'fetchAppUsers'])->middleware('authorizeUser');
    Route::post('upsertAppUser', [ChatController::class, 'upsertAppUser'])->middleware('authorizeUser');
    Route::post('deleteAppUser', [ChatController::class, 'deleteAppUser'])->middleware('authorizeUser');
});
