import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// --- Data Model ---

class BusEta {
  final String route;
  final String destination;
  final String eta;
  final int sequence;

  BusEta({
    required this.route,
    required this.destination,
    required this.eta,
    required this.sequence,
  });

  factory BusEta.fromJson(Map<String, dynamic> json) {
    return BusEta(
      route: json['route'] ?? '',
      destination: json['dest_en'] ?? '',
      eta: json['eta'] ?? '',
      sequence: json['eta_seq'] ?? 0,
    );
  }
}

class BusResult {
  final String route;
  final List<BusEta> etas;

  BusResult({required this.route, required this.etas});

  factory BusResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? [];
    final etas = data
        .where((item) => item['eta'] != null)
        .map((item) => BusEta.fromJson(item as Map<String, dynamic>))
        .toList();
    final route =
        data.isNotEmpty ? (data[0]['route'] as String? ?? '') : '';
    return BusResult(route: route, etas: etas);
  }
}

// --- API Service ---

Future<BusResult> fetchBusEta(String route, String stop) async {
  final url = Uri.parse(
    'https://rt.data.gov.hk/v1/transport/citybus-nwfb/eta/CTB/$stop/$route',
  );
  final response = await http.get(url);
  if (response.statusCode == 200) {
    return BusResult.fromJson(json.decode(response.body));
  } else {
    throw Exception('Failed to load bus ETA data');
  }
}

// --- Route Config ---

class RouteStop {
  final String route;
  final String stopId;
  final String stopName;

  const RouteStop({
    required this.route,
    required this.stopId,
    required this.stopName,
  });
}

const List<RouteStop> availableRoutes = [
  RouteStop(route: 'S56', stopId: '003443', stopName: 'Tung Chung Station'),
  RouteStop(route: 'E21A', stopId: '003443', stopName: 'Tung Chung Station'),
  RouteStop(route: 'S1', stopId: '003443', stopName: 'Tung Chung Station'),
  RouteStop(route: 'E11', stopId: '003443', stopName: 'Tung Chung Station'),
];

// --- App Entry ---

void main() => runApp(const BusTimeApp());

class BusTimeApp extends StatelessWidget {
  const BusTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HK Bus ETA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const BusHomePage(),
    );
  }
}

// --- Home Page ---

class BusHomePage extends StatefulWidget {
  const BusHomePage({super.key});

  @override
  State<BusHomePage> createState() => _BusHomePageState();
}

class _BusHomePageState extends State<BusHomePage> {
  RouteStop _selectedRoute = availableRoutes[0];
  Future<BusResult>? _futureEta;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _fetchData() {
    setState(() {
      _futureEta = fetchBusEta(_selectedRoute.route, _selectedRoute.stopId);
    });
  }

  void _onRouteChanged(RouteStop route) {
    setState(() {
      _selectedRoute = route;
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HK Bus ETA'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchData,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return _buildWideLayout(constraints);
            } else if (constraints.maxWidth >= 600) {
              return _buildMediumLayout(constraints);
            } else {
              return _buildNarrowLayout(constraints);
            }
          },
        ),
      ),
    );
  }

  // Wide layout: side-by-side route selector and ETA results
  Widget _buildWideLayout(BoxConstraints constraints) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 320,
          child: _buildRouteSelectorPanel(),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _buildEtaResultPanel(),
        ),
      ],
    );
  }

  // Medium layout: centered content with constrained width
  Widget _buildMediumLayout(BoxConstraints constraints) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: _buildSingleColumnLayout(),
      ),
    );
  }

  // Narrow layout: full-width single column
  Widget _buildNarrowLayout(BoxConstraints constraints) {
    return _buildSingleColumnLayout();
  }

  Widget _buildSingleColumnLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRouteSelector(),
          const SizedBox(height: 16),
          _buildEtaContent(),
        ],
      ),
    );
  }

  // --- Route Selector Panel (wide layout sidebar) ---
  Widget _buildRouteSelectorPanel() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select Route',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: availableRoutes.length,
              itemBuilder: (context, index) {
                final route = availableRoutes[index];
                final isSelected = route == _selectedRoute;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      route.route.substring(0, 1),
                      style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    'Route ${route.route}',
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(route.stopName),
                  selected: isSelected,
                  selectedTileColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  onTap: () => _onRouteChanged(route),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- ETA Result Panel (wide layout main area) ---
  Widget _buildEtaResultPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route ${_selectedRoute.route}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            _selectedRoute.stopName,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          _buildEtaContent(),
        ],
      ),
    );
  }

  // --- Route Selector Card (narrow/medium layout) ---
  Widget _buildRouteSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_bus,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select Route',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableRoutes.map((route) {
                final isSelected = route == _selectedRoute;
                return FilterChip(
                  label: Text(route.route),
                  selected: isSelected,
                  onSelected: (_) => _onRouteChanged(route),
                  avatar: isSelected
                      ? null
                      : const Icon(Icons.directions_bus_outlined, size: 18),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedRoute.stopName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ETA Content ---
  Widget _buildEtaContent() {
    if (_futureEta == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<BusResult>(
      future: _futureEta,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.etas.isEmpty) {
          return _buildEmptyCard();
        }

        return _buildEtaCards(snapshot.data!);
      },
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Failed to load ETA',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.schedule,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No upcoming arrivals',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'There are no scheduled buses for this route right now.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEtaCards(BusResult result) {
    final etaFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ssZ");
    final timeFormat = DateFormat("HH:mm");
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: result.etas.asMap().entries.map((entry) {
        final index = entry.key;
        final eta = entry.value;

        DateTime? arrivalTime;
        String timeText = '--:--';
        String minutesText = '';
        Color minutesColor = Theme.of(context).colorScheme.onSurfaceVariant;

        try {
          arrivalTime = etaFormat.parse(eta.eta, true).toLocal();
          timeText = timeFormat.format(arrivalTime);
          final diff = arrivalTime.difference(now).inMinutes;
          if (diff <= 0) {
            minutesText = 'Arriving';
            minutesColor = Theme.of(context).colorScheme.primary;
          } else if (diff == 1) {
            minutesText = '1 min';
            minutesColor = Theme.of(context).colorScheme.error;
          } else if (diff <= 5) {
            minutesText = '$diff mins';
            minutesColor = Theme.of(context).colorScheme.tertiary;
          } else {
            minutesText = '$diff mins';
          }
        } catch (_) {
          // Keep defaults if parsing fails
        }

        final label = index == 0
            ? 'Next Bus'
            : index == 1
                ? '2nd Bus'
                : '${index + 1}th Bus';

        return Card(
          elevation: index == 0 ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: index == 0
                ? BorderSide.none
                : BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
          ),
          color: index == 0
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: index == 0
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: index == 0
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                      ),
                      Text(
                        timeText,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: index == 0
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                      : null,
                                ),
                      ),
                      if (eta.destination.isNotEmpty)
                        Text(
                          eta.destination,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: index == 0
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                        ),
                    ],
                  ),
                ),
                if (minutesText.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: minutesColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      minutesText,
                      style: TextStyle(
                        color: minutesColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
