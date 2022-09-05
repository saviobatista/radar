import 'package:flutter_map/flutter_map.dart';
import 'package:radar/models/flight.dart';
import 'package:radar/models/position.dart';

class RadarService {
  Map<String, Flight> flights = {};
  List<List<String>> aircrafts = [];

  Socket live

  RadarService() {
    // File('assets/aircrafts.csv').readAsLinesSync().forEach((line) {
    //   aircrafts.add(line.split(','));
    // });
  }

  List<Marker> get markers => flights.entries
      .where((e) => e.value.latitude != null && e.value.latitude != null)
      .map<Marker>((e) => e.value.marker)
      .toList();

  void parse(String line) {
    // MSG,3,1,1,E49405,1,2022/06/23,00:00:10.169,2022/06/23,00:00:10.219,,19200,,,-22.90146,-47.14713,,,0,,0,0
    final List<String> data = line.split(',');
    final String icao = data[4];
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
  }
}
