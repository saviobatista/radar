import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:date_time_picker/date_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:radar/services/radar_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  DateTime? data;
  bool live = true;
  DateTime? replayTime;
  DateTime lastUpdate = DateTime.now();
  RadarService radar = RadarService();
  List<Marker> markers = [];
  Timer? timer;
  List<String> replayBuffer = [];
  int replayIndex = 0;
  String? loading;
  bool paused = false;
  bool loaded = false;
  bool configured = false;
  late Socket socket;
  late Socket replayController;
  List<DropdownMenuItem<String>> dias = [
    const DropdownMenuItem(value: '0', child: Text('Aguarde...')),
  ];
  String? dia;
  String? hora;

  void handleController(
    Socket s,
  ) {
    replayController = s;
    replayController.listen((data) {
      print('COMANDO ENVIADO PELO SERVIDOR DE CONTROLE');
      final param = jsonDecode(String.fromCharCodes(data));
      switch (param['action']) {
        case 'days':
          print('Dias disponíveis');
          List<DropdownMenuItem<String>> newDays = [];
          for (String dia in param['days']) {
            newDays.add(DropdownMenuItem(
              key: Key(dia),
              value: dia,
              child: Text(
                  '${dia.substring(6, 8)}/${dia.substring(4, 6)}/${dia.substring(0, 4)}'),
            ));
          }
          setState(() {
            dias = newDays;
          });
          break;
        default:
          print('Comando invalido!');
          print(param);
      }
    });
    replayController.write(jsonEncode({'action': 'days'}));
  }

  void handleControllerError(error) {
    print('ERRO NO CONTROLLER');
  }

  @override
  void initState() {
    super.initState();
    // Controller
    Socket.connect('10.42.17.193', 9141)
        .then(handleController, onError: handleControllerError);
    // Streamer
    Socket.connect(
            mode == PlayMode.replay ? '10.42.17.193' : '10.42.17.50', 30003)
        .then((Socket socket) {
      print('connected');
      socket.listen((data) {
        print('listening');
        print(String.fromCharCodes(data));
        for (String line in String.fromCharCodes(data).trim().split('\n')) {
          parseLine(line);
        }
      }).onError((e) {
        print(e);
      });
    });
  }

  @override
  Widget build(BuildContext context) {}

  void onPause() {
    if (mode == PlayMode.replay) {
      paused = true;
      timer?.cancel();
    }
  }

  Future<void> onPlay() async {
    if (!configured) {
      replayController.write(
        jsonEncode(
          {
            'action': 'setup',
            'day': dia,
            'hour': hora,
          },
        ),
      );
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

  void rePlay() {
    onPlay();
  }
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
      width: 80,
      height: 45,
      child: DateTimePicker(
        enabled: true,
        type: DateTimePickerType.time,
        use24HourFormat: true,
        locale: const Locale('pt', 'BR'),
        onChanged: widget.onChange,
      ),
    );
  }
}
