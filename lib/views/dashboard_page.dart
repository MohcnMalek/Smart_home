// dashboard_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../providers/home_provider.dart';
import '../widgets/stylish_background.dart';
import 'room_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final stt.SpeechToText _speech;
  bool _listening = false;
  String? _voiceStatus;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().loadHome();
    });
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (_) {},
      onError: (e) {
        setState(() {
          _listening = false;
          _voiceStatus = '❌ Mic error: ${e.errorMsg}';
        });
      },
    );

    if (!available) {
      setState(() => _voiceStatus = '❌ Speech not available on this device');
      return;
    }

    setState(() {
      _listening = true;
      _voiceStatus = '🎙 Listening... (English commands)';
    });

    await _speech.listen(
      localeId: 'en_US',
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      onResult: (res) async {
        final text = res.recognizedWords;

        if (res.finalResult) {
          final ok = await context.read<HomeProvider>().runVoiceCommand(text);

          setState(() {
            _voiceStatus = ok ? "✅ Executed: $text" : "❌ Not understood: $text";
            _listening = false;
          });

          await _speech.stop();
        }
      },
    );
  }

  void _showVoiceHelp() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Voice commands (English)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 10),
              Text('• turn on living room light'),
              Text('• turn off bedroom ac'),
              Text('• switch on kitchen camera'),
              Text('• turn off garage door'),
              SizedBox(height: 10),
              Text(
                'Tip: speak clearly, short sentence.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Consumer<HomeProvider>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.error != null) {
              return Center(child: Text('Error: ${vm.error}'));
            }

            final totalDevices =
                vm.rooms.fold<int>(0, (sum, r) => sum + r.devices.length);
            final ratio = totalDevices == 0
                ? 0.25
                : (vm.activeDevicesCount / totalDevices).clamp(0.0, 1.0);

            return Stack(
              children: [
                StylishBackground(intensity: ratio, hueShift: 0.0),

                // Use CustomScrollView to avoid overflow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SmartHome',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF111111),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Dashboard',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _showVoiceHelp,
                                  icon: const Icon(Icons.help_outline_rounded),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _toggleListening,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 18,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _listening ? Icons.mic : Icons.mic_none_rounded,
                                      color: const Color(0xFF111111),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (_voiceStatus != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _voiceStatus!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111111),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Quick stats
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryCard(
                                    title: 'Temperature',
                                    value: '${vm.temperature.toStringAsFixed(1)}°C',
                                    icon: Icons.thermostat_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryCard(
                                    title: 'Energy (now)',
                                    value: '${vm.energy.toStringAsFixed(2)} kWh',
                                    icon: Icons.bolt_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _SummaryCard(
                              title: 'Active devices',
                              value: '${vm.activeDevicesCount}',
                              icon: Icons.toggle_on_outlined,
                            ),

                            const SizedBox(height: 12),

                            // ✅ Real-time usage graph (only)
                            EnergyRealtimeCard(
                              values: vm.energyHistory, // must exist in HomeProvider
                            ),

                            const SizedBox(height: 16),

                            const Text(
                              'Rooms',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111111),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 18),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final r = vm.rooms[i];

                              return InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => RoomPage(roomId: r.id)),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 18,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF2F3F7),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Image.asset(
                                          r.image,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.home_outlined,
                                            color: Color(0xFF111111),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        r.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF111111),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${r.devices.length} devices',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: vm.rooms.length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.05,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// -------------------------
// REAL-TIME USAGE CARD + GRAPH
// -------------------------
class EnergyRealtimeCard extends StatelessWidget {
  const EnergyRealtimeCard({
    super.key,
    required this.values,
    this.title = 'REAL-TIME USAGE',
    this.height = 130,
  });

  final List<double> values; // ex: vm.energyHistory
  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final safe = values.isEmpty ? const <double>[0] : values;
    final maxV = safe.reduce(math.max);
    final minV = safe.reduce(math.min);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.75)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: height,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  return CustomPaint(
                    painter: _EnergyLinePainter(
                      values: safe,
                      minV: minV,
                      range: range,
                      progress: t,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on devices ON/OFF',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyLinePainter extends CustomPainter {
  _EnergyLinePainter({
    required this.values,
    required this.minV,
    required this.range,
    required this.progress,
  });

  final List<double> values;
  final double minV;
  final double range;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // grid lines
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (values.length < 2) return;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF97316);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFF97316).withOpacity(0.14);

    final n = values.length;
    final dx = size.width / (n - 1);

    Offset p(int i) {
      final norm = ((values[i] - minV) / range).clamp(0.0, 1.0);
      final x = dx * i;
      final y = size.height - (norm * size.height);
      return Offset(x, y);
    }

    final path = Path()..moveTo(p(0).dx, p(0).dy);
    for (int i = 1; i < n; i++) {
      final pt = p(i);
      path.lineTo(pt.dx, pt.dy);
    }

    // animate
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLen = metrics.fold<double>(0, (a, m) => a + m.length);
    final drawLen = totalLen * progress;

    final animated = Path();
    double used = 0;
    for (final m in metrics) {
      final remain = drawLen - used;
      if (remain <= 0) break;
      final len = math.min(m.length, remain);
      animated.addPath(m.extractPath(0, len), Offset.zero);
      used += len;
    }

    final fill = Path.from(animated)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(animated, linePaint);
  }

  @override
  bool shouldRepaint(covariant _EnergyLinePainter old) {
    return old.values != values ||
        old.minV != minV ||
        old.range != range ||
        old.progress != progress;
  }
}

// -------------------------
// SUMMARY CARD
// -------------------------
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF111111)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
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
