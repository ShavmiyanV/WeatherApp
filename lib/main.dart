import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Weather',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5BC0F8),
          secondary: Color(0xFF90E0EF),
          surface: Color(0x33212121),
        ),
      ),
      home: const WeatherHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  static const _cacheKey = 'weather_cache_v1';

  final TextEditingController _indexController =
      TextEditingController(text: '194174B');

  bool _isLoading = false;
  bool _showingCached = false;
  String? _errorMessage;
  WeatherResult? _result;

  @override
  void initState() {
    super.initState();
    _restoreCachedResult();
  }

  Future<void> _restoreCachedResult() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null) return;

    try {
      final jsonMap = jsonDecode(cached) as Map<String, dynamic>;
      final cachedResult = WeatherResult.fromJson(jsonMap);
      if (!mounted) return;
      setState(() {
        _result = cachedResult;
        _showingCached = true;
      });
    } catch (_) {
      // Ignore corrupted cache values.
    }
  }

  Coordinates? _deriveCoordinates(String rawIndex) {
    final cleaned = rawIndex.trim().toUpperCase();
    if (cleaned.length < 4) return null;
    final firstTwo = int.tryParse(cleaned.substring(0, 2));
    final nextTwo = int.tryParse(cleaned.substring(2, 4));
    if (firstTwo == null || nextTwo == null) return null;
    final latitude = 5 + firstTwo / 10.0;
    final longitude = 79 + nextTwo / 10.0;
    return Coordinates(latitude: latitude, longitude: longitude);
  }

  Uri _buildRequestUri(Coordinates coordinates) {
    return Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': coordinates.latitude.toStringAsFixed(2),
      'longitude': coordinates.longitude.toStringAsFixed(2),
      'current_weather': 'true',
    });
  }

  Future<void> _fetchWeather() async {
    final index = _indexController.text.trim().toUpperCase();
    final coordinates = _deriveCoordinates(index);
    if (coordinates == null) {
      setState(() {
        _errorMessage = 'Your index must start with four digits (e.g., 194174B).';
      });
      return;
    }

    final uri = _buildRequestUri(coordinates);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final current = payload['current_weather'] as Map<String, dynamic>?;
      if (current == null) {
        throw Exception('Missing current weather data');
      }

      final result = WeatherResult(
        index: index,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        temperature: (current['temperature'] as num).toDouble(),
        windSpeed: (current['windspeed'] as num).toDouble(),
        weatherCode: (current['weathercode'] as num).round(),
        fetchedAt: DateTime.now(),
        requestUrl: uri.toString(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(result.toJson()));

      if (!mounted) return;
      setState(() {
        _result = result;
        _showingCached = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            '⚠️ No connection detected. We can’t load the weather right now. Check your internet and refresh.';
        _showingCached = _result != null;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final date =
        '${timestamp.year}-${twoDigits(timestamp.month)}-${twoDigits(timestamp.day)}';
    final time =
        '${twoDigits(timestamp.hour)}:${twoDigits(timestamp.minute)}:${twoDigits(timestamp.second)}';
    return '$date $time';
  }

  @override
  void dispose() {
    _indexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coordinates = _deriveCoordinates(_indexController.text);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1D2B64),
              Color(0xFF1BB2D6),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_result != null)
                        WeatherHero(
                          result: _result!,
                          isCached: _showingCached,
                        )
                      else
                        const WeatherPlaceholderHero(),
                      const SizedBox(height: 20),
                      GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _indexController,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(color: Colors.white),
                              cursorColor: Colors.white,
                              decoration: _roundedInputDecoration(
                                labelText: 'Student Index',
                                helper:
                                    'Enter your student index (e.g., 194174B)',
                              ),
                              onChanged: (_) => setState(() {
                                _errorMessage = null;
                              }),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _CoordinateCard(
                                    label: 'Latitude',
                                    value: coordinates?.latitude,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _CoordinateCard(
                                    label: 'Longitude',
                                    value: coordinates?.longitude,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _fetchWeather,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.15),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isLoading)
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation(
                                                  Colors.white),
                                        ),
                                      )
                                    else
                                      const Icon(Icons.cloud_sync_rounded),
                                    const SizedBox(width: 12),
                                    Text(_isLoading
                                        ? 'Fetching...'
                                        : 'Fetch Weather'),
                                  ],
                                ),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFFF7B7B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_result != null) ...[
                        const SizedBox(height: 20),
                        WeatherSummaryCard(
                          result: _result!,
                          lastUpdatedLabel:
                              _formatTimestamp(_result!.fetchedAt),
                          isCached: _showingCached,
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class Coordinates {
  const Coordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class WeatherResult {
  const WeatherResult({
    required this.index,
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    required this.fetchedAt,
    required this.requestUrl,
  });

  final String index;
  final double latitude;
  final double longitude;
  final double temperature;
  final double windSpeed;
  final int weatherCode;
  final DateTime fetchedAt;
  final String requestUrl;

  Map<String, dynamic> toJson() => {
        'index': index,
        'latitude': latitude,
        'longitude': longitude,
        'temperature': temperature,
        'windSpeed': windSpeed,
        'weatherCode': weatherCode,
        'fetchedAt': fetchedAt.toIso8601String(),
        'requestUrl': requestUrl,
      };

  factory WeatherResult.fromJson(Map<String, dynamic> json) => WeatherResult(
        index: json['index'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        temperature: (json['temperature'] as num).toDouble(),
        windSpeed: (json['windSpeed'] as num).toDouble(),
        weatherCode: json['weatherCode'] as int,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        requestUrl: json['requestUrl'] as String,
      );
}

class _CoordinateCard extends StatelessWidget {
  const _CoordinateCard({required this.label, this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            value != null ? value!.toStringAsFixed(2) : '--',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class WeatherSummaryCard extends StatelessWidget {
  const WeatherSummaryCard({
    super.key,
    required this.result,
    required this.lastUpdatedLabel,
    required this.isCached,
  });

  final WeatherResult result;
  final String lastUpdatedLabel;
  final bool isCached;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Conditions',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (isCached)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Cached'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _MetricTile(
                label: 'Temperature',
                value: '${result.temperature.toStringAsFixed(1)}°',
                icon: Icons.thermostat,
              ),
              _MetricTile(
                label: 'Wind',
                value: '${result.windSpeed.toStringAsFixed(1)} m/s',
                icon: Icons.air,
              ),
              _MetricTile(
                label: 'Weather Code',
                value: result.weatherCode.toString(),
                icon: Icons.numbers,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoRow(label: 'Index', value: result.index),
          _InfoRow(
            label: 'Coordinates',
            value:
                '${result.latitude.toStringAsFixed(2)}, ${result.longitude.toStringAsFixed(2)}',
          ),
          _InfoRow(label: 'Last update', value: lastUpdatedLabel),
          const SizedBox(height: 12),
          Text(
            result.requestUrl,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            offset: Offset(0, 10),
            blurRadius: 30,
          ),
        ],
      ),
      child: child,
    );
  }
}

class WeatherHero extends StatelessWidget {
  const WeatherHero({super.key, required this.result, required this.isCached});

  final WeatherResult result;
  final bool isCached;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.index,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${result.temperature.toStringAsFixed(0)}°',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Weather code ${result.weatherCode}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    Icons.cloud,
                    size: 64,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  if (isCached)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Cached data'),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Wind ${result.windSpeed.toStringAsFixed(1)} m/s · ${result.latitude.toStringAsFixed(2)}, ${result.longitude.toStringAsFixed(2)}',
            style:
                Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class WeatherPlaceholderHero extends StatelessWidget {
  const WeatherPlaceholderHero({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Weather',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your index and fetch to see the forecast.',
            style:
                Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text('Your last successful result will appear here.'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _roundedInputDecoration({
  required String labelText,
  required String helper,
}) {
  return InputDecoration(
    labelText: labelText,
    helperText: helper,
    labelStyle: const TextStyle(color: Colors.white70),
    helperStyle: const TextStyle(color: Colors.white54),
    filled: true,
    fillColor: Colors.white.withOpacity(0.08),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.white),
    ),
    helperMaxLines: 2,
  );
}
