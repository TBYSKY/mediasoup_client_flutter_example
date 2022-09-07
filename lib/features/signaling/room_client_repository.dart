import 'dart:async';
import 'dart:developer';

import 'package:example/features/me/bloc/me_bloc.dart';
import 'package:example/features/media_devices/bloc/media_devices_bloc.dart';
import 'package:example/features/peers/bloc/peers_bloc.dart';
import 'package:example/features/producers/bloc/producers_bloc.dart';
import 'package:example/features/room/bloc/room_bloc.dart';
import 'package:example/features/signaling/web_socket.dart';
import 'package:example/medsoup/src/common/index.dart';
import 'package:example/medsoup/src/consumer.dart';
import 'package:example/medsoup/src/data_consumer.dart';
import 'package:example/medsoup/src/device.dart';
import 'package:example/medsoup/src/producer.dart';
import 'package:example/medsoup/src/rtp_parameters.dart';
import 'package:example/medsoup/src/scalability_modes.dart';
import 'package:example/medsoup/src/sctp_parameters.dart';
import 'package:example/medsoup/src/transport.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fluttertoast/fluttertoast.dart';

class RoomClientRepository {
  final ProducersBloc producersBloc;
  final PeersBloc peersBloc;
  final MeBloc meBloc;
  final RoomBloc roomBloc;
  final MediaDevicesBloc mediaDevicesBloc;

  final String roomId;
  final String peerId;
  final String url;
  final String displayName;

  bool _closed = false;

  WebSocket? _webSocket;
  Device? _mediasoupDevice;
  Transport? _sendTransport;
  Transport? _recvTransport;
  bool _produce = false;
  bool _consume = true;
  StreamSubscription<MediaDevicesState>? _mediaDevicesBlocSubscription;
  String? audioInputDeviceId;
  String? audioOutputDeviceId;
  String? videoInputDeviceId;

  RoomClientRepository({
    required this.producersBloc,
    required this.peersBloc,
    required this.meBloc,
    required this.roomBloc,
    required this.roomId,
    required this.peerId,
    required this.url,
    required this.displayName,
    required this.mediaDevicesBloc,
  }) {
    _mediaDevicesBlocSubscription =
        mediaDevicesBloc.stream.listen((MediaDevicesState state) async {
      if (state.selectedAudioInput != null &&
          state.selectedAudioInput?.deviceId != audioInputDeviceId) {
        await disableMic();
        enableMic();
      }

      if (state.selectedVideoInput != null &&
          state.selectedVideoInput?.deviceId != videoInputDeviceId) {
        await disableWebcam();
        enableWebcam();
      }
    });
  }

  void close() {
    if (_closed) {
      return;
    }

    _webSocket?.close();
    _sendTransport?.close();
    _recvTransport?.close();
    _mediaDevicesBlocSubscription?.cancel();
  }

  Future<void> disableMic() async {
    String micId = producersBloc.state.mic!.id;

    producersBloc.add(ProducerRemove(source: 'mic'));

    try {
      await _webSocket!.socket.request('closeProducer', {
        'producerId': micId,
      });
    } catch (error) {}
  }

  Future<void> disableWebcam() async {
    meBloc.add(MeSetWebcamInProgress(progress: true));
    String webcamId = producersBloc.state.webcam!.id;

    producersBloc.add(ProducerRemove(source: 'webcam'));

    try {
      await _webSocket!.socket.request('closeProducer', {
        'producerId': webcamId,
      });
    } catch (error) {
    } finally {
      meBloc.add(MeSetWebcamInProgress(progress: false));
    }
  }

  Future<void> muteMic() async {
    producersBloc.add(ProducerPaused(source: 'mic'));

    try {
      await _webSocket!.socket.request('pauseProducer', {
        'producerId': producersBloc.state.mic!.id,
      });
    } catch (error) {}
  }

