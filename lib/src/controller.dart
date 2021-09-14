import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ivs_player/src/types.dart';

class IvsController {
  IvsController({required this.id})
      : _channel = MethodChannel("ivs_player:$id"),
        _eventChannel = EventChannel("ivs_event:$id") {
    eventStream.drain();
  }

  final int id;
  final MethodChannel _channel;
  final EventChannel _eventChannel;

  Stream get eventStream {
    final transformer =
        StreamTransformer.fromHandlers(handleData: _transformData);
    return _eventChannel.receiveBroadcastStream().transform(transformer);
  }

  final state = ValueNotifier<PlayerState>(PlayerState.idle);
  final position = ValueNotifier<Duration>(Duration.zero);
  final duration = ValueNotifier<Duration>(Duration.zero);
  final quality = ValueNotifier<Quality>(Quality());

  Future<void> load(String src) {
    return _channel.invokeMethod('load', {"src": src});
  }

  Future<void> play() {
    return _channel.invokeMethod('play');
  }

  Future<void> pause() {
    return _channel.invokeMethod('pause');
  }

  Future<int> seekTo(int millisecond) async {
    return await _channel.invokeMethod('seek_to', millisecond);
  }

  Future<int> getDuration() async {
    return await _channel.invokeMethod('get_duration');
  }

  void _transformData(data, EventSink sink) {
    print(data);
    final type = data?['type'];
    switch (type) {
      case 'duration_changed':
        duration.value = Duration(milliseconds: data['duration']);
        break;
      case 'fail':
        sink.add(Failed(data['error']));
        break;
      case 'state_changed':
        state.value = _stringToState(data['state']);
        break;
      case 'sought_to':
        position.value = Duration(milliseconds: data['position']);
        break;
      case 'rebuffer':
        sink.add(Rebuffer());
        break;
      case 'network_became_unavailable':
        sink.add(NetworkBecameUnavailable());
        break;
      case 'quality_changed':
        quality.value = Quality(
          bitrate: data['bitrate'],
          width: data['width'],
          height: data['height'],
          frameRate: data['frame_rate'],
          name: data['name'],
          codecs: data['codecs'],
        );
        break;
      default:
        sink.addError('Unknown event type: $type');
    }
  }

  PlayerState _stringToState(String code) {
    final value = PlayerState.values
        .firstWhere((element) => describeEnum(element) == code);
    return value;
  }
}