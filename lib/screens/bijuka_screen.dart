import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../viewmodels/bijuka_viewmodel.dart';

class BijukaScreen extends StatelessWidget {
  const BijukaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BijukaViewModel(),
      child: const _BijukaScreenContent(),
    );
  }
}

class _BijukaScreenContent extends StatelessWidget {
  const _BijukaScreenContent();

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<BijukaViewModel>(context);

    if (vm.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.red));
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: Text("Bijuka Monitor (MVVM)", style: GoogleFonts.outfit(color: Colors.green[900], fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.green[900]),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: "Save Report",
            onPressed: () async {
              try {
                final path = await vm.exportCSV();
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Export Successful"),
                      content: Text("Saved at:\n$path"),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]
                    )
                  );
                }
              } catch (e) {
                 if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          )
        ],
      ),
      body: _buildBody(context, vm),
    );
  }

  Widget _buildBody(BuildContext context, BijukaViewModel vm) {
    if (vm.isLoading) return const Center(child: CircularProgressIndicator(color: Colors.green));
    if (!vm.isOnline) return _buildOfflineState();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text("Live Conditions", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildInfoCard("Temp", "${vm.currentTemp.toStringAsFixed(1)}°C", Icons.thermostat_rounded, const Color(0xFFFFCCBC), Colors.deepOrange)),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoCard("Humidity", "${vm.currentHumidity.toStringAsFixed(1)}%", Icons.water_drop_rounded, const Color(0xFFBBDEFB), Colors.blue)),
          ],
        ),
        const SizedBox(height: 12),
        _buildInfoCard("Soil pH", vm.currentPH.toStringAsFixed(1), Icons.grass, const Color(0xFFE1BEE7), Colors.purple, isWide: true),

        const SizedBox(height: 24),

        Text("Temperature Trends", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 12),
        Container(
          height: 250,
          padding: const EdgeInsets.only(right: 20, top: 20, bottom: 10, left: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 60,
              minX: vm.minX,
              maxX: vm.maxX,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 10,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 10,
                    getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
                    reservedSize: 30,
                  )
                ),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: vm.tempHistory.isEmpty ? [const FlSpot(0, 0)] : vm.tempHistory,
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(radius: 4, color: Colors.green, strokeWidth: 2, strokeColor: Colors.white);
                  }),
                  belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text("Device Control", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: Column(
            children: [
              _buildSwitchRow("Main Water Pump", vm.isMainPumpOn, (_) => vm.toggleMainPump()),
              const Divider(height: 30),
              _buildSwitchRow("Auxiliary Light", vm.isAuxLightOn, (_) => vm.toggleAuxLight()),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color bgColor, Color iconColor, {bool isWide = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.power_settings_new_rounded, color: value ? Colors.green : Colors.grey[400]),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 32,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: value ? Colors.green : Colors.grey[300],
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text("Waiting for Connection...", style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 18)),
          const SizedBox(height: 8),
          Text("Check your device power", style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14)),
        ],
      ),
    );
  }
}
