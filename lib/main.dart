import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() => runApp(const WeatherApp());

// ───────────────────────────── APP ROOT ─────────────────────────────

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.lightBlue,
      ),
      home: const HomePage(),
    );
  }
}

// ───────────────────────────── MODELS ─────────────────────────────

class Place {
  final String name;
  final String country;
  final double lat;
  final double lon;
  const Place(this.name, this.country, this.lat, this.lon);
}

class Hour {
  final DateTime time;
  final double temp;
  final int code;
  final int rain;
  Hour(this.time, this.temp, this.code, this.rain);
}

class Day {
  final DateTime date;
  final double max;
  final double min;
  final double uv;
  final int code;
  final int rain;
  final DateTime sunrise;
  final DateTime sunset;
  Day(
    this.date,
    this.max,
    this.min,
    this.uv,
    this.code,
    this.rain,
    this.sunrise,
    this.sunset,
  );
}

class Weather {
  final DateTime time;
  final double temp;
  final double feels;
  final double pressure;
  final double wind;
  final int windDir;
  final int humidity;
  final int code;
  final bool isDay;
  final List<Hour> hours;
  final List<Day> days;
  Weather({
    required this.time,
    required this.temp,
    required this.feels,
    required this.pressure,
    required this.wind,
    required this.windDir,
    required this.humidity,
    required this.code,
    required this.isDay,
    required this.hours,
    required this.days,
  });
}

// ───────────────────────────── SERVICE ─────────────────────────────

class WeatherService {
  static Future<Weather> fetch(Place p) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${p.lat}',
      'longitude': '${p.lon}',
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m',
      'hourly': 'temperature_2m,weather_code,precipitation_probability',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '7',
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Server error (${res.statusCode})');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;

    final c = j['current'];
    final h = j['hourly'];
    final d = j['daily'];

    final hourTimes = h['time'] as List;
    final hours = <Hour>[
      for (int i = 0; i < hourTimes.length; i++)
        Hour(
          DateTime.parse(hourTimes[i]),
          (h['temperature_2m'][i] as num).toDouble(),
          (h['weather_code'][i] as num).toInt(),
          ((h['precipitation_probability'][i]) as num?)?.toInt() ?? 0,
        ),
    ];

    final dayTimes = d['time'] as List;
    final days = <Day>[
      for (int i = 0; i < dayTimes.length; i++)
        Day(
          DateTime.parse(dayTimes[i]),
          (d['temperature_2m_max'][i] as num).toDouble(),
          (d['temperature_2m_min'][i] as num).toDouble(),
          ((d['uv_index_max'][i]) as num?)?.toDouble() ?? 0,
          (d['weather_code'][i] as num).toInt(),
          ((d['precipitation_probability_max'][i]) as num?)?.toInt() ?? 0,
          DateTime.parse(d['sunrise'][i]),
          DateTime.parse(d['sunset'][i]),
        ),
    ];

    return Weather(
      time: DateTime.parse(c['time']),
      temp: (c['temperature_2m'] as num).toDouble(),
      feels: (c['apparent_temperature'] as num).toDouble(),
      pressure: (c['pressure_msl'] as num).toDouble(),
      wind: (c['wind_speed_10m'] as num).toDouble(),
      windDir: (c['wind_direction_10m'] as num).toInt(),
      humidity: (c['relative_humidity_2m'] as num).toInt(),
      code: (c['weather_code'] as num).toInt(),
      isDay: (c['is_day'] as num).toInt() == 1,
      hours: hours,
      days: days,
    );
  }

  static Future<List<Place>> search(String query) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query,
      'count': '8',
      'language': 'en',
      'format': 'json',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Search failed (${res.statusCode})');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (j['results'] as List?) ?? [];
    return [
      for (final r in list)
        Place(
          r['name'] ?? '',
          [
            r['admin1'],
            r['country'],
          ].where((e) => e != null && e.toString().isNotEmpty).join(', '),
          (r['latitude'] as num).toDouble(),
          (r['longitude'] as num).toDouble(),
        ),
    ];
  }
}

// ───────────────────────────── HELPERS ─────────────────────────────

