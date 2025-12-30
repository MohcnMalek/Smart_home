import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/home_provider.dart';
import 'services/simulation_service.dart';
import 'services/sqlite_cache_service.dart';
import 'services/voice_service.dart';
import 'views/dashboard_page.dart';

class SmartMaisonApp extends StatelessWidget {
  const SmartMaisonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ✅ SQLite DB
        Provider<SqliteCacheService>(create: (_) => SqliteCacheService()),

        // ✅ TTS service (pour parler après commande)
        Provider<VoiceService>(create: (_) => VoiceService()),

        // ✅ Simulation service (cache + SQLite)
        Provider<SimulationService>(
          create: (ctx) => SimulationService(
            db: Provider.of<SqliteCacheService>(ctx, listen: false),
          ),
        ),

        // ✅ HomeProvider (state + voice parsing + logs)
        ChangeNotifierProvider<HomeProvider>(
          create: (ctx) => HomeProvider(
            service: Provider.of<SimulationService>(ctx, listen: false),
            db: Provider.of<SqliteCacheService>(ctx, listen: false),
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
