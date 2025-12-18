import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  bool _isLoading = true;
  List<dynamic> _marketData = [];
  String _selectedState = "Maharashtra";
  String _selectedCrop = "Tomato";

  // Mock data for the graph (Price History)
  final List<FlSpot> _priceHistory = [
    const FlSpot(0, 2000),
    const FlSpot(1, 2100),
    const FlSpot(2, 1950),
    const FlSpot(3, 2200),
    const FlSpot(4, 2400),
    const FlSpot(5, 2350),
    const FlSpot(6, 2500),
  ];

  @override
  void initState() {
    super.initState();
    _fetchMarketData();
  }

  Future<void> _fetchMarketData() async {
    setState(() => _isLoading = true);
    try {
      // Use the local IP that works for the user
      // Production URL (HTTPS required for Play Store)
      final url = Uri.parse('https://beejx-backend-default.hf.space/api/v1/mandi?state=$_selectedState&crop=$_selectedCrop');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _marketData = data['data']; // Assuming API returns { "data": [...] }
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load market data");
      }
    } catch (e) {
      print("Market API Error: $e");
      setState(() {
        _isLoading = false;
        // Fallback Mock Data if API fails
        _marketData = [
          {"market": "Nagpur Mandi", "price": "₹2,500/Q", "trend": "up"},
          {"market": "Pune APMC", "price": "₹2,450/Q", "trend": "down"},
          {"market": "Nashik Mandi", "price": "₹2,400/Q", "trend": "stable"},
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          "Market Insights",
          style: GoogleFonts.outfit(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedState,
                        isExpanded: true,
                        items: ["Maharashtra", "Punjab", "Karnataka"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.outfit())))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedState = val);
                            _fetchMarketData();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCrop,
                        isExpanded: true,
                        items: ["Tomato", "Onion", "Wheat", "Rice"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.outfit())))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCrop = val);
                            _fetchMarketData();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Price Trend Graph
            Text(
              "Price Trend (Last 7 Days)",
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _priceHistory,
                      isCurved: true,
                      color: const Color(0xFF2E7D32),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Live Mandi Prices
            Text(
              "Live Mandi Prices",
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _marketData.length,
                    itemBuilder: (context, index) {
                      final item = _marketData[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['market'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "Updated: Today",
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item['price'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      item['trend'] == 'up'
                                          ? Icons.trending_up
                                          : item['trend'] == 'down'
                                              ? Icons.trending_down
                                              : Icons.trending_flat,
                                      size: 14,
                                      color: item['trend'] == 'up'
                                          ? Colors.green
                                          : item['trend'] == 'down'
                                              ? Colors.red
                                              : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item['trend'] == 'up'
                                          ? "+2.5%"
                                          : item['trend'] == 'down'
                                              ? "-1.2%"
                                              : "0%",
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: item['trend'] == 'up'
                                            ? Colors.green
                                            : item['trend'] == 'down'
                                                ? Colors.red
                                                : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