class Look {
  static String describe(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1) return 'Mainly clear';
    if (code == 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 55) return 'Drizzle';
    if (code == 56 || code == 57) return 'Freezing drizzle';
    if (code >= 61 && code <= 65) return 'Rain';
    if (code == 66 || code == 67) return 'Freezing rain';
    if (code >= 71 && code <= 75) return 'Snowfall';
    if (code == 77) return 'Snow grains';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code == 85 || code == 86) return 'Snow showers';
    if (code == 95) return 'Thunderstorm';
    if (code == 96 || code == 99) return 'Thunderstorm with hail';
    return 'Unknown';
  }

  static IconData icon(int code, bool isDay) {
    if (code == 0 || code == 1) {
      return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    }
    if (code == 2) return isDay ? Icons.wb_cloudy_rounded : Icons.cloud_queue;
    if (code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.blur_on_rounded;
    if (code >= 51 && code <= 57) return Icons.grain_rounded;
    if (code >= 61 && code <= 67) return Icons.water_drop_rounded;
    if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
    if (code >= 80 && code <= 82) return Icons.umbrella_rounded;
    if (code == 85 || code == 86) return Icons.ac_unit_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }

  static Color iconColor(int code, bool isDay) {
    if (code == 0 || code == 1) {
      return isDay ? const Color(0xFFFFD54F) : const Color(0xFFFFF59D);
    }
    if (code >= 95) return const Color(0xFFFFEE58);
    return Colors.white;
  }

  static List<Color> gradient(int code, bool isDay) {
    if ((code == 0 || code == 1) && isDay) {
      return const [Color(0xFF2193B0), Color(0xFF6DD5ED)];
    }
    if ((code == 0 || code == 1) && !isDay) {
      return const [Color(0xFF0F2027), Color(0xFF2C5364)];
    }
    if (code == 2 || code == 3) {
      return isDay
          ? const [Color(0xFF4B6CB7), Color(0xFF8FA3C8)]
          : const [Color(0xFF232B3E), Color(0xFF4A5670)];
    }
    if (code == 45 || code == 48) {
      return const [Color(0xFF757F9A), Color(0xFFA9B3C8)];
    }
    if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
      return const [Color(0xFF373B44), Color(0xFF4286F4)];
    }
    if (code >= 71 && code <= 77 || code == 85 || code == 86) {
      return const [Color(0xFF5B7DA8), Color(0xFF8FB4D9)];
    }
    if (code >= 95) {
      return const [Color(0xFF141E30), Color(0xFF35577D)];
    }
    return const [Color(0xFF2193B0), Color(0xFF6DD5ED)];
  }

  static String compass(int deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[(((deg + 22.5) % 360) / 45).floor()];
  }

  static String uvLabel(double uv) {
    if (uv < 3) return 'Low';
    if (uv < 6) return 'Moderate';
    if (uv < 8) return 'High';
    if (uv < 11) return 'Very high';
    return 'Extreme';
  }
}

