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
      title: 'کنترل صدا',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PlaybackDetectionPage(),
    );
  }
}

class PlaybackDetectionPage extends StatefulWidget {
  const PlaybackDetectionPage({super.key});

  @override
  State<PlaybackDetectionPage> createState() => _PlaybackDetectionPageState();
}

class _PlaybackDetectionPageState extends State<PlaybackDetectionPage> {
  static const EventChannel _playbackChannel =
      EventChannel('control_audio/playback_events');

  late final Stream<int> _playbackCountStream;

  @override
  void initState() {
    super.initState();
    _playbackCountStream = _playbackChannel
        .receiveBroadcastStream()
        .map((value) => (value as num).toInt());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('کنترل صدا'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<int>(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    count > 0 ? Icons.graphic_eq : Icons.music_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    count > 0
                        ? 'پخش صدا فعال است'
                        : 'در انتظار پخش صدا...',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تعداد نشست‌های پخش فعال: $count',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'در این آزمایش، اندروید فقط فعالیت پخش را گزارش می‌کند؛ '
                    'نام و آیکون برنامه‌های دیگر برای برنامه‌های عادی مخفی است.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
