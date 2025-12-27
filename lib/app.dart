import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/home_provider.dart';
import 'services/simulation_service.dart';
import 'services/voice_service.dart';
import 'views/dashboard_page.dart';

class SmartMaisonApp extends StatelessWidget {
  const SmartMaisonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SimulationService>(create: (_) => SimulationService()),

        Provider<VoiceService>(
          create: (_) => VoiceService(),
          dispose: (_, v) => v.dispose(),
        ),

        ChangeNotifierProvider<HomeProvider>(
          create: (ctx) => HomeProvider(
            service: Provider.of<SimulationService>(ctx, listen: false),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SmartHome',
        theme: ThemeData(useMaterial3: true),
        home: const DashboardPage(),
      ),
    );
  }
}