// ───────────────────────────── HOME PAGE ─────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Place _place = const Place('Dhaka', 'Bangladesh', 23.8103, 90.4125);
  Weather? _weather;
  bool _loading = true;
  String? _error;
  bool _fahrenheit = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final w = await WeatherService.fetch(_place);
      if (!mounted) return;
      setState(() {
        _weather = w;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load weather.\nCheck your internet connection.';
        _loading = false;
      });
    }
  }

  Future<void> _openSearch() async {
    final result = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SearchSheet(),
    );
    if (result != null) {
      _place = result;
      _load();
    }
  }

  String _t(double c) {
    final v = _fahrenheit ? c * 9 / 5 + 32 : c;
    return '${v.round()}°';
  }

  @override
  Widget build(BuildContext context) {
    final w = _weather;
    final colors = w == null
        ? const [Color(0xFF2193B0), Color(0xFF6DD5ED)]
        : Look.gradient(w.code, w.isDay);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
        child: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_loading && _weather == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null && _weather == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 72,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final w = _weather!;
    final today = w.days.first;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _header(),
          const SizedBox(height: 8),
          _hero(w, today),
          const SizedBox(height: 20),
          _hourlyCard(w),
          const SizedBox(height: 14),
          _dailyCard(w),
          const SizedBox(height: 14),
          _detailsGrid(w, today),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Data: Open-Meteo.com   •   Updated ${DateFormat('h:mm a').format(w.time)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withAlpha(170),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header: city + search + unit toggle ──
  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.location_on_rounded, color: Colors.white),
        const SizedBox(width: 6),
        Expanded(
          child: InkWell(
            onTap: _openSearch,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (_place.country.isNotEmpty)
                  Text(
                    _place.country,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Search city',
          onPressed: _openSearch,
          icon: const Icon(Icons.search_rounded, color: Colors.white),
        ),
        GestureDetector(
          onTap: () => setState(() => _fahrenheit = !_fahrenheit),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _fahrenheit ? '°F' : '°C',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Hero: big icon + temperature ──
  Widget _hero(Weather w, Day today) {
    return Column(
      children: [
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, d MMMM').format(w.time),
          style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(210)),
        ),
        const SizedBox(height: 8),
        Icon(
          Look.icon(w.code, w.isDay),
          size: 110,
          color: Look.iconColor(w.code, w.isDay),
        ),
        Text(
          _t(w.temp),
          style: const TextStyle(
            fontSize: 96,
            fontWeight: FontWeight.w200,
            height: 1.0,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          Look.describe(w.code),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'H: ${_t(today.max)}   L: ${_t(today.min)}   •   Feels like ${_t(w.feels)}',
          style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(220)),
        ),
      ],
    );
  }

  // ── Hourly forecast (next 24 hours) ──
  Widget _hourlyCard(Weather w) {
    final now = DateTime(w.time.year, w.time.month, w.time.day, w.time.hour);
    int start = w.hours.indexWhere((h) => !h.time.isBefore(now));
    if (start < 0) start = 0;
    final end = (start + 24).clamp(0, w.hours.length);
    final list = w.hours.sublist(start, end);

    return GlassCard(
      title: 'HOURLY FORECAST',
      icon: Icons.access_time_rounded,
      child: SizedBox(
        height: 118,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 18),
          itemBuilder: (_, i) {
            final h = list[i];
            final isNow = i == 0;
            final dayFlag = h.time.hour >= 6 && h.time.hour < 19;
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isNow ? 'Now' : DateFormat('h a').format(h.time),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isNow ? FontWeight.w700 : FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
                Icon(
                  Look.icon(h.code, dayFlag),
                  size: 26,
                  color: Look.iconColor(h.code, dayFlag),
                ),
                Text(
                  h.rain > 0 ? '${h.rain}%' : ' ',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9BE7FF),
                  ),
                ),
                Text(
                  _t(h.temp),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 7-day forecast with temperature range bars ──
  Widget _dailyCard(Weather w) {
    final weekMin = w.days.map((d) => d.min).reduce((a, b) => a < b ? a : b);
    final weekMax = w.days.map((d) => d.max).reduce((a, b) => a > b ? a : b);
    final span = (weekMax - weekMin) == 0 ? 1 : (weekMax - weekMin);

    return GlassCard(
      title: '7-DAY FORECAST',
      icon: Icons.calendar_month_rounded,
      child: Column(
        children: [
          for (int i = 0; i < w.days.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      i == 0
                          ? 'Today'
                          : DateFormat('EEE').format(w.days[i].date),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(
                    Look.icon(w.days[i].code, true),
                    size: 24,
                    color: Look.iconColor(w.days[i].code, true),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      w.days[i].rain > 0 ? ' ${w.days[i].rain}%' : '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9BE7FF),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      _t(w.days[i].min),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withAlpha(190),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) {
                        final left =
                            (w.days[i].min - weekMin) / span * c.maxWidth;
                        final width =
                            ((w.days[i].max - w.days[i].min) /
                                    span *
                                    c.maxWidth)
                                .clamp(8.0, c.maxWidth);
                        return Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(50),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Positioned(
                              left: left.clamp(0.0, c.maxWidth - width),
                              child: Container(
                                height: 6,
                                width: width,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF80D8FF),
                                      Color(0xFFFFCA28),
                                      Color(0xFFFF7043),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      _t(w.days[i].max),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Detail tiles ──
  Widget _detailsGrid(Weather w, Day today) {
    final tiles = <_Tile>[
      _Tile(
        Icons.thermostat_rounded,
        'FEELS LIKE',
        _t(w.feels),
        w.feels > w.temp ? 'Feels warmer' : 'Feels cooler or same',
      ),
      _Tile(
        Icons.water_drop_outlined,
        'HUMIDITY',
        '${w.humidity}%',
        w.humidity > 70
            ? 'Quite humid'
            : w.humidity < 35
            ? 'Dry air'
            : 'Comfortable',
      ),
      _Tile(
        Icons.air_rounded,
        'WIND',
        '${w.wind.round()} km/h',
        'From ${Look.compass(w.windDir)}',
      ),
      _Tile(
        Icons.speed_rounded,
        'PRESSURE',
        '${w.pressure.round()} hPa',
        w.pressure < 1009 ? 'Low' : (w.pressure > 1022 ? 'High' : 'Normal'),
      ),
      _Tile(
        Icons.wb_sunny_outlined,
        'UV INDEX',
        today.uv.round().toString(),
        Look.uvLabel(today.uv),
      ),
      _Tile(Icons.umbrella_outlined, 'RAIN CHANCE', '${today.rain}%', 'Today'),
      _Tile(
        Icons.wb_twilight_rounded,
        'SUNRISE',
        DateFormat('h:mm a').format(today.sunrise),
        'Morning',
      ),
      _Tile(
        Icons.nights_stay_outlined,
        'SUNSET',
        DateFormat('h:mm a').format(today.sunset),
        'Evening',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        for (final t in tiles)
          GlassCard(
            title: t.title,
            icon: t.icon,
            child: Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t.value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.note,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Tile {
  final IconData icon;
  final String title;
  final String value;
  final String note;
  _Tile(this.icon, this.title, this.value, this.note);
}

// ───────────────────────────── GLASS CARD ─────────────────────────────

class GlassCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const GlassCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(36),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withAlpha(50)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: Colors.white.withAlpha(190)),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(190),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── SEARCH SHEET ─────────────────────────────

class SearchSheet extends StatefulWidget {
  const SearchSheet({super.key});

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final _controller = TextEditingController();
  List<Place> _results = [];
  bool _loading = false;
  String? _message;

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.length < 2) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final r = await WeatherService.search(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
        if (r.isEmpty) _message = 'No city found for "$q"';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Search failed. Check your internet.';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Color(0xFF1B2735),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search city (e.g. Dhaka, London)',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => _search(_controller.text),
                ),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final p = _results[i];
                  return ListTile(
                    leading: const Icon(Icons.location_city_rounded),
                    title: Text(p.name),
                    subtitle: Text(p.country),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
