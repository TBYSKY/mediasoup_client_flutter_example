/*
 * @Author: Beoyan
 * @Date: 2022-08-12 15:14:44
 * @LastEditTime: 2022-09-06 16:00:15
 * @LastEditors: Beoyan
 * @Description: 
 */
import 'package:protoo_client/protoo_client.dart' as ProtooClient;

class WebSocket {
  final String peerId;
  final String roomId;
  final String url;
  late ProtooClient.Peer _protoo;
  Function()? onOpen;
  Function()? onFail;
  Function()? onDisconnected;
  Function()? onClose;
  Function(dynamic request, dynamic accept, dynamic reject)?
      onRequest; // request, accept, reject
  Function(dynamic notification)? onNotification;

  ProtooClient.Peer get socket => _protoo;

  WebSocket({required this.peerId, required this.roomId, required this.url}) {
    _protoo = ProtooClient.Peer(
      ProtooClient.Transport(
        '$url/?roomId=$roomId&peerId=$peerId',
      ),
    );

    _protoo.on('open', () => this.onOpen?.call());
    _protoo.on('failed', () => this.onFail?.call());
    _protoo.on('disconnected', () => this.onClose?.call());
    _protoo.on('close', () => this.onClose?.call());
    _protoo.on(
        'request',
        (request, accept, reject) =>
            this.onRequest?.call(request, accept, reject));
    _protoo.on('notification',
        (request, accept, reject) => onNotification?.call(request));
  }

  setConsumerPreferredLayers(id, s, l) {
    _protoo.request("setConsumerPreferredLayers",
        {"consumerId": id, "spatialLayer": s, "temporalLayer": l});
  }

  void close() {
    _protoo.close();
  }
}
