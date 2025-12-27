// views/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../providers/home_provider.dart';
import '../services/voice_service.dart';
import '../widgets/stylish_background.dart';
import '../widgets/energy_realtime_card.dart';
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
  String? _lastFinalCommand;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().loadHome();
    });
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() {
        _listening = false;
        _voiceStatus = '🎙 Stopped.';
      });
      return;
    }

    final available = await _speech.initialize(
      onStatus: (_) {},
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _voiceStatus = '❌ Mic error: ${e.errorMsg}';
        });
      },
    );

    if (!available) {
      if (!mounted) return;
      setState(() => _voiceStatus = '❌ Speech not available on this device');
      return;
    }

    if (!mounted) return;
    setState(() {
      _listening = true;
      _voiceStatus = '🎙 Listening... (English commands)';
    });

    await _speech.listen(
      localeId: 'en_US', // ✅ force English
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      onResult: (res) async {
        final text = res.recognizedWords.trim();
        if (text.isEmpty) return;

        // Partials: affiche le texte en live
        if (!res.finalResult) {
          if (!mounted) return;
          setState(() => _voiceStatus = '🎙 $text');
          return;
        }

        // Final: exécuter une seule fois
        if (_lastFinalCommand == text) return;
        _lastFinalCommand = text;

        // Stop mic avant traitement + TTS (important)
        await _speech.stop();

        final vm = context.read<HomeProvider>();
        final ok = await vm.runVoiceCommand(text);

        final feedback = (vm.lastVoiceFeedback?.trim().isNotEmpty ?? false)
            ? vm.lastVoiceFeedback!.trim()
            : (ok ? "Of course. Done." : "Sorry, I didn't understand.");

        // ✅ TTS
        try {
          final voice = context.read<VoiceService>();
          await voice.speak(feedback);
        } catch (_) {
          // ignore si TTS indisponible
        }

        if (!mounted) return;
        setState(() {
          _listening = false;
          _voiceStatus = feedback;
        });
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
              SizedBox(height: 12),
              Text('Tips', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('• Speak clearly, short sentence.'),
              Text('• Use "turn on" / "turn off".'),
              SizedBox(height: 6),
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
            final totalDevices =
                vm.rooms.fold<int>(0, (sum, r) => sum + r.devices.length);
            final ratio = totalDevices == 0
                ? 0.25
                : (vm.activeDevicesCount / totalDevices).clamp(0.0, 1.0);

            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.error != null) {
              return Center(child: Text('Error: ${vm.error}'));
            }

            return Stack(
              children: [
                StylishBackground(intensity: ratio, hueShift: 0.0),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                              title: 'Energy (real time)',
                              value: '${vm.energy.toStringAsFixed(2)} kW',
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

                      // ✅ Graphe énergie temps réel (widget séparé dans ton dossier widgets)
                      EnergyRealtimeCard(values: vm.energyHistory),

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

                      Expanded(
                        child: GridView.builder(
                          itemCount: vm.rooms.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.05,
                          ),
                          itemBuilder: (context, i) {
                            final r = vm.rooms[i];

                            return InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RoomPage(roomId: r.id),
                                  ),
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
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.home_outlined,
                                          color: Color(0xFF111111),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      r.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
          )
        ],
      ),
    );
  }
}
