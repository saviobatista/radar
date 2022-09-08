import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';

final kWaypoints = [
  Marker(
    // SEBSU (FINAL 15)
    width: 10,
    height: 10,
    point: LatLng(-22.94727778, -47.21841667),
    builder: (context) => const Icon(Icons.diamond),
  ),
  Marker(
    // ARNIV (FINAL 33)
    width: 10,
    height: 10,
    point: LatLng(-23.06750833, -47.05051389),
    builder: (context) => const Icon(Icons.diamond),
  ),
  // FINAL 33 - 4nm
  Marker(
    width: 5,
    height: 5,
    point: LatLng(-23.05729992308919, -47.064786586193726),
    builder: (context) => const Icon(Icons.circle_sharp, size: 10.0),
  ),
  //
  Marker(
    width: 5,
    height: 5,
    point: LatLng(-23.04720159529468, -47.07884328257547),
    builder: (context) => const Icon(Icons.circle_sharp, size: 10.0),
  ),
  //
  Marker(
    width: 5,
    height: 5,
    point: LatLng(-23.03714968709546, -47.09295682997209),
    builder: (context) => const Icon(Icons.circle_sharp, size: 10.0),
  ),
  //
  Marker(
    width: 5,
    height: 5,
    point: LatLng(-23.027075069936572, -47.107036796366856),
    builder: (context) => const Icon(Icons.circle_sharp, size: 10.0),
  ),
];