  Future<void> unmuteMic() async {
    producersBloc.add(ProducerResumed(source: 'mic'));

    try {
      await _webSocket!.socket.request('resumeProducer', {
        'producerId': producersBloc.state.mic!.id,
      });
    } catch (error) {}
  }

  void _producerCallback(Producer producer) {
    if (producer.source == 'webcam') {
      meBloc.add(MeSetWebcamInProgress(progress: false));
    }
    producer.on('trackended', () {
      disableMic().catchError((data) {});
    });
    producersBloc.add(ProducerAdd(producer: producer));
  }

  void _consumerCallback(Consumer consumer, [dynamic accept]) {
    // ScalabilityMode scalabilityMode = ScalabilityMode.parse(
    //     consumer.rtpParameters.encodings.first.scalabilityMode);

    accept({});

    peersBloc.add(PeerAddConsumer(peerId: consumer.peerId, consumer: consumer));
  }

  //接收消息通道
  void _dataConsumerCallback(DataConsumer dataConsumer, [dynamic accept]) {
    accept({});

    dataConsumer.dataChannel.onMessage = (data) {
      print(data);
      Fluttertoast.showToast(
          msg: data.text,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    };
    // dataConsumer.on('message', (message) {
    //   switch (dataConsumer.label) {
    //     case 'chat':
    //       print(message);
    //       RTCDataChannelMessage dataChannelMessage = message["data"];

    //       dataChannelMessage.text;
    //       break;
    //     case 'bot':
    //       break;
    //     default:
    //   }
    // });
  }

  //设置当前消费者的时间层空间层
  Future<void> setConsumerPreferredLayers(consumerid, s, l) async {
    _webSocket!.setConsumerPreferredLayers(consumerid, s, l);
  }

  Future<MediaStream> createAudioStream() async {
    audioInputDeviceId = mediaDevicesBloc.state.selectedAudioInput!.deviceId;
    Map<String, dynamic> mediaConstraints = {
      'audio': {
        'optional': [
          {
            'sourceId': audioInputDeviceId,
          },
        ],
      },
    };

    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);

    return stream;
  }

