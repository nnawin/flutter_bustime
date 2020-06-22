import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

Future<Bus> fetchAlbum(route, stop) async {
  if (route == null || stop == null) {
    route = 'S56';
    stop = '003443';
  }
  final response = await http.get(
      'https://rt.data.gov.hk/v1/transport/citybus-nwfb/eta/CTB/' +
          stop +
          '/' +
          route);

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    return Bus.fromJson(json.decode(response.body));
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load album');
  }
}

class Bus {
  final String routeNumber;
  final List<String> eta;

  Bus({this.routeNumber, this.eta});

  factory Bus.fromJson(Map<String, dynamic> json) {
    List<String> timings = List();
    for (var i in json['data']) {
      timings.add(i['eta']);
    }
    return Bus(routeNumber: json['data'][0]['route'], eta: timings);
  }
}

void main() => runApp( new MaterialApp(
home: MyApp(),
debugShowCheckedModeBanner: false,
));

class MyApp extends StatefulWidget {
  
  MyApp({Key key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<Bus> futureAlbum;
  String dropdownValue = 'S56';

  @override
  void initState() {
    super.initState();
    futureAlbum = fetchAlbum('S56', '003443');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fetch Data Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Next bus arrival info...'),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              DropdownButton<String>(
                value: dropdownValue,
                icon: Icon(Icons.train),
                iconSize: 24,
                elevation: 16,
                style: TextStyle(color: Colors.deepPurple),
                underline: Container(
                  height: 2,
                  color: Colors.deepPurpleAccent,
                ),
                onChanged: (String newValue) {
                  setState(() {
                    dropdownValue = newValue;
                  });
                  futureAlbum = fetchAlbum(dropdownValue, '003443');
                },
                items: <String>['S56', 'E21A']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(64.0),
                  child: FutureBuilder<Bus>(
                    future: futureAlbum,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        var etaTexts = '';
                        DateFormat dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ssZZZZ");
                        DateFormat dateFormat2 = DateFormat("HH:mm");
                        DateTime dateTime;
                        for (var i in snapshot.data.eta) {
                          dateTime = dateFormat.parse(i);
                          etaTexts = etaTexts + dateFormat2.format(dateTime) + '\n';
                        }
                        return Text(etaTexts);
                      }
                      // By default, show a loading spinner.
                      return CircularProgressIndicator();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
