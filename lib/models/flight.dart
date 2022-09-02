import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:radar/models/position.dart';
import 'package:latlong2/latlong.dart' show LatLng, pi;

class Flight {
  final String icao;
  DateTime? date;
  String? callsign;
  int? altitude;
  int? speed;
  int? track;
  double? latitude;
  double? longitude;
  int? verticalRate;
  bool? emergency; // em emergencia
  bool? ident; // Modo identificacao de transponder
  bool? solo; // No solo?
  String? type;

  final transitionHeight = 8000;

  List<Position> gps = [];

  Flight({
    required this.icao,
    this.date,
    this.callsign,
    this.altitude,
    this.speed,
    this.track,
    this.latitude,
    this.longitude,
    this.verticalRate,
    this.emergency,
    this.ident,
    this.solo,
    this.type,
  });

  num get angle {
    if (track != null) {
      return track! * ((22 / 7) / 180);
    } else if (gps.length < 10) {
      return 0.0;
    } else {
      final Position pos1 = gps[gps.length - 10];
      final Position pos2 = gps[gps.length - 1];
      final double dx = pos2.longitude - pos1.longitude;
      final double dy = pos2.latitude - pos1.latitude;
      return atan2(dy, dx) * 180 / pi;
    }
  }

  String get flightlevel {
    if (altitude == null) {
      return '???';
    } else if (altitude! > transitionHeight) {
      return 'FL${(altitude! / 100).ceil()}';
    } else {
      return '${altitude!}FT';
    }
  }

  Marker get marker => Marker(
        point: LatLng(latitude!, longitude!),
        height: 25,
        width: 100,
        anchorPos: AnchorPos.exactly(Anchor(90, 15)),
        builder: (context) => Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.rotate(
              // angle: (track?.toDouble() ?? 1) * pi / 180,
              angle: angle.toDouble(),
              child: const Icon(Icons.airplanemode_on),
            ),
            Column(
              children: [
                Text(callsign ?? icao, style: const TextStyle(fontSize: 10.0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('${flightlevel} -- ${speed}KT',
                        style: const TextStyle(fontSize: 8.0)),
                    // Text(),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
}