  Future<MediaStream> createVideoStream({bool userScreen = false}) async {
    videoInputDeviceId = mediaDevicesBloc.state.selectedVideoInput!.deviceId;
    Map<String, dynamic> mediaConstraints = <String, dynamic>{
      'audio': userScreen ? false : true,
      'video': userScreen
          ? true
          : {
              'mandatory': {
                'width': '1280',
                // Provide your own width, height and frame rate here
                'height': '720',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [
                {'sourceId': videoInputDeviceId}
              ],
            }
    };

    MediaStream stream = userScreen
        ? await navigator.mediaDevices.getDisplayMedia(mediaConstraints)
        : await navigator.mediaDevices.getUserMedia(mediaConstraints);

    return stream;
  }

  void enableWebcam() async {
    if (meBloc.state.webcamInProgress) {
      return;
    }
    meBloc.add(MeSetWebcamInProgress(progress: true));
    if (_mediasoupDevice!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeVideo) ==
        false) {
      return;
    }
    MediaStream? videoStream;
    MediaStreamTrack? track;
    try {
      // NOTE: prefer using h264
      final videoVPVersion = kIsWeb ? 9 : 9; //更换vp8 或者 vp9
      RtpCodecCapability? codec = _mediasoupDevice!.rtpCapabilities.codecs
          .firstWhere(
              (RtpCodecCapability c) => c.mimeType.toLowerCase() == 'video/vp9',
              orElse: () =>
                  throw 'desired vp$videoVPVersion codec+configuration is not supported');
      videoStream = await createVideoStream();
      track = videoStream.getVideoTracks().first;
      meBloc.add(MeSetWebcamInProgress(progress: true));
      _sendTransport!.produce(
        stream: videoStream,
        track: track,
        codecOptions: ProducerCodecOptions(
          videoGoogleStartBitrate: 1000,
          videoGoogleMinBitrate: 1000,
        ),
        encodings: kIsWeb
            ? [
                RtpEncodingParameters(
                    scalabilityMode: 'S3T3_KEY', scaleResolutionDownBy: 1.0),
              ]
            : [
                // RtpEncodingParameters(
                //   //h264 S1T1 vp9  S3T3_KEY
                //   // scalabilityMode: 'S1T1',
                //   rid: 'h',
                //   scaleResolutionDownBy: 1,
                //   maxBitrate: 5000000,
                //   dtx: true,
                //   active: true,
                // ),
                // RtpEncodingParameters(
                //   scaleResolutionDownBy: 1,
                //   // maxBitrate: 1000000,
                //   minBitrate: 756000,

                //   dtx: false,
                //   active: true,
                // ),
                // RtpEncodingParameters(
                //   //h264 S1T1 vp9  S3T3_KEY
                //   // scalabilityMode: 'S1T1',

                //   scaleResolutionDownBy: 2,

                //   maxBitrate: 756000,
                //   minBitrate: 477557,
                //   dtx: false,
                //   active: true,
                // ),

                // RtpEncodingParameters(
                //   //h264 S1T1 vp9  S3T3_KEY
                //   scalabilityMode: 'S1T1_KEY',
                //   rid: 'l',
                //   scaleResolutionDownBy: 4,
                //   maxBitrate: 100000,
                //   active: true,
                // ),

                // VP9 SVC
                RtpEncodingParameters(
                  scalabilityMode: 'S2T3', //h264 S1T1 vp9  S3T3_KEY
                  // scaleResolutionDownBy: 1.0,
                  dtx: true,
                  // priority: Priority.High,
                  active: true,
                ),
                //联播
                // RtpEncodingParameters(
                //   scalabilityMode: 'S3T3_KEY', //h264 S1T1 vp9  S3T3_KEY
                //   dtx: true,
                //   // priority: Priority.High,
                //   maxBitrate: 900000,
                //   active: true,
                // ),

                // RtpEncodingParameters(
                //   scalabilityMode: 'S1T1', //h264 S1T1 vp9  S3T3_KEY
                //   // scaleResolutionDownBy: 1.0,
                //   // dtx: true,
                //   // priority: Priority.High,
                //   maxBitrate: 15000,
                //   active: true,
                // ),
                // RtpEncodingParameters(
                //     // scalabilityMode: 'S3T3_KEY', //h264 S1T1 vp9  S3T3_KEY
                //     scaleResolutionDownBy: 2.0,
                //     // dtx: true,
                //     // priority: Priority.High,
                //     active: true,
                //     maxBitrate: 300000,
                //     rid: 'q'),
              ],
        appData: {
          'source': 'webcam',
        },
        source: 'webcam',
        codec: codec,
      );
    } catch (error) {
      if (videoStream != null) {
        await videoStream.dispose();
      }
    }
  }

  void enableMic() async {
    if (_mediasoupDevice!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeAudio) ==
        false) {
      return;
    }

