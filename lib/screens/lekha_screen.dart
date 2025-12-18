import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/lekha_service.dart';
import '../services/supabase_service.dart'; // Import Supabase Service

class LekhaScreen extends StatefulWidget {
  const LekhaScreen({super.key});

  @override
  State<LekhaScreen> createState() => _LekhaScreenState();
}

class _LekhaScreenState extends State<LekhaScreen> {
  final LekhaService _lekhaService = LekhaService();
  final SupabaseService _supabase = SupabaseService();
  final User? user = FirebaseAuth.instance.currentUser;
  
  Map<String, String>? _lastTransaction;
  bool _isVerifying = false;
  
  // Dynamic Schemes
  Future<List<Map<String, dynamic>>>? _schemesFuture;
  List<Map<String, dynamic>> _schemesList = [];
  Map<String, dynamic>? _selectedScheme; // Use object instead of index for safety
  
  @override
  void initState() {
    super.initState();
    _loadSchemes();
  }

  void _loadSchemes() {
    _schemesFuture = _supabase.fetchSchemes().then((data) {
       if (mounted) {
         setState(() {
           _schemesList = data;
           if (data.isNotEmpty) {
             _selectedScheme = data[0];
           }
         });
       }
       return data;
    });
  }

  void _applyForSubsidy() async {
    if (_selectedScheme == null) return;

    setState(() => _isVerifying = true);
    
    // Simulate Network/Blockchain Delay
    await Future.delayed(const Duration(seconds: 2));

    // Convert amount safely (Supabase numeric comes as generic number)
    final amount = double.tryParse(_selectedScheme!['amount'].toString()) ?? 0.0;
    
    final tx = await _lekhaService.createTransaction(_selectedScheme!['name'], amount);

    setState(() {
      _lastTransaction = tx;
      _isVerifying = false;
    });
  }
  
  Future<void> _discoverNewSchemes(BuildContext context) async {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("AI Agent is scanning the web for latest schemes... 🤖")),
      );
      
      setState(() => _isVerifying = true); // Reuse spinner or add specific one
      
      final newSchemes = await _supabase.discoverSchemes("Uttarakhand");
      
      if (!mounted) return; // Prevent crash if user left screen

      setState(() => _isVerifying = false);

      if (newSchemes.isNotEmpty) {
        if (!mounted) return;
        setState(() {
           _schemesList = newSchemes;
           _selectedScheme = newSchemes[0];
        });
        
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("AI Discovery Complete ✨"),
            content: Text("Found ${newSchemes.length} active schemes via Gemini Agent.\nThe list has been updated."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Awesome"))
            ],
          )
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("AI couldn't find new schemes. Try again later.")),
        );
      }
  }

  Future<void> _openOfficialPortal() async {
    final Uri url = Uri.parse('https://dbt.uk.gov.in/');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text("Lekha Pay (लेखा) 🔐", style: GoogleFonts.outfit(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.purple), // AI Icon
            tooltip: "Ask AI to Find New Schemes",
            onPressed: () => _discoverNewSchemes(context),
          ),
          IconButton(
            icon: const Icon(Icons.language, color: Colors.blue),
            tooltip: "Official DBT Portal",
            onPressed: _openOfficialPortal,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue[800]!, Colors.blue[600]!]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10)],
              ),
              child: Column(
                children: [
                   const Icon(Icons.verified_user_outlined, size: 50, color: Colors.white),
                   const SizedBox(height: 16),
                   Text(
                     "Uttarakhand DBT Ledger",
                     style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     "Blockchain-backed proof for ${user?.displayName ?? 'Farmer'}",
                     textAlign: TextAlign.center,
                     style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                   ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Action Card (Dynamic Loading)
            if (_lastTransaction == null)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _schemesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text("Error loading schemes: ${snapshot.error}"));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                       return const Center(child: Text("No schemes available currently."));
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Select Government Scheme", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14)),
                        const SizedBox(height: 8),
                        
                        // Dropdown for DYNAMIC Schemes
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!)
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              hint: Text("Choose a scheme...", style: GoogleFonts.outfit()),
                              value: _selectedScheme,
                              isExpanded: true,
                              items: _schemesList.map((scheme) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: scheme,
                                  child: Text(scheme['name'], style: GoogleFonts.outfit(color: Colors.black87), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                 if(val != null) setState(() => _selectedScheme = val);
                              },
                            ),
                          ),
                        ),
                        
                        const Divider(height: 30),
                        
                        if (_selectedScheme != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Benefit Amount", style: GoogleFonts.outfit(fontSize: 16)),
                            Text("₹${_selectedScheme!['amount']}", style: GoogleFonts.outfit(fontSize: 18, color: Colors.green[700], fontWeight: FontWeight.bold)),
                          ],
                        ),

                        const SizedBox(height: 20),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: (_isVerifying || _selectedScheme == null) ? null : _applyForSubsidy,
                            icon: _isVerifying 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.fingerprint, color: Colors.white),
                            label: Text(_isVerifying ? "Hashing on Chain..." : "Claim & Verify", style: GoogleFonts.outfit(color: Colors.white)),
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
            ),
            
            // Proof Card (Result) - Unchanged Logic
            if (_lastTransaction != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 20)],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, size: 60, color: Colors.green),
                    const SizedBox(height: 16),
                    Text("Subsidy Claim Verified!", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[800])),
                    const SizedBox(height: 8),
                    Text("Recorded on Immutable Ledger.", style: GoogleFonts.outfit(color: Colors.grey)),
                    const Divider(height: 30),
                    
                    // QR Code
                    QrImageView(
                      data: _lastTransaction!['hash']!,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("BLOCKCHAIN HASH", style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            _lastTransaction!['hash']!,
                            style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Text("PREVIOUS BLOCK", style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                          Text(
                            _lastTransaction!['previousHash']!.substring(0, 20) + "...",
                            style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

