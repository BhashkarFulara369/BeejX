import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../viewmodels/smart_ledger_viewmodel.dart';
import '../services/lekha_service.dart';
import '../services/supabase_service.dart';

class LekhaScreen extends StatelessWidget {
  const LekhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Providing ViewModel only for this screen subtree
    return ChangeNotifierProvider(
      create: (_) => SmartLedgerViewModel(),
      child: const _LekhaScreenContent(),
    );
  }
}

class _LekhaScreenContent extends StatefulWidget {
  const _LekhaScreenContent();

  @override
  State<_LekhaScreenContent> createState() => _LekhaScreenContentState();
}

class _LekhaScreenContentState extends State<_LekhaScreenContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LekhaService _lekhaService = LekhaService();
  final SupabaseService _supabase = SupabaseService();
  
  // Subsidy State
  Map<String, String>? _lastTransaction;
  bool _isVerifying = false;
  Future<List<Map<String, dynamic>>>? _schemesFuture;
  List<Map<String, dynamic>> _schemesList = [];
  Map<String, dynamic>? _selectedScheme;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSchemes();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  void _loadSchemes() {
     _schemesFuture = _supabase.fetchSchemes().then((data) {
       if (mounted) {
         setState(() {
           _schemesList = data;
           if (data.isNotEmpty) _selectedScheme = data[0];
         });
       }
       return data;
    });
  }
  
  void _applyForSubsidy() async {
    if (_selectedScheme == null) return;
    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(seconds: 2));
    final amount = double.tryParse(_selectedScheme!['amount'].toString()) ?? 0.0;
    final tx = await _lekhaService.createTransaction(_selectedScheme!['name'], amount);
    setState(() {
      _lastTransaction = tx;
      _isVerifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Consume ViewModel
    final viewModel = Provider.of<SmartLedgerViewModel>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text("Smart Ledger", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green[800],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green[800],
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: "My Expenses"),
            Tab(icon: Icon(Icons.account_balance), text: "Govt Subsidies"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExpensesTab(viewModel),
          _buildSubsidiesTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0 ? FloatingActionButton.extended(
        onPressed: viewModel.isScanning ? null : () async {
            await viewModel.scanBill();
            if (viewModel.extractedExpense != null && mounted) {
               _showConfirmationDialog(context, viewModel);
            } else if (viewModel.analysisError != null && mounted) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewModel.analysisError!)));
            }
        },
        icon: viewModel.isScanning 
           ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
           : const Icon(Icons.camera_alt),
        label: Text(viewModel.isScanning ? "Scanning..." : "Scan Bill"),
        backgroundColor: Colors.green[700],
      ) : null,
    );
  }

  void _showConfirmationDialog(BuildContext context, SmartLedgerViewModel viewModel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Extracted Data"),
        content: Text(viewModel.formattedExpenseString ?? "No Data"),
        actions: [
          TextButton(onPressed: () {
            viewModel.clearState();
            Navigator.pop(ctx);
          }, child: const Text("Discard", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
            viewModel.saveExpense(); 
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expense Saved!")));
          }, child: const Text("Save")),
        ]
      )
    );
  }

  Widget _buildExpensesTab(SmartLedgerViewModel vm) {
    if (vm.isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 16),
            Text("Analyzing Bill...", style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[700])),
          ],
        ),
      );
    }
    
    // Empty State for now (since we haven't implemented Fetching yet)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Icon(Icons.description_outlined, size: 80, color: Colors.grey[300]),
           const SizedBox(height: 16),
           Text("No expenses yet", style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[800], fontWeight: FontWeight.bold)),
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
             child: Text(
               "Tap 'Scan Bill' to instantly log your farming expenses using AI.",
               textAlign: TextAlign.center,
               style: GoogleFonts.outfit(color: Colors.grey),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildSubsidiesTab() {
     return Center(
       child: FutureBuilder<List<Map<String, dynamic>>>(
         future: _schemesFuture,
         builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("No Subsidies Found");
            
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final scheme = snapshot.data![index];
                return ListTile(
                  title: Text(scheme['name']),
                  subtitle: Text(scheme['description'] ?? ""),
                  trailing: Text(scheme['amount']?.toString() ?? ""),
                  onTap: () {
                    // Navigate to details
                  },
                );
              },
            );
         },
       ),
     );
  }
}
