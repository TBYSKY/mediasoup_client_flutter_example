import 'dart:convert';
import 'dart:developer';

import 'package:example/features/peers/ui/remote_stream.dart';
import 'package:example/features/signaling/room_client_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:example/features/peers/bloc/peers_bloc.dart';
import 'package:example/features/peers/enitity/peer.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ListRemoteStreams extends StatelessWidget {
  const ListRemoteStreams({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Map<String, Peer> peers =
        context.select((PeersBloc bloc) => bloc.state.peers);

    final bool small = MediaQuery.of(context).size.width < 800;
    final bool horizontal =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (small && peers.length == 1) {
      return InkWell(
        child: RemoteStream(
          key: ValueKey(peers.keys.first),
          peer: peers.values.first,
        ),
        onTap: () async {
          List<dynamic> statsList = await peers.values.first.video!.getStats();
          statsList.forEach((e) {
            log(jsonEncode(e.values));
          });
          context
              .read<RoomClientRepository>()
              .setConsumerPreferredLayers(peers.values.first.video!.id, 0, 0);
          print("---------------------------");
          statsList.forEach((e) {
            log(jsonEncode(e.values));
          });
        },
        onDoubleTap: (() {
          context
              .read<RoomClientRepository>()
              .setConsumerPreferredLayers(peers.values.first.video!.id, 2, 2);
        }),
        onLongPress: () async {
          List<dynamic> statsList = await peers.values.first.video!.getStats();
          StatsReport sta = statsList.firstWhere((e) {
            return jsonEncode(e.values).contains("googFrameHeightReceived");
          });

          Map map = sta.values;
          Fluttertoast.showToast(
              msg:
                  "${map["googFrameWidthReceived"]} x${map["googFrameHeightReceived"]} 帧率：${map["googFrameRateOutput"]}",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0);
        },
      );
    }

    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    if (small && horizontal)
      return MediaQuery.removePadding(
        context: context,
        child: GridView.count(
          crossAxisCount: 2,
          children: peers.values.map((peer) {
            return InkWell(
              child: Container(
                key: ValueKey('${peer.id}_container'),
                width: width / 2,
                height: peers.length <= 2 ? height : height / 2,
                child: RemoteStream(
                  key: ValueKey(peer.id),
                  peer: peer,
                ),
              ),
              onTap: () async {
                List<dynamic> statsList = await peer.video!.getStats();
                statsList.forEach((e) {
                  log(jsonEncode(e.values));
                });
                context
                    .read<RoomClientRepository>()
                    .setConsumerPreferredLayers(peer.video!.id, 0, 0);
                print("---------------------------");
                statsList.forEach((e) {
                  log(jsonEncode(e.values));
                });
              },
            );
          }).toList(),
        ),
        removeTop: true,
      );

    if (small)
      return MediaQuery.removePadding(
        context: context,
        child: ListView.builder(
          itemBuilder: (context, index) {
            final peerId = peers.keys.elementAt(index);
            return InkWell(
                child: Container(
                  key: ValueKey('${peerId}_container'),
                  width: double.infinity,
                  height: peers.length > 2 ? height / 3 : height / 2,
                  child: RemoteStream(
                    key: ValueKey(peerId),
                    peer: peers[peerId]!,
                  ),
                ),
                onTap: () async {
                  List<dynamic> statsList =
                      await peers[peerId]!.video!.getStats();
                  statsList.forEach((e) {
                    log(jsonEncode(e.values));
                  });

                  context
                      .read<RoomClientRepository>()
                      .setConsumerPreferredLayers(
                          peers[peerId]!.video!.id, 0, 0);
                  print("---------------------------");
                  statsList.forEach((e) {
                    log(jsonEncode(e.values));
                  });
                });
          },
          itemCount: peers.length,
          scrollDirection: Axis.vertical,
          shrinkWrap: true,
        ),
        removeTop: true,
      );

    return Center(
      child: Wrap(
        spacing: 10,
        children: [
          for (Peer peer in peers.values)
            InkWell(
              child: Container(
                key: ValueKey('${peer.id}_container'),
                width: 450,
                height: 380,
                child: RemoteStream(
                  key: ValueKey(peer.id),
                  peer: peers[peer.id]!,
                ),
              ),
              onTap: () async {
                List<dynamic> statsList = await peer.video!.getStats();
                statsList.forEach((e) {
                  log(jsonEncode(e.values));
                });
                context
                    .read<RoomClientRepository>()
                    .setConsumerPreferredLayers(peer.video!.id, 0, 0);
                print("---------------------------");
                statsList.forEach((e) {
                  log(jsonEncode(e.values));
                });
              },
            )
        ],
      ),
    );
  }
}
