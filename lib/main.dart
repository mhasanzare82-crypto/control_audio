import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ControlAudioApp());
}

class ControlAudioApp extends StatelessWidget {
  const ControlAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'آزمایش کنترل صدا',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VolumeControlTestPage(),
    );
  }
}

class VolumeControlTestPage extends StatefulWidget {
  const VolumeControlTestPage({super.key});

  @override
  State<VolumeControlTestPage> createState() => _VolumeControlTestPageState();
}

class _VolumeControlTestPageState extends State<VolumeControlTestPage> {
  static const EventChannel _playbackChannel =
      EventChannel('control_audio/playback_events');
  static const MethodChannel _volumeChannel =
      MethodChannel('control_audio/volume');

  late final Stream<int> _playbackCountStream;
  double _volumePercent = 100;
  bool _volumeReady = false;
  bool _volumeError = false;

  @override
  void initState() {
    super.initState();
    _playbackCountStream = _playbackChannel
        .receiveBroadcastStream()
        .map((value) => (value as num).toInt());
    _loadVolume();
  }

  Future<void> _loadVolume() async {
    try {
      final state =
          await _volumeChannel.invokeMapMethod<String, dynamic>('getVolume');
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
      await _volumeChannel.invokeMethod<void>(
        'setVolume',
        {'percent': value.round()},
      );
    } on PlatformException {
      if (mounted) setState(() => _volumeError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('آزمایش کنترل صدا'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.volume_up, size: 64),
            const SizedBox(height: 16),
            Text(
              'اسلایدر آزمایشی صدای رسانه',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'میزان صدا: ${_volumePercent.round()}٪',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            Slider(
              value: _volumePercent.clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_volumePercent.round()}٪',
              onChanged: _volumeReady ? _setVolume : null,
            ),
            if (!_volumeReady && !_volumeError)
              const Center(child: CircularProgressIndicator()),
            if (_volumeError)
              const Text(
                'خواندن یا تغییر صدای رسانه با خطا مواجه شد.',
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            const Text(
              'هشدار مهم: این اسلایدر از API عادی اندروید برای تغییر ولوم مشترک رسانه استفاده می‌کند؛ '
              'بنابراین ممکن است صدای همه برنامه‌های در حال پخش را با هم تغییر دهد. '
              'این نسخه هنوز کنترل مستقل صدای هر برنامه نیست.',
              textAlign: TextAlign.center,
            ),
            const Divider(height: 40),
            Text(
              'تشخیص پخش هم‌زمان',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            StreamBuilder<int>(
              stream: _playbackCountStream,
              initialData: 0,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'امکان بررسی وضعیت پخش صدا وجود ندارد.',
                    textAlign: TextAlign.center,
                  );
                }
                final count = snapshot.data ?? 0;
                return Column(
                  children: [
                    Icon(
                      count > 0 ? Icons.graphic_eq : Icons.music_off,
                      size: 44,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تعداد نشست‌های پخش فعال: $count',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'برای آزمایش، دو تا چهار برنامه صوتی را هم‌زمان پخش کن. '
              'با حرکت اسلایدر بررسی کن آیا صدای همه آن‌ها با هم تغییر می‌کند یا نه. '
              'این شمارنده تعداد نشست‌ها را نشان می‌دهد، نه تعداد قطعی برنامه‌ها.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
