import 'dart:async';
import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';

// class DataExample {
//   final String str;
//   final int num;

//   DataExample({
//     required this.str,
//     required this.num,
//   });
// }

// class JsBridgeExample {
//   JsBridgeExample() {
//     example();
//   }

//   _print(message) {
//     final d = DateTime.now();
//     final ts = '${d.hour}:${d.minute}:${d.second}:${d.millisecond}';
//     print('[$ts] $message');
//   }

//   example() async {
//     const exampleJs = '''
//     DartBridge.setHandler('TESTJS', async (args) => {
//       await new Promise(resolve => setTimeout(resolve, 2000));
//       return `JS code got args.name=\${args.name} and args.obj.num=\${args.obj.num}`;
//     });

//     const print = (message) => DartBridge.sendMessage('PRINT', message);

//     setTimeout(async () => {
//       print('Start async call to Dart');
//       const asyncCallToDartResult = await DartBridge.sendMessage('TESTDART', { some: 'object' });
//       print(`asyncCallToDartResult=\${asyncCallToDartResult}`);
//     }, 4000);
//     ''';

//     final jsRuntime = getJavascriptRuntime();
//     final jsBridge = JsBridge(jsRuntime: jsRuntime, toEncodable: _toEncodable);
//     jsRuntime.evaluate(exampleJs);

//     jsBridge.setHandler('PRINT', (message) async {
//       _print('[JS] $message');
//     });

//     _print('Start async call to JS');
//     final asyncCallToJsResult = await jsBridge.sendMessage('TESTJS',
//         {'name': 'value', 'obj': DataExample(str: 'some string', num: 54321)});
//     _print('asyncCallToJsResult=$asyncCallToJsResult');

//     jsBridge.setHandler('TESTDART', (message) async {
//       await Future.delayed(const Duration(seconds: 2));
//       return 'Dart code got $message';
//     });
//   }

//   Object? _toEncodable(Object? value) {
//     if (value is DataExample) {
//       return {
//         'num': value.num,
//         'str': value.str,
//       };
//     }
//     return null;
//   }
// }

// flutter: [11:47:39:524] Start async call to JS
// flutter: [11:47:41:540] asyncCallToJsResult=JS code got args.name=value and args.obj.num=54321
// flutter: [11:47:43:525] [JS] Start async call to Dart
// flutter: [11:47:45:531] [JS] asyncCallToDartResult=Dart code got {some: object}

const DART_BRIDGE_MESSAGE_NAME = 'DART_BRIDGE_MESSAGE_NAME';

class JsBridge {
  final JavascriptRuntime jsRuntime;
  int _messageCounter = 0;
  static final Map<int, Completer> _pendingRequests = {};
  final Object? Function(Object? value)? toEncodable;
  static final Map<String, Future<dynamic> Function(dynamic message)>
      _handlers = {};
  JsBridge({
    required this.jsRuntime,
    this.toEncodable,
  }) {
    final bridgeScriptEvalResult = jsRuntime.evaluate(JS_BRIDGE_JS);
    if (bridgeScriptEvalResult.isError) {
      print('Error eval bridge script');
    }
    final windowEvalResult =
        jsRuntime.evaluate('var window = global = globalThis;');
    if (windowEvalResult.isError) {
      print('Error eval window script');
    }
    jsRuntime.onMessage(DART_BRIDGE_MESSAGE_NAME, (message) {
      _onMessage(message);
    });
  }

  _onMessage(dynamic message) async {
    if (message['isRequest']) {
      final handler = _handlers[message['name']];
      if (handler == null) {
        print('Error: no handlers for message $message');
      } else {
        final result = await handler(message['args']);
        final jsResult = jsRuntime.evaluate(
            'onMessageFromDart(false, ${message['callId']}, "${message['name']}",${jsonEncode(result, toEncodable: toEncodable)})');
        if (jsResult.isError) {
          print('Error sending message to JS: $jsResult');
        }
      }
    } else {
      final completer = _pendingRequests.remove(message['callId']);
      if (completer == null) {
        print('Error: no completer for response for message $message');
      } else {
        completer.complete(message['result']);
      }
    }
  }

  sendMessage(String name, dynamic message) async {
    if (_messageCounter > 999999999) {
      _messageCounter = 0;
    }
    _messageCounter += 1;
    final completer = Completer();
    _pendingRequests[_messageCounter] = completer;
    final jsResult = jsRuntime.evaluate(
        'window.onMessageFromDart(true, $_messageCounter, "$name",${jsonEncode(message, toEncodable: toEncodable)})');
    if (jsResult.isError) {
      print('Error sending message to JS: $jsResult');
    }

    return completer.future;
  }

  // final _handlers = {};

  setHandler(String name, Future<dynamic> Function(dynamic message) handler) {
    _handlers[name] = handler;
  }
}

const JS_BRIDGE_JS = '''
globalThis.DartBridge = (() => {
    let callId = 0;
    const DART_BRIDGE_MESSAGE_NAME = '$DART_BRIDGE_MESSAGE_NAME';
    globalThis.onMessageFromDart = async (isRequest, callId, name, args) => {
        if (isRequest) {
            if (handlers[name]) {
                sendMessage(DART_BRIDGE_MESSAGE_NAME, JSON.stringify({
                    isRequest: false,
                    callId,
                    name,
                    result: await handlers[name](args),
                }));
            }
        }
        else {
            const pendingResolve = pendingRequests[callId];
            delete pendingRequests[callId];
            if (pendingResolve) {
                pendingResolve(args);
            }
        }
        return null;
    };
    const handlers = {};
    const pendingRequests = {};
    return {
        sendMessage: async (name, args) => {
            if (callId > 999999999) {
                callId = 0;
            }
            callId += 1;
            sendMessage(DART_BRIDGE_MESSAGE_NAME, JSON.stringify({
                isRequest: true,
                callId,
                name,
                args,
            }),call=((res)=>{}));
            return new Promise((resolve) => {
                pendingRequests[callId] = resolve;
                call(resolve)
            });
        },
        setHandler: (name, handler) => {
            handlers[name] = handler;
        },
        resolveRequest: (callId, result) => {
            sendMessage(DART_BRIDGE_MESSAGE_NAME, JSON.stringify({
                isRequest: false,
                callId,
                result,
            }));
        },
    };
})();
global = globalThis;
''';
