import 'dart:convert';
import 'package:hetu_script/hetu_script.dart';
import './externals.dart';
import './helpers/crypto.dart' as helpers;
import './helpers/fetch.dart' as helpers;
import './helpers/future.dart' as helpers;
import './helpers/fuzzy.dart' as helpers;
import './helpers/html.dart' as helpers;
import './helpers/list.dart' as helpers;
import './helpers/map.dart' as helpers;
import './helpers/regexp.dart' as helpers;
import './helpers/throw_err.dart' as helpers;
import '../utils/http.dart';

export './externals.dart';

Future<Hetu> createHetu() async {
  final Hetu hetu = Hetu();

  await hetu.init(
    externalClasses: <HTExternalClass>[
      helpers.HtmlElementClassBinding(),
      helpers.RegExpMatchResultClassBinding(),
    ],
    externalFunctions: <String, Function>{
      'decryptCryptoJsAES': helpers.decryptCryptoJsAES,
      'fetch': helpers.fetch,
      'createFuzzy': helpers.createFuzzy,
      'parseHtml': helpers.parseHtml,
      'jsonEncode': (final dynamic data) => jsonEncode(data),
      'jsonDecode': (final String data) => jsonDecode(data),
      'httpUserAgent': () => HttpUtils.userAgent,
      'regexMatch': helpers.regexMatch,
      'regexMatchAll': helpers.regexMatchAll,
      'mapList': helpers.mapList,
      'filterList': helpers.filterList,
      'findList': helpers.findList,
      'regexReplaceAll': helpers.regexReplaceAll,
      'regexReplaceFirst': helpers.regexReplaceFirst,
      'resolveFuture': helpers.resolveFuture,
      'throwError': helpers.throwError,
      'ensureURL': HttpUtils.ensureURL,
      'eachList': helpers.eachList,
      'eachMap': helpers.eachMap,
      'mergeMap': helpers.mergeMap,
      'mergeList': helpers.mergeList,
      'rangeList': helpers.rangeList,
      'resolveFutureAll': helpers.resolveFutureAll,
      'flattenList': helpers.flattenList,
      'deepFlattenList': helpers.deepFlattenList,
    },
  ).onError<HTError>((final HTError error, final StackTrace _) async {
    if (error.line != null) {
      error.line =
          error.line! - RegExp('\n').allMatches(hetuExternals).length - 1;
    }

    throw error;
  });

  return hetu;
}

void modifyHTError(final HTError err) {}
