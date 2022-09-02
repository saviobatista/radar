import 'dart:async';
import 'dart:io';
import 'package:date_time_picker/date_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:radar/services/radar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

enum PlayMode { live, replay }

class _MainScreenState extends State<MainScreen> {
  DateTime? data;
  bool live = true;
  DateTime? replayTime;
  DateTime lastUpdate = DateTime.now();
  Radar radar = Radar();
  List<Marker> markers = [];
  Timer? timer;
  List<String> replayBuffer = [];
  int replayIndex = 0;
  String? loading;
  bool paused = false;
  bool loaded = false;
  PlayMode mode = PlayMode.live;
  late Socket socket;

  @override
  void initState() {
    super.initState();
    // Ao inicializar conecta ao vivo por padrão
    Socket.connect('10.42.17.50', 30003).then(initSocket);
  }

  void initSocket(Socket s) {
    socket = s;
    socket.listen((data) {
      for (String line in String.fromCharCodes(data).trim().split('\n')) {
        parseLine(line);
      }
    });
    // TODO: handleError no socket
  }

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
              SeletorDataHora(
                onChange: (v) =>
                    setState(() => replayTime = DateTime.tryParse(v)),
              ),
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

  void onPause() {
    if (mode == PlayMode.replay) {
      paused = true;
      timer?.cancel();
    }
  }

  Future<void> onPlay() async {
    if (live) {
      Socket socket = await Socket.connect('10.42.17.50', 30003);
      socket.listen((data) {
        for (String line in String.fromCharCodes(data).trim().split('\n')) {
          parseLine(line);
        }
      });
      refresh();
    } else if (loaded && paused) {
      setState(() => paused = false);
      parseReplay();
    } else {
      // setState(() {
      //   loading = 'Processando arquivo histórico';
      //   paused = false;
      // });
      // // Feed buffer with only after replayTime defined time
      // int hora = 0;
      // await File('assets/adsb_log.20220828.csv')
      //     .openRead()
      //     .map(utf8.decode)
      //     .transform(const LineSplitter())
      //     .forEach((line) {
      //   final List<String> data = line.split(',');
      //   if (data.length > 6) {
      //     // So vai pro buffer se horario for maior que horario do replay
      //     final d =
      //         DateTime.parse('${data[6].replaceAll('/', '-')} ${data[7]}');
      //     if (data.length > 6 && d.isAfter(replayTime)) {
      //       replayBuffer.add(line);
      //     }
      //     if (d.hour > hora) {
      //       setState(() {
      //         hora = d.hour;
      //         loading = '${((hora + 1) / 24 * 100).toStringAsFixed(0)}%';
      //       });
      //     }
      //   }
      // });
      // setState(() {
      //   loading = null;
      //   loaded = true;
      // });
      // refresh();
      // parseReplay();
    }
  }

  void parseReplay() {
    if (replayBuffer.length <= replayIndex) {
      return;
    }
    final line = replayBuffer[replayIndex++];
    final List<String> data = line.split(',');

    /// Tratamento do tempo do replay
    final momento =
        DateTime.parse('${data[6].replaceAll('/', '-')} ${data[7]}');

    /// Tratamento dos voos
    radar.parse(line);

    /// Velocidade de reproducao, 1x, 2x, 3x
    const speed = 2;

    /// Proximo parse
    final duracao = Duration(
      milliseconds: momento.difference(replayTime!).inMilliseconds ~/ speed,
    );
    replayTime = momento;
    timer = Timer(duracao, () {
      parseReplay();
    });
  }

  void refresh() {
    Timer(
      const Duration(seconds: 1),
      () => setState(
        () {
          markers = radar.markers;
          lastUpdate = replayTime!;
          refresh();
        },
      ),
    );
  }

  Future<void> parseLine(String line) async {
    final List<String> data = line.split(',');
    // Avoid null line
    if (data.length < 7) return;

    // /// Tratamento do tempo do replay
    // final momento =
    //     DateTime.parse('${data[6].replaceAll('/', '-')} ${data[7]}');
    // if (!momento.isBefore(replayTime!)) {
    //   final duracao = replayTime!.difference(momento);
    //   await Future.delayed(duracao);
    //   replayTime = momento;
    // }

    /// Tratamento dos voos
    radar.parse(line);
    if (mode != PlayMode.live) return;
    setState(() => markers = radar.markers);
  }

  void swapMode() async {
    PlayMode newMode = mode == PlayMode.live ? PlayMode.replay : PlayMode.live;
    if (socket.runtimeType == Socket) {
      // Shutdown socket
      await socket.close();
      socket.destroy();
    }
    if (newMode == PlayMode.replay) {
      radar.flights.clear();
    }
    setState(() {
      mode = newMode;
    });
  }

  void rePlay() {}
}

class SeletorDataHora extends StatefulWidget {
  const SeletorDataHora({Key? key, required this.onChange}) : super(key: key);

  final Function(String) onChange;

  @override
  State<SeletorDataHora> createState() => _SeletorDataHoraState();
}

class _SeletorDataHoraState extends State<SeletorDataHora> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 40,
      child: DateTimePicker(
        enabled: true,
        type: DateTimePickerType.dateTimeSeparate,
        dateMask: 'd MMM, yyyy',
        initialValue:
            DateTime.now().subtract(const Duration(days: 1)).toString(),
        firstDate: DateTime(2022, 1, 1),
        lastDate: DateTime.now().subtract(const Duration(days: 1)),
        icon: const Icon(Icons.event),
        use24HourFormat: true,
        locale: const Locale('pt', 'BR'),
        onChanged: widget.onChange,
      ),
    );
  }
}
