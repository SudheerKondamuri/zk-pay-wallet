import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WalletState()),
      ],
      child: const ZKWalletApp(),
    ),
  );
}

class ZKWalletApp extends StatelessWidget {
  const ZKWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZK-Pay Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const WalletScreen(),
    );
  }
}

class WalletState extends ChangeNotifier {
  final String accountAddress = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
  final String apiBaseUrl = "http://localhost:4000";

  String balanceEth = "0.00";
  List<dynamic> intents = [];
  bool isLoading = false;
  Timer? _timer;

  WalletState() {
    refreshData();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      refreshData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refreshData() async {
    try {
      final balRes = await http.get(Uri.parse('$apiBaseUrl/deposits/$accountAddress'));
      if (balRes.statusCode == 200) {
        final data = json.decode(balRes.body);
        balanceEth = data['balanceEth'] ?? "0.00";
      }

      final intRes = await http.get(Uri.parse('$apiBaseUrl/intents?address=$accountAddress'));
      if (intRes.statusCode == 200) {
        final data = json.decode(intRes.body);
        intents = data['intents'] ?? [];
        intents.sort((a, b) => b['id'].toString().compareTo(a['id'].toString()));
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching data: $e");
    }
  }

  Future<bool> sendPayment(String toAddress, String amount) async {
    isLoading = true;
    notifyListeners();
    try {
      final amountDouble = double.tryParse(amount) ?? 0.0;
      final amountWei = BigInt.from(amountDouble * 1e18).toString();
      
      final res = await http.post(
        Uri.parse('$apiBaseUrl/intents'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fromAddress': accountAddress,
          'toAddress': toAddress,
          'amountWei': amountWei
        })
      );
      isLoading = false;
      refreshData();
      return res.statusCode == 201;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ZK-Pay Wallet',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BalanceCard(),
              const SizedBox(height: 32),
              const SendPaymentForm(),
              const SizedBox(height: 32),
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Consumer<WalletState>(
                  builder: (context, state, child) {
                    if (state.intents.isEmpty) {
                      return const Center(child: Text("No transactions yet.", style: TextStyle(color: Colors.white54)));
                    }
                    return ListView.builder(
                      itemCount: state.intents.length,
                      itemBuilder: (context, index) {
                        final tx = state.intents[index];
                        final amount = (double.parse(tx['amount_wei']) / 1e18).toStringAsFixed(4);
                        
                        Color statusColor = Colors.white54;
                        if (tx['status'] == 'pending') statusColor = Colors.orangeAccent;
                        if (tx['status'] == 'batched') statusColor = Colors.lightBlueAccent;
                        
                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueAccent.withOpacity(0.2),
                              child: const Icon(Icons.arrow_upward, color: Colors.blueAccent),
                            ),
                            title: Text('To: ${tx['to_address'].substring(0,8)}...'),
                            subtitle: Text('Status: ${tx['status']}', style: TextStyle(color: statusColor)),
                            trailing: Text(
                              '-$amount ETH',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          const Text(
            'L2 Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Consumer<WalletState>(
            builder: (context, state, child) {
              return Text(
                '${state.balanceEth} ETH',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              );
            }
          ),
        ],
      ),
    );
  }
}

class SendPaymentForm extends StatefulWidget {
  const SendPaymentForm({super.key});

  @override
  State<SendPaymentForm> createState() => _SendPaymentFormState();
}

class _SendPaymentFormState extends State<SendPaymentForm> {
  final _addressController = TextEditingController(text: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC");
  final _amountController = TextEditingController(text: "0.01");

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Send L2 Payment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Recipient Address',
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (ETH)',
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Consumer<WalletState>(
            builder: (context, state, child) {
              return ElevatedButton(
                onPressed: state.isLoading ? null : () async {
                  final success = await state.sendPayment(
                    _addressController.text,
                    _amountController.text,
                  );
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment intent submitted!')),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to submit intent.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: state.isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              );
            }
          )
        ],
      ),
    );
  }
}
