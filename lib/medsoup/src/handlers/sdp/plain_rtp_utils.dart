import 'package:example/medsoup/src/handlers/sdp/media_section.dart';
import 'package:example/medsoup/src/rtp_parameters.dart';
import 'package:example/medsoup/src/sdp_object.dart';
import 'package:example/medsoup/src/transport.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';


class PlainRtpUtils {
  static PlainRtpParameters extractPlainRtpParameters(
    SdpObject sdpObject,
    RTCRtpMediaType kind,
  ) {
    MediaObject? mediaObject = sdpObject.media.firstWhere(
      (MediaObject m) => m.type == RTCRtpMediaTypeExtension.value(kind),
      orElse: () => null as MediaObject,
    );

    if (mediaObject == null) {
      throw ('m=${RTCRtpMediaTypeExtension.value(kind)} section not found');
    }

    Connection connectionObject =
        (mediaObject.connection ?? sdpObject.connection)!;

    PlainRtpParameters result = PlainRtpParameters(
      ip: connectionObject.ip,
      ipVersion: connectionObject.version,
      port: mediaObject.port!,
    );

    return result;
  }

  static List<RtpEncodingParameters> getRtpEncodings(
    SdpObject sdpObject,
    RTCRtpMediaType kind,
  ) {
    MediaObject? mediaObject = sdpObject.media.firstWhere(
      (MediaObject m) => m.type == RTCRtpMediaTypeExtension.value(kind),
      orElse: () => null as MediaObject,
    );

    if (mediaObject == null) {
      throw ('m=${RTCRtpMediaTypeExtension.value(kind)} section not found');
    }

    if (mediaObject.ssrcs != null || mediaObject.ssrcs!.isNotEmpty) {
      Ssrc ssrc = mediaObject.ssrcs!.first;
      RtpEncodingParameters result = RtpEncodingParameters(ssrc: ssrc.id);

      return <RtpEncodingParameters>[result];
    }

    return <RtpEncodingParameters>[];
  }
}
