import 'dart:convert';
import 'dart:io' show RawZLibFilter, ZLibCodec;
import 'dart:typed_data';

import 'package:pebble_routines/core/database/routine_step.dart';

/// A routine carried inside an "Add to Pebble" link.
///
/// The whole routine travels in the link itself, after the `#`, so there is
/// no server, nothing stored and no account needed. Browsers never send the
/// part after `#` to a server, so the steps stay out of web logs too.
///
/// ```
/// https://pebbleroutines.com/r#<data>     (the shared link)
/// pebbleroutines://r#<data>               (the web page's "Open in Pebble")
/// ```
///
/// `<data>` is `z` plus base64url of the raw-deflated JSON
/// `{"v":1,"t":"title","s":[...]}`, which keeps links about 40% shorter.
/// Links from before compression (plain base64url JSON) still open. Each
/// step is `{"c":"label","p":1,"k":1}` (a check, with photo and skip flags),
/// `{"i":"note"}` or `{"w":seconds}` (a timer). `web/r/index.html` reads the
/// same format, so change both together.
class SharedRoutine {
  const SharedRoutine({required this.title, required this.steps});

  final String title;
  final List<RoutineStep> steps;

  static const int version = 1;
  static const String webHost = 'pebbleroutines.com';
  static const String webPath = '/r';
  static const String appScheme = 'pebbleroutines';

  /// Generous limits, so a hand-made link can't flood the screen.
  static const int maxTitleChars = 120;
  static const int maxSteps = 60;
  static const int maxTimerSeconds = 24 * 60 * 60;

  /// Marks compressed data. Plain base64url JSON always starts with `e`.
  static const String compressedPrefix = 'z';
  static final ZLibCodec _deflate = ZLibCodec(raw: true, level: 9);

  /// More than any real routine needs, so a crafted link can't expand into
  /// megabytes on the phone.
  static const int maxJsonBytes = 128 * 1024;

  static List<int>? _inflate(List<int> input, int maxBytes) {
    final filter = RawZLibFilter.inflateFilter(raw: true);
    filter.process(input, 0, input.length);
    final out = BytesBuilder(copy: false);
    for (
      var chunk = filter.processed(end: true);
      chunk != null;
      chunk = filter.processed(end: true)
    ) {
      out.add(chunk);
      if (out.length > maxBytes) return null;
    }
    return out.takeBytes();
  }

  /// The link to share. Guidance audio and photo prompts stay on this phone.
  Uri toLink() {
    final payload = <String, Object?>{
      'v': version,
      't': title.trim(),
      's': [for (final step in steps) _encodeStep(step)],
    };
    final compressed = _deflate.encode(utf8.encode(jsonEncode(payload)));
    final data =
        '$compressedPrefix${base64Url.encode(compressed).replaceAll('=', '')}';
    return Uri(scheme: 'https', host: webHost, path: webPath, fragment: data);
  }

  /// The routine in a link Pebble was opened with, or null when the link is
  /// not an "Add to Pebble" link or can't be read.
  static SharedRoutine? fromLink(Uri uri) {
    final isWeb =
        uri.scheme == 'https' &&
        (uri.host == webHost || uri.host == 'www.$webHost') &&
        (uri.path == webPath || uri.path == '$webPath/');
    final isApp = uri.scheme == appScheme && uri.host == 'r';
    if (!isWeb && !isApp) return null;
    return fromData(uri.fragment);
  }

  /// Reads the `<data>` part of a link. Null when it can't be read.
  static SharedRoutine? fromData(String data) {
    if (data.isEmpty || data.length > 64 * 1024) return null;
    try {
      final isCompressed = data.startsWith(compressedPrefix);
      final body = isCompressed ? data.substring(1) : data;
      final padded = body.padRight((body.length + 3) ~/ 4 * 4, '=');
      List<int>? bytes = base64Url.decode(padded);
      if (isCompressed) bytes = _inflate(bytes, maxJsonBytes);
      if (bytes == null || bytes.length > maxJsonBytes) return null;
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['v'] != version) return null;
      final title = _clean(decoded['t'], maxTitleChars);
      final rawSteps = decoded['s'];
      if (rawSteps is! List) return null;
      final steps = <RoutineStep>[];
      for (final raw in rawSteps.take(maxSteps)) {
        final step = raw is Map ? _decodeStep(raw) : null;
        if (step != null) steps.add(step);
      }
      if (steps.whereType<CheckStep>().isEmpty) return null;
      return SharedRoutine(
        title: title.isEmpty ? 'Shared routine' : title,
        steps: steps,
      );
    } catch (_) {
      return null;
    }
  }

  /// The `<data>` part of this routine's link.
  String get data => toLink().fragment;

  static Map<String, Object?> _encodeStep(RoutineStep step) {
    return switch (step) {
      CheckStep(:final label, :final requiresPhoto, :final allowSkip) => {
        'c': label.trim(),
        if (requiresPhoto) 'p': 1,
        if (allowSkip) 'k': 1,
      },
      InfoStep(:final message) => {'i': message.trim()},
      TimerStep(:final duration) => {'w': duration},
      _ => const {},
    };
  }

  static RoutineStep? _decodeStep(Map raw) {
    if (raw['c'] is String) {
      final label = _clean(raw['c'], maxStepDescriptionChars);
      if (label.isEmpty) return null;
      return RoutineStep.check(
        label: label,
        requiresPhoto: raw['p'] == 1,
        allowSkip: raw['k'] == 1,
      );
    }
    if (raw['i'] is String) {
      final message = _clean(raw['i'], maxStepDescriptionChars);
      return message.isEmpty ? null : RoutineStep.info(message: message);
    }
    final seconds = raw['w'];
    if (seconds is int && seconds > 0 && seconds <= maxTimerSeconds) {
      return RoutineStep.timer(duration: seconds);
    }
    return null;
  }

  /// Trims, drops control characters and caps the length.
  static String _clean(Object? value, int maxChars) {
    if (value is! String) return '';
    final text = value
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length <= maxChars ? text : text.substring(0, maxChars).trim();
  }
}
