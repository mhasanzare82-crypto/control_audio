import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ControlAudioApp());
}

class ControlAudioApp extends StatelessWidget {
  const ControlAudioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'آزمایش شناسایی برنامه‌های صوتی',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
    home: const VolumeControlTestPage(),
  );
}

class VolumeControlTestPage extends StatefulWidget {
  const VolumeControlTestPage({super.key});
  @override
  State<VolumeControlTestPage> createState() => _VolumeControlTestPageState();
}

class _VolumeControlTestPageState extends State<VolumeControlTestPage> {
  static const EventChannel _playbackChannel = EventChannel('control_audio/playback_events');
  static const MethodChannel _volumeChannel = MethodChannel('control_audio/volume');
  late final Stream<Map<String, dynamic>> _playbackStream;
  double _volumePercent = 100;
  bool _volumeReady = false;
  bool _volumeError = false;

  @override
  void initState() {
    super.initState();
    _playbackStream = _playbackChannel.receiveBroadcastStream().map(
      (value) => Map<String, dynamic>.from(value as Map),
    );
    _loadVolume();
  }

  Future<void> _loadVolume() async {
    try {
      final state = await _volumeChannel.invokeMapMethod<String, dynamic>('getVolume');
      if (!mounted || state == null) return;
      final current = (state['current'] as num).toDouble();
      final maximum = (state['maximum'] as num).toDouble();
      setState(() {
        _volumePercent = maximum <= 0 ? 0 : (current / maximum * 100).clamp(0, 100);
        _volumeReady = true;
      });
    } on PlatformException {
      if (mounted) setState(() => _volumeError = true);
    }
  }

  Future<void> _setVolume(double value) async {
    setState(() => _volumePercent = value);
    try {
      await _volumeChannel.invokeMethod<void>('setVolume', {'percent': value.round()});
    } on PlatformException {
      if (mounted) setState(() => _volumeError = true);
    }
  }

  String _playerStateLabel(dynamic rawState) {
    switch (rawState) {
      case 2: return 'در حال پخش';
      case 3: return 'مکث‌شده';
      case 4: return 'متوقف‌شده';
      case 1: return 'آماده';
      default: return 'نامشخص';
    }
  }

  String _uidStatusLabel(dynamic status) {
    switch (status) {
      case 'available': return 'شناسه برنامه در دسترس است';
      case 'anonymized_or_unavailable': return 'اندروید شناسه را ناشناس کرده است';
      case 'method_hidden': return 'روش خواندن شناسه در دسترس نیست';
      case 'blocked_by_android': return 'اندروید دسترسی به شناسه را مسدود کرد';
      default: return 'خواندن شناسه ممکن نشد';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('آزمایش شناسایی برنامه‌های صوتی'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.graphic_eq, size: 56),
            const SizedBox(height: 12),
            Text('آزمایش تشخیص نام برنامه‌ها',
              style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'دو یا سه برنامه صوتی را هم‌زمان پخش کن و چند ثانیه صبر کن. '
              'این نسخه فقط بررسی می‌کند آیا اندروید شناسه و نام هر برنامه را نشان می‌دهد یا نه.',
              textAlign: TextAlign.center,
            ),
            const Divider(height: 32),
            Text('صدای مشترک رسانه: ' + _volumePercent.round().toString() + '٪',
              style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            Slider(
              value: _volumePercent.clamp(0, 100), min: 0, max: 100, divisions: 100,
              label: _volumePercent.round().toString() + '٪',
              onChanged: _volumeReady ? _setVolume : null,
            ),
            if (!_volumeReady && !_volumeError) const Center(child: CircularProgressIndicator()),
            if (_volumeError)
              const Text('خواندن یا تغییر صدای رسانه با خطا مواجه شد.', textAlign: TextAlign.center),
            const Text(
              'این اسلایدر همچنان ولوم مشترک رسانه را تغییر می‌دهد و برای هر برنامه مستقل نیست.',
              textAlign: TextAlign.center,
            ),
            const Divider(height: 32),
            StreamBuilder<Map<String, dynamic>>(
              stream: _playbackStream,
              initialData: const {'count': 0, 'players': <dynamic>[]},
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('دریافت اطلاعات نشست‌های صوتی با خطا مواجه شد.',
                    textAlign: TextAlign.center);
                }
                final data = snapshot.data ?? const {'count': 0, 'players': <dynamic>[]};
                final players = (data['players'] as List<dynamic>? ?? [])
                  .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('نشست‌های صوتی شناسایی‌شده: ' + (data['count'] ?? 0).toString(),
                      style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    if (players.isEmpty)
                      const Text('فعلاً نشست صوتی فعالی شناسایی نشده است.', textAlign: TextAlign.center),
                    for (final player in players)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (player['appLabel'] as String?)?.isNotEmpty == true
                                  ? player['appLabel'] as String
                                  : 'برنامه شماره ' + player['index'].toString() + ' — نام برنامه در دسترس نیست',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text('وضعیت: ' + _playerStateLabel(player['playerState'])),
                              Text(_uidStatusLabel(player['uidStatus'])),
                              if ((player['packageNames'] as List<dynamic>?)?.isNotEmpty == true)
                                Text('شناسه بسته: ' + (player['packageNames'] as List<dynamic>).join(', ')),
                              Text('UID آزمایشی: ' + (player['uid'] ?? -1).toString()),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'اگر نام برنامه‌ها نمایش داده نشد، نتیجه آزمایش این است که اندروید شناسه نشست‌ها را '
                      'برای این برنامه عادی پنهان یا ناشناس کرده است. در این آزمایش هیچ مجوز '
                      'Notification Access یا دسترسی ویژه‌ای فعال نمی‌شود.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
