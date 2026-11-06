import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/movimientos_screen.dart';
import 'screens/recursos_screen.dart';
import 'screens/stats_screen.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _index = 0;

  ThemeData _tema() {
    const background = Color(0xFF1A1B26);
    const surface = Color(0xFF24283B);
    const primary = Color(0xFF7AA2F7);
    const text = Color(0xFFC0CAF5);
    const border = Color(0xFF3B4261);

    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'monospace',
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: Color(0xFF9ECE6A),
        surface: surface,
        error: Color(0xFFF7768E),
        onPrimary: background,
        onSurface: text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: border,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _pantalla() => switch (_index) {
    0 => const HomeScreen(),
    1 => const RecursosScreen(),
    2 => const MovimientosScreen(),
    _ => const StatsScreen(),
  };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _tema(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Administración',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'local •',
                  style: TextStyle(color: Color(0xFF9ECE6A)),
                ),
              ),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_index), child: _pantalla()),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) {
            setState(() {
              _index = value;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'recursos',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz),
              label: 'movimientos',
            ),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: 'stats'),
          ],
        ),
      ),
    );
  }
}
