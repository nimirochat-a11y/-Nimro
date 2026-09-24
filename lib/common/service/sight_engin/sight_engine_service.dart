import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_native_video_trimmer/flutter_native_video_trimmer.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/sight_engine/sight_engine_media_model.dart';
import 'package:nimiro/model/sight_engine/text_moderation_model.dart';
import 'package:nimiro/utilities/app_res.dart';

class SightEngineService {
  static var shared = SightEngineService();

  Future<void> checkImagesInSightEngine({
    required List<XFile> xFiles,
    required Function() completion,
  }) async {
    if (SessionManager.instance.getSettings()?.isContentModeration == 0) {
      completion();
      return;
    }
    BaseController.share.showLoader();
    var request = http.MultipartRequest('POST',
        Uri.parse('https://api.sightengine.com/1.0/check-workflow.json'));

    request.fields['workflow'] =
        SessionManager.instance.getSettings()?.sightEngineImageWorkflowId ?? '';
    request.fields['api_user'] =
        SessionManager.instance.getSettings()?.sightEngineApiUser ?? '';
    request.fields['api_secret'] =
        SessionManager.instance.getSettings()?.sightEngineApiSecret ?? '';

    for (XFile xFile in xFiles) {
      File file = File(xFile.path);
      request.files.add(
        http.MultipartFile(
          'media',
          file.readAsBytes().asStream(),
          file.lengthSync(),
          filename: file.path.split("/").last,
        ),
      );
    }

    try {
      var response =
          await request.send().timeout(const Duration(seconds: 30));
      var respStr = await response.stream
          .bytesToString()
          .timeout(const Duration(seconds: 30));
      SightEngineMediaModel sightEngineMediaModel =
          SightEngineMediaModel.fromJson(jsonDecode(respStr));

      if (sightEngineMediaModel.error != null) {
        // Moderation API error (bad credentials / outage): fail open instead
        // of leaving the app stuck on a loader.
        Loggers.error(
            'SightEngine image moderation error: ${sightEngineMediaModel.error?.message}');
        BaseController.share.stopLoader();
        completion();
        return;
      }

      var result = sightEngineMediaModel.summary?.action ?? '';

      BaseController.share.stopLoader();
      if (result == 'accept') {
        completion(); // All images accepted
      } else if (result == 'reject') {
        var summaryDescription = sightEngineMediaModel.summary?.rejectReason
                ?.map((e) => e.text ?? '')
                .join(', ') ??
            '';
        BaseController.share.showSnackBar(
            '${LKey.mediaRejectedAndContainsSuchThings.tr} $summaryDescription');
      }
    } catch (e) {
      // Network failure / timeout: fail open, never leave the UI hanging.
      Loggers.error('SightEngine image moderation failed: $e');
      BaseController.share.stopLoader();
      completion();
    }
  }

  Future<void> checkVideoInSightEngine({required XFile xFile,
    required int duration,
    required Function() completion}) async {
    if (SessionManager.instance.getSettings()?.isContentModeration == 0) {
      completion();
      return;
    }

    File file = File(xFile.path);
    BaseController.share.showLoader();
    if (duration > AppRes.sightEngineCropSec) {
      final videoTrimmer = VideoTrimmer();
      try {
        await videoTrimmer.loadVideo(file.path);
      } catch (e) {
        Loggers.error(e);
      }
      final trimmedPath = await videoTrimmer.trimVideo(
        startTimeMs: 0,
        endTimeMs: AppRes.sightEngineCropSec * 1000,
        includeAudio: false,
      );
      file = File(trimmedPath ?? '');
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(
          'https://api.sightengine.com/1.0/video/check-workflow-sync.json'),
    );
    request.fields['workflow'] =
        SessionManager.instance.getSettings()?.sightEngineVideoWorkflowId ?? '';
    request.fields['api_user'] =
        SessionManager.instance.getSettings()?.sightEngineApiUser ?? '';
    request.fields['api_secret'] =
        SessionManager.instance.getSettings()?.sightEngineApiSecret ?? '';

    request.files.add(
      http.MultipartFile(
          'media', file.readAsBytes().asStream(), file.lengthSync(),
          filename: file.path.split("/").last),
    );

    try {
      var response =
          await request.send().timeout(const Duration(seconds: 30));
      var respStr = await response.stream
          .bytesToString()
          .timeout(const Duration(seconds: 30));
      SightEngineMediaModel sightEngineMediaModel =
          SightEngineMediaModel.fromJson(jsonDecode(respStr));
      if (sightEngineMediaModel.error != null) {
        Loggers.error(
            'SightEngine video moderation error: ${sightEngineMediaModel.error?.message}');
        BaseController.share.stopLoader();
        completion();
        return;
      }
      var result = sightEngineMediaModel.summary?.action ?? '';
      BaseController.share.stopLoader();
      if (result == 'accept') {
        completion();
      } else if (result == 'reject') {
        var summaryDescription = sightEngineMediaModel.summary?.rejectReason
                ?.map((e) => e.text ?? '')
                .join(', ') ??
            '';
        BaseController.share.showSnackBar(
            '${LKey.mediaRejectedAndContainsSuchThings.tr} $summaryDescription');
      }
    } catch (e) {
      Loggers.error('SightEngine video moderation failed: $e');
      BaseController.share.stopLoader();
      completion();
    }
  }

  Future<void> chooseTextModeration(
      {required String text, required Function() completion}) async {
    if (SessionManager.instance.getSettings()?.isContentModeration == 0) {
      completion();
      return;
    }
    if (text.isEmpty) {
      completion();
      return;
    }
    BaseController.share.showLoader();
    var request = http.MultipartRequest(
        'POST', Uri.parse('https://api.sightengine.com/1.0/text/check.json'));
    request.fields.addAll({
      'text': text,
      'lang': 'en,zh,da,nl,fi,fr,de,it,no,pl,pt,es,sv,tl,tr',
      'categories': 'profanity',
      'mode': 'rules',
      'api_user':
          SessionManager.instance.getSettings()?.sightEngineApiUser ?? '',
      'api_secret':
          SessionManager.instance.getSettings()?.sightEngineApiSecret ?? '',
    });

    try {
      http.StreamedResponse response = await request
          .send()
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        var respStr = await response.stream
            .bytesToString()
            .timeout(const Duration(seconds: 30));
        TextModerationModel textModerationModel =
            TextModerationModel.fromJson(jsonDecode(respStr));
        List<Matches> matches = textModerationModel.profanity?.matches ?? [];
        if (textModerationModel.error != null) {
          Loggers.error(
              'SightEngine text moderation error: ${textModerationModel.error?.message}');
          BaseController.share.stopLoader();
          completion();
          return;
        }
        List<String> words = [];

        for (var element in matches) {
          if (element.intensity == 'high' || element.intensity == 'medium') {
            words.add(element.match ?? '');
          }
        }

        BaseController.share.stopLoader();
        if (words.isEmpty) {
          completion();
        } else {
          log('${LKey.textRejectedAndContainsSuchThings.tr} ${words.join(', ')}');
          BaseController.share.showSnackBar(
              '${LKey.textRejectedAndContainsSuchThings.tr} ${words.join(', ')}');
        }
      } else {
        // Non-200 from moderation API: fail open instead of hanging.
        Loggers.error(
            'SightEngine text moderation HTTP ${response.statusCode}');
        BaseController.share.stopLoader();
        completion();
      }
    } catch (e) {
      Loggers.error('SightEngine text moderation failed: $e');
      BaseController.share.stopLoader();
      completion();
    }
  }
}
