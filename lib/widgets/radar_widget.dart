import 'package:date_time_picker/date_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:radar/services/radar_service.dart';
import 'package:latlong2/latlong.dart';

class RadarWidget extends StatefulWidget {
  const RadarWidget({Key? key}) : super(key: key);

  @override
  State<RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget> {
  final RadarService radar = RadarService(
    liveIP: '10.42.17.50',
    replayIP: '10.42.17.193',
    controllerPort: '30009',
  );
  List<Marker> markers = [];
  List<String> days = [];

  @override
  void initState() {
    super.initState();
    radar.setCallback((List<Marker> data) {
      setState(() => markers = data);
    });
    radar.setDaysCallback((List<String> data) {
      setState(() => days = data);
    });
  }

  Widget get modeIcon =>
      radar.mode == PlayMode.live ? liveButton : replayButton;

  Widget get liveButton => IconButton(
        onPressed: radar.swapMode,
        icon: const Icon(Icons.live_tv),
        tooltip: 'Exibindo dados ao vivo, clique para replay',
      );
  Widget get replayButton => IconButton(
        onPressed: radar.swapMode,
        icon: const Icon(Icons.replay),
        tooltip: 'Exibindo replay, clique para ao vivo',
      );

  Widget get toolbarData => radar.mode == PlayMode.live
      ? const Text('00:00 22/22/22')
      : Row(
          children: [
            const Text('Data:'),
            const SizedBox(width: 10),
            DropdownButton(
              items: days.map((String day) {
                return DropdownMenuItem(
                  value: day,
                  child: Text(day),
                );
              }).toList(),
              onChanged: (String? value) {
                radar.setParam('date', value.toString());
              },
            ),
            const SizedBox(width: 10),
            const Text('Hora:'),
            const SizedBox(width: 10),
            DateTimePicker(
              type: DateTimePickerType.time,
              icon: const Icon(Icons.access_time),
              timeLabelText: 'Hora',
              onChanged: (value) {
                radar.setParam('time', value);
              },
            ),
            const SizedBox(width: 10),
            controlButton,
          ],
        );
  Widget get controlButton => IconButton(
        onPressed: () {
          // radar.changeParam('action', 'play');
        },
        icon: const Icon(Icons.play_arrow),
        tooltip: 'Iniciar replay',
      );
  Widget get bodyContent => radar.state == RadarState.loading
      ? const Center(
          child: Text(
            'Carregando...',
            style: TextStyle(fontSize: 40.0),
          ),
        )
      : radar.state == RadarState.error
          ? const Center(
              child: Text(
                'Erro ao carregar dados',
                style: TextStyle(fontSize: 40.0),
              ),
            )
          : mapa;

  Widget get mapa => FlutterMap(
        options: MapOptions(
          center: LatLng(-23.006653059524492, -47.13571101259729),
          zoom: 13.0,
        ),
        layers: [
          TileLayerOptions(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
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
      );
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Radar ADSB'),
            const SizedBox(width: 20),
            modeIcon,
            toolbarData,
          ],
        ),
      ),
      body: bodyContent,
    );
  }
}
