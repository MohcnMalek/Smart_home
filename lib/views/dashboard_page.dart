import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../providers/home_provider.dart';
import '../services/voice_service.dart';
import '../widgets/stylish_background.dart';
import '../widgets/energy_realtime_card.dart';
import 'room_page.dart';
import 'rooms_list_page.dart';

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

  Future<String?> _bestLocaleId() async {
    final locales = await _speech.locales();
    final sys = await _speech.systemLocale();

    // prefer English if available
    final en = locales
        .where((l) => (l.localeId).toLowerCase().startsWith('en'))
        .toList();
    if (en.isNotEmpty) return en.first.localeId;

    // fallback system
    if (sys != null) return sys.localeId;

    // fallback any
    if (locales.isNotEmpty) return locales.first.localeId;

    return null;
  }

  void _showVoiceHelp(HomeProvider vm) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.record_voice_over, color: Colors.indigo),
                  SizedBox(width: 10),
                  Text(
                    "Voice Guide (English)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "Tap an example to execute it:",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: vm.voiceHelpExamples.length,
                  itemBuilder: (context, i) {
                    final ex = vm.voiceHelpExamples[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.mic, color: Colors.indigo, size: 20),
                      title: Text(
                        ex['cmd'] ?? '',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "Action: ${ex['title'] ?? ''}",
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () async {
                        final cmd = ex['cmd'];
                        if (cmd == null || cmd.trim().isEmpty) return;

                        final ok = await vm.runVoiceCommand(cmd);

                        final feedback = (vm.lastVoiceFeedback?.trim().isNotEmpty ?? false)
                            ? vm.lastVoiceFeedback!.trim()
                            : (ok ? "Of course. Done." : "Sorry, I didn't understand.");

                        try {
                          await context.read<VoiceService>().speak(feedback);
                        } catch (e) {
                          debugPrint("TTS error: $e");
                        }

                        if (!mounted) return;
                        setState(() => _voiceStatus = feedback);

                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tips: Speak short. Use “turn on / turn off”.",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogs() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => const _LogsWidget(),
    );
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

    final localeId = await _bestLocaleId();
    if (localeId == null) {
      if (!mounted) return;
      setState(() => _voiceStatus = '❌ No language available');
      return;
    }

    if (!mounted) return;
    setState(() {
      _listening = true;
      _voiceStatus = '🎙 Listening...';
    });

    await _speech.listen(
      localeId: localeId,
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      onResult: (res) async {
        final text = res.recognizedWords.trim();
        if (text.isEmpty) return;

        if (!res.finalResult) {
          if (!mounted) return;
          setState(() => _voiceStatus = '🎙 $text');
          return;
        }

        if (_lastFinalCommand == text) return;
        _lastFinalCommand = text;

        await _speech.stop();

        final vm = context.read<HomeProvider>();
        final ok = await vm.runVoiceCommand(text);

        final feedback = (vm.lastVoiceFeedback?.trim().isNotEmpty ?? false)
            ? vm.lastVoiceFeedback!.trim()
            : (ok ? "Of course. Done." : "Sorry, I didn't understand.");

        try {
          await context.read<VoiceService>().speak(feedback);
        } catch (e) {
          debugPrint("TTS error: $e");
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(feedback), duration: const Duration(seconds: 2)),
          );
        }

        if (!mounted) return;
        setState(() {
          _listening = false;
          _voiceStatus = feedback;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text("SmartHome", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          Consumer<HomeProvider>(
            builder: (_, vm, __) => IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => _showVoiceHelp(vm),
            ),
          ),
          IconButton(icon: const Icon(Icons.history), onPressed: _showLogs),
        ],
      ),
      body: SafeArea(
        child: Consumer<HomeProvider>(
          builder: (context, vm, _) {
            final totalDevices =
                vm.rooms.fold<int>(0, (sum, r) => sum + r.devices.length);
            final ratio = totalDevices == 0
                ? 0.25
                : (vm.activeDevicesCount / totalDevices).clamp(0.0, 1.0);

            if (vm.isLoading) return const Center(child: CircularProgressIndicator());
            if (vm.error != null) return Center(child: Text('Error: ${vm.error}'));

            return Stack(
              children: [
                StylishBackground(intensity: ratio),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_voiceStatus != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Text(
                            _voiceStatus!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
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
                      EnergyRealtimeCard(values: vm.energyHistory),
                      const SizedBox(height: 16),
                      _SceneCard(
                        onTap: () async {
                          await vm.activateNightMode();
                          final msg = vm.lastVoiceFeedback ?? "Night mode activated.";
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
                          );
                          try {
                            await context.read<VoiceService>().speak(msg);
                          } catch (e) {
                            debugPrint("TTS error: $e");
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Rooms',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RoomsListPage()),
                            ),
                            child: const Text("See all"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: vm.rooms.length,
                          itemBuilder: (context, i) => _RoomCard(room: vm.rooms[i]),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleListening,
        backgroundColor: _listening ? Colors.red : Colors.indigo,
        label: Text(_listening ? "Listening..." : "Voice Command"),
        icon: Icon(_listening ? Icons.stop : Icons.mic),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SceneCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.indigo.shade500],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Quick Scene", style: TextStyle(color: Colors.white70)),
              SizedBox(height: 4),
              Text("Night Mode", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.indigo),
            child: const Text("Activate"),
          )
        ],
      ),
    );
  }
}

class _LogsWidget extends StatelessWidget {
  const _LogsWidget();

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<HomeProvider>().eventLogs;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            const Text("History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Divider(),
            Expanded(
              child: logs.isEmpty
                  ? const Center(child: Text("No events yet"))
                  : ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: const Icon(Icons.access_time, size: 18),
                        title: Text(logs[i], style: const TextStyle(fontSize: 14)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final dynamic room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RoomPage(roomId: room.id)),
      ),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(image: AssetImage(room.image), fit: BoxFit.cover),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black26,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                "${room.devices.length} devices",
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
