import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

enum PlayMode { live, replay }

class RadarWidget extends StatefulWidget {
  const RadarWidget({Key? key}) : super(key: key);

  @override
  State<RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget> {
  PlayMode mode = PlayMode.replay;

  void swapMode() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Radar ADSB'),
            const SizedBox(width: 20),
            IconButton(
              icon: Icon(mode == PlayMode.live ? Icons.live_tv : Icons.replay),
              tooltip: mode == PlayMode.live
                  ? 'Exibindo dados ao vivo, clique para replay'
                  : 'Exibindo replay, clique para ao vivo',
              onPressed: swapMode,
            ),
            if (mode == PlayMode.replay) ...[
              const SizedBox(width: 50),
              DropdownButton(
                  icon: const Icon(Icons.calendar_today),
                  items: dias,
                  value: dia,
                  onChanged: (v) => setState(() => dia = v.toString())),
              const SizedBox(width: 20),
              SeletorDataHora(
                  onChange: (v) => setState(() => hora = v.toString())),
              const SizedBox(width: 20),
              IconButton(
                icon: Icon(paused ? Icons.pause_circle : Icons.play_circle),
                onPressed: rePlay,
              ),
            ]
          ],
        ),
      ),
      body: loading != null
          ? Center(
              child: Text(
                loading!,
                style: const TextStyle(fontSize: 40.0),
              ),
            )
          : FlutterMap(
              options: MapOptions(
                center: LatLng(-23.006653059524492, -47.13571101259729),
                zoom: 13.0,
              ),
              layers: [
                TileLayerOptions(
                  urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayerOptions(
                  markers: markers,
                ),
                MarkerLayerOptions(
                  markers: [
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
                      builder: (context) =>
                          const Icon(Icons.circle_sharp, size: 10.0),
                    ),
                    //
                    Marker(
                      width: 5,
                      height: 5,
                      point: LatLng(-23.04720159529468, -47.07884328257547),
                      builder: (context) =>
                          const Icon(Icons.circle_sharp, size: 10.0),
                    ),
                    //
                    Marker(
                      width: 5,
                      height: 5,
                      point: LatLng(-23.03714968709546, -47.09295682997209),
                      builder: (context) =>
                          const Icon(Icons.circle_sharp, size: 10.0),
                    ),
                    //
                    Marker(
                      width: 5,
                      height: 5,
                      point: LatLng(-23.027075069936572, -47.107036796366856),
                      builder: (context) =>
                          const Icon(Icons.circle_sharp, size: 10.0),
                    ),
                  ],
                )
              ],
              nonRotatedChildren: [
                AttributionWidget.defaultWidget(
                  source: 'Sávio Batista',
                  onSourceTapped: () {},
                ),
              ],
            ),
    );
  }
}