    MediaStream? audioStream;
    MediaStreamTrack? track;
    try {
      audioStream = await createAudioStream();
      track = audioStream.getAudioTracks().first;
      _sendTransport!.produce(
        track: track,
        codecOptions: ProducerCodecOptions(opusStereo: 1, opusDtx: 1),
        stream: audioStream,
        appData: {
          'source': 'mic',
        },
        source: 'mic',
      );
    } catch (error) {
      if (audioStream != null) {
        await audioStream.dispose();
      }
    }
  }

  Future<void> _joinRoom() async {
    try {
      _mediasoupDevice = Device();

      dynamic routerRtpCapabilities =
          await _webSocket!.socket.request('getRouterRtpCapabilities', {});

      print(routerRtpCapabilities);

      final rtpCapabilities = RtpCapabilities.fromMap(routerRtpCapabilities);
      rtpCapabilities.headerExtensions
          .removeWhere((he) => he.uri == 'urn:3gpp:video-orientation');
      await _mediasoupDevice!.load(routerRtpCapabilities: rtpCapabilities);

      if (_mediasoupDevice!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeAudio) ==
              true ||
          _mediasoupDevice!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeVideo) ==
              true) {
        _produce = true;
      }

      if (_produce) {
        Map transportInfo =
            await _webSocket!.socket.request('createWebRtcTransport', {
          'forceTcp': false,
          'producing': true,
          'consuming': false,
          'sctpCapabilities': _mediasoupDevice!.sctpCapabilities.toMap(),
        });

        _sendTransport = _mediasoupDevice!.createSendTransportFromMap(
          transportInfo,
          producerCallback: _producerCallback,
        );

        _sendTransport!.on('connect', (Map data) {
          _webSocket!.socket
              .request('connectWebRtcTransport', {
                'transportId': _sendTransport!.id,
                'dtlsParameters': data['dtlsParameters'].toMap(),
              })
              .then(data['callback'])
              .catchError(data['errback']);
        });

        _sendTransport!.on('produce', (Map data) async {
          try {
            Map response = await _webSocket!.socket.request(
              'produce',
              {
                'transportId': _sendTransport!.id,
                'kind': data['kind'],
                'rtpParameters': data['rtpParameters'].toMap(),
                if (data['appData'] != null)
                  'appData': Map<String, dynamic>.from(data['appData'])
              },
            );

            data['callback'](response['id']);
          } catch (error) {
            data['errback'](error);
          }
        });

        _sendTransport!.on('producedata', (data) async {
          try {
            Map response = await _webSocket!.socket.request('produceData', {
              'transportId': _sendTransport!.id,
              'sctpStreamParameters': data['sctpStreamParameters'].toMap(),
              'label': data['label'],
              'protocol': data['protocol'],
              'appData': data['appData'],
            });

            data['callback'](response['id']);
          } catch (error) {
            data['errback'](error);
          }
        });
      }

      if (_consume) {
        Map transportInfo = await _webSocket!.socket.request(
          'createWebRtcTransport',
          {
            'forceTcp': false,
            'producing': false,
            'consuming': true,
            'sctpCapabilities': _mediasoupDevice!.sctpCapabilities.toMap(),
          },
        );

        _recvTransport = _mediasoupDevice!.createRecvTransportFromMap(
          transportInfo,
          consumerCallback: _consumerCallback,
          dataConsumerCallback: _dataConsumerCallback,
        );

        _recvTransport!.on(
          'connect',
          (data) {
            _webSocket!.socket
                .request(
                  'connectWebRtcTransport',
                  {
                    'transportId': _recvTransport!.id,
                    'dtlsParameters': data['dtlsParameters'].toMap(),
                  },
                )
                .then(data['callback'])
                .catchError(data['errback']);
          },
        );
      }

      Map response = await _webSocket!.socket.request('join', {
        'displayName': displayName,
        'device': {
          'name': "Flutter",
          'flag': 'flutter',
          'version': '0.9.2',
        },
        'rtpCapabilities': _mediasoupDevice!.rtpCapabilities.toMap(),
        'sctpCapabilities': _mediasoupDevice!.sctpCapabilities.toMap(),
      });

      response['peers'].forEach((value) {
        peersBloc.add(PeerAdd(newPeer: value));
      });

      if (_produce) {
        enableMic();
        enableWebcam();

        _sendTransport!.on('connectionstatechange', (connectionState) {
          if (connectionState == 'connected') {
            // enableChatDataProducer();
            // enableBotDataProducer();
          }
        });
      }
    } catch (error) {
      print(error);
      close();
    }
  }

  void join() {
    _webSocket = WebSocket(
      peerId: peerId,
      roomId: roomId,
      url: url,
    );

    _webSocket!.onOpen = _joinRoom;
    _webSocket!.onFail = () {
      print('WebSocket connection failed');
    };
    _webSocket!.onDisconnected = () {
      if (_sendTransport != null) {
        _sendTransport!.close();
        _sendTransport = null;
      }
      if (_recvTransport != null) {
        _recvTransport!.close();
        _recvTransport = null;
      }
    };
    _webSocket!.onClose = () {
      if (_closed) return;

      close();
    };

    _webSocket!.onRequest = (request, accept, reject) async {
      switch (request['method']) {
        case 'newConsumer':
          {
            if (!_consume) {
              reject(403, 'I do not want to consume');
              break;
            }
            try {
              _recvTransport!.consume(
                id: request['data']['id'],
                producerId: request['data']['producerId'],
                kind: RTCRtpMediaTypeExtension.fromString(
                    request['data']['kind']),
                rtpParameters:
                    RtpParameters.fromMap(request['data']['rtpParameters']),
                appData: Map<String, dynamic>.from(request['data']['appData']),
                peerId: request['data']['peerId'],
                accept: accept,
              );
            } catch (error) {
              print('newConsumer request failed: $error');
              throw (error);
            }
            break;
          }
        case 'newDataConsumer':
          print('接受到消息 newDataConsumer');
          _recvTransport!.consumeData(
              id: request['data']['id'],
              dataProducerId: request['data']['dataProducerId'],
              sctpStreamParameters: SctpStreamParameters.fromMap(
                  request['data']['sctpStreamParameters']),
              label: request['data']['label'],
              appData: request['data']['appData'],
              peerId: request['data']['peerId'],
              accept: accept);
          break;
        default:
          break;
      }
    };

    _webSocket!.onNotification = (notification) async {
      print("----------------通知   ${notification['method']}");
      switch (notification['method']) {
        //TODO: todo;
        case 'producerScore': //生产者平分变化
          {
            String consumerId = notification['data']['producerId'];
            List score = notification['data']['score'];
            print("----------------测试   producerScore : ${score.toString()}");
            break;
          }
        case 'consumerScore': //消费者平分变化
          {
            String consumerId = notification['data']['consumerId'];
            Map score = notification['data']['score'];
            print("----------------测试   consumerScore : ${score.toString()}");
            break;
          }
        case 'consumerClosed':
          {
            String consumerId = notification['data']['consumerId'];
            peersBloc.add(PeerRemoveConsumer(consumerId: consumerId));

            break;
          }
        case 'consumerPaused':
          {
            String consumerId = notification['data']['consumerId'];
            peersBloc.add(PeerPausedConsumer(consumerId: consumerId));
            break;
          }

        case 'consumerResumed':
          {
            String consumerId = notification['data']['consumerId'];
            peersBloc.add(PeerResumedConsumer(consumerId: consumerId));
            break;
          }

        case 'newPeer':
          {
            final Map<String, dynamic> newPeer =
                Map<String, dynamic>.from(notification['data']);
            peersBloc.add(PeerAdd(newPeer: newPeer));
            break;
          }

        case 'peerClosed':
          {
            String peerId = notification['data']['peerId'];
            peersBloc.add(PeerRemove(peerId: peerId));
            break;
          }
        case 'consumerLayersChanged': //消费者状态发生改变
          {
            String consumerId = notification['data']["consumerId"];
            int spatialLayer = notification['data']["spatialLayer"];
            int temporalLayer = notification['data']["temporalLayer"];
            log("consumerLayersChanged---------consumerId：$consumerId -----spatialLayer : $spatialLayer -----temporalLayer : $temporalLayer");
            break;
          }
        case 'peerDisplayNameChanged': //名字改变
          {
            String peerId = notification['data']["peerId"];
            String displayName = notification['data']["displayName"];
            String oldDisplayName = notification['data']["oldDisplayName"];
            log("peerDisplayNameChanged---------consumerId：$peerId -----displayName : $displayName -----oldDisplayName : $oldDisplayName");
            break;
          }

        default:
          break;
      }
    };
  }
}
