import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:date_time_picker/date_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:radar/models/flight.dart';
import 'package:radar/models/position.dart';
import 'package:radar/widgets/waypoints.dart';

enum RadarMode { live, replay }

enum RadarState { loading, loaded, error, playing, swaping, paused }

class RadarWidget extends StatefulWidget {
  const RadarWidget({Key? key}) : super(key: key);

  @override
  State<RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget> {
  List<List<String>> aircrafts = [];

  RadarState state = RadarState.playing;
  RadarMode mode = RadarMode.live;

  late Socket live;
  Map<String, Flight> liveFlights = {};

  late Socket replay;
  Map<String, Flight> replayFlights = {};

  List<Marker> markers = [];
  Map<String, String> days = {};
  String? day;
  String hora = '00:00';
  String? moment;

  @override
  void initState() {
    super.initState();
    // Live server connect
    Socket.connect('10.42.17.50', 30003).then((s) {
      live = s;
      live.listen((data) {
        parseRawData(data, RadarMode.live);
      });

      // Update markers every second
      // Refresh every second
      Timer.periodic(const Duration(seconds: 1), (timer) {
        final last10minutes =
            DateTime.now().subtract(const Duration(minutes: 10));
        setState(() {
          markers = (mode == RadarMode.live ? liveFlights : replayFlights)
              .entries
              .where((e) => e.value.latitude != null && e.value.latitude != null
                  // && e.value.date!.compareTo(last10minutes) >= 0
                  )
              .map<Marker>((e) => e.value.marker)
              .toList();
          hora = moment.toString();
        });
      });
    });
    // Replay server connect
    Socket.connect('10.42.17.193', 30003).then((s) {
      replay = s;
      replay.listen((data) {
        parseRawData(data, RadarMode.replay);
      });
      replay.writeln(jsonEncode({'action': 'days'}));
    });
  }

  void parseRawData(Uint8List data, RadarMode mode) {
    final lines = String.fromCharCodes(data).split('\n');
    for (final line in lines) {
      if (line.isNotEmpty) {
        if (line.length > 2 && line.substring(0, 3) == 'MSG') {
          parse(line, mode);
        } else {
          parseInfo(line);
        }
      }
    }
  }

  void parseInfo(String line) {
    final params = jsonDecode(line);
    switch (params['action']) {
      case 'days':
        for (String day in params['days']) {
          days[day] =
              '${day.substring(6, 8)}/${day.substring(4, 6)}/${day.substring(0, 4)}';
        }
        setState(() {
          days = days;
          state = RadarState.paused;
        });
        break;
      case 'status':
        switch (params['status']) {
          case 'ready':
          case 'paused':
            setState(() => state = RadarState.paused);
            break;
          case 'playing':
            setState(() => state = RadarState.playing);
            break;
          case 'loading':
            setState(() => state = RadarState.loading);
            break;
        }
        break;
      // case 'playing':
      //   setState(() => state = RadarState.playing);
      //   break;
      // case 'paused':
      //   setState(() => state = RadarState.paused);
      //   break;
    }
  }

  void parse(String line, RadarMode m) {
    if (state == RadarState.swaping) return;
    // MSG,3,1,1,E49405,1,2022/06/23,00:00:10.169,2022/06/23,00:00:10.219,,19200,,,-22.90146,-47.14713,,,0,,0,0
    final List<String> data = line.split(',');
    final String icao = data[4];
    final flights = m == RadarMode.live ? liveFlights : replayFlights;
    if (!flights.keys.contains(icao)) {
      flights[icao] = Flight(icao: icao);
      final dbInfo =
          aircrafts.firstWhere((e) => e[0] == icao, orElse: () => []);
      if (dbInfo.isNotEmpty) {
        flights[icao]?.callsign = dbInfo[1];
        flights[icao]?.type = dbInfo[2];
      }
    }
    flights[icao]!.date =
        DateTime.parse('${data[6].replaceAll('/', '-')} ${data[7]}');
    if (m == mode) {
      moment = data[7].substring(0, 5);
    }
    //EXTRA: Store gps position in history
    if (data[14].isNotEmpty &&
        data[15].isNotEmpty &&
        double.parse(data[14]) != flights[icao]!.latitude &&
        double.parse(data[15]) != flights[icao]!.longitude) {
      flights[icao]!.gps.add(Position(
            latitude: double.parse(data[14]),
            longitude: double.parse(data[15]),
            altitude: int.tryParse(data[11]) ?? 0,
            date: flights[icao]!.date!,
          ));
      if (flights[icao]!.gps.length > 15) {
        flights[icao]!.gps.removeAt(0);
      }
    }

    // Field 11: Callsign	 An eight digit flight ID - can be flight number or registration (or even nothing).
    if (data[10].isNotEmpty) {
      flights[icao]!.callsign = data[10];
    }
    // Field 12: Altitude	 Mode C altitude. Height relative to 1013.2mb (Flight Level). Not height AMSL..
    if (data[11].isNotEmpty) {
      flights[icao]!.altitude = int.parse(data[11]);
    }
    // Field 13: GroundSpeed	 Speed over ground (not indicated airspeed)
    if (data[12].isNotEmpty) {
      flights[icao]!.speed = int.parse(data[12]);
    }
    // Field 14: Track	 Track of aircraft (not heading). Derived from the velocity E/W and velocity N/S
    if (data[13].isNotEmpty) {
      flights[icao]!.track = int.parse(data[13]);
    }
    // Field 15: Latitude	 North and East positive. South and West negative.
    if (data[14].isNotEmpty) {
      flights[icao]!.latitude = double.parse(data[14]);
    }
    // Field 16: Longitude	 North and East positive. South and West negative.
    if (data[15].isNotEmpty) {
      flights[icao]!.longitude = double.parse(data[15]);
    }
    // Track of aircraft (not heading). Derived from the velocity E/W and velocity N/S
    if (data[13].isNotEmpty) {
      flights[icao]!.track = int.parse(data[13]);
    }
    // Field 17: VerticalRate	 64ft resolution
    if (data[16].isNotEmpty) {
      flights[icao]!.verticalRate = int.parse(data[16]);
    }
    // Field 20: Emergency	 Flag to indicate emergency code has been set
    if (data[19].isNotEmpty) {
      flights[icao]!.emergency = data[19] == '1';
    }
    // Field 21: SPI (Ident)	 Flag to indicate transponder Ident has been activated.
    if (data[20].isNotEmpty) {
      flights[icao]!.ident = data[20] == '1';
    }
    // Field 22: IsOnGround	 Flag to indicate ground squat switch is active
    if (data[21].isNotEmpty) {
      flights[icao]!.solo = data[21] == '1';
    }

    // Message type	 (MSG, STA, ID, AIR, SEL or CLK)
    // Might be done or not
    // Field 2 Transmission Type	 MSG sub types 1 to 8. Not used by other message types.
    // Field 3: Session ID	 Database Session record number
    // Field 4: AircraftID	 Database Aircraft record number
    // Field 5: HexIdent	 Aircraft Mode S hexadecimal code
    // Field 6: FlightID	 Database Flight record number
    // Field 7: Date message generated	  As it says
    // Field 8: Time message generated	  As it says
    // Field 9: Date message logged	  As it says
    // Field 10: Time message logged	  As it says
    // Field 11: Callsign	 An eight digit flight ID - can be flight number or registration (or even nothing).
    // Field 18: Squawk	 Assigned Mode A squawk code.
    // Field 19: Alert (Squawk change)	 Flag to indicate squawk has changed.

    if (m == RadarMode.live) {
      liveFlights = flights;
    } else {
      replayFlights = flights;
    }
  }

  void swapMode() async {
    setState(
      () => mode = mode == RadarMode.live ? RadarMode.replay : RadarMode.live,
    );
  }

  void toggleReplay() {
    replay.write(
      jsonEncode(
        {
          'action': state == RadarState.playing ? 'pause' : 'play',
        },
      ),
    );
  }

  Widget get modeIcon => mode == RadarMode.live ? liveButton : replayButton;

  Widget get liveButton => IconButton(
        onPressed: swapMode,
        icon: const Icon(Icons.live_tv),
        tooltip: 'Exibindo dados ao vivo, clique para replay',
      );
  Widget get replayButton => IconButton(
        onPressed: swapMode,
        icon: const Icon(Icons.replay),
        tooltip: 'Exibindo replay, clique para ao vivo',
      );
  Widget get statusText => mode == RadarMode.live
      ? SizedBox()
      : (state == RadarState.loading
          ? Text('Carregando...')
          : state == RadarState.paused
              ? Text('Pausado')
              : state == RadarState.playing
                  ? Text('Reproduzindo')
                  : Text('UNKN'));

  // Row(
  //     children: [
  //       const Text('Data:'),
  //       const SizedBox(width: 10),
  //       DropdownButton(
  //         items: days.map((String day) {
  //           return DropdownMenuItem(
  //             value: day,
  //             child: Text(day),
  //           );
  //         }).toList(),
  //         onChanged: (String? value) {
  //           // radar.setParam('date', value.toString());
  //         },
  //       ),
  //       const SizedBox(width: 10),
  //       const Text('Hora:'),
  //       const SizedBox(width: 10),
  //       DateTimePicker(
  //         type: DateTimePickerType.time,
  //         icon: const Icon(Icons.access_time),
  //         timeLabelText: 'Hora',
  //         onChanged: (value) {
  //           // radar.setParam('time', value);
  //         },
  //       ),
  //       const SizedBox(width: 10),
  //       controlButton,
  //     ],
  //   );
  Widget get controlButton => IconButton(
        onPressed: () {
          // radar.changeParam('action', 'play');
        },
        icon: const Icon(Icons.play_arrow),
        tooltip: 'Iniciar replay',
      );
  Widget get bodyContent => state == RadarState.loading
      ? const Center(
          child: Text(
            'Carregando...',
            style: TextStyle(fontSize: 40.0),
          ),
        )
      : state == RadarState.error
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
            markers: kWaypoints,
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
            if (mode == RadarMode.replay) ...[
              DropdownButton(
                icon: const Icon(Icons.calendar_month),
                value: day,
                items: days.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  setState(() => day = value);
                  replay.write(jsonEncode({'action': 'day', 'day': day}));
                },
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                height: 30,
                child: DateTimePicker(
                  type: DateTimePickerType.time,
                  icon: const Icon(Icons.access_time),
                  timeLabelText: 'Hora',
                  onChanged: (hour) {
                    replay.write(jsonEncode({'action': 'hour', 'hour': hour}));
                  },
                ),
              ),
              IconButton(
                onPressed: state == RadarState.loading ? null : toggleReplay,
                icon: Icon(state == RadarState.loading
                    ? Icons.timer
                    : state == RadarState.playing
                        ? Icons.pause_circle
                        : Icons.play_circle),
              ),
              SizedBox(width: 50),
              statusText
            ],
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(hora),
                ],
              ),
            ),
          ],
        ),
      ),
      body: bodyContent,
    );
  }
}
