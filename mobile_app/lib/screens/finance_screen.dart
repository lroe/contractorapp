import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class FinanceScreen extends StatefulWidget {
  final Project project;
  final User user;
  const FinanceScreen({super.key, required this.project, required this.user});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final txs = await _apiService.getTransactions(widget.project.id);
      setState(() {
        _transactions = txs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  double get _totalIncome => _transactions
      .where((t) => t['type'] == 'INCOME')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0.0));

  double get _totalExpense => _transactions
      .where((t) => t['type'] == 'EXPENSE')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0.0));

  void _showAddTransactionDialog(String type) {
    final amountController = TextEditingController();
    final remarksController = TextEditingController();
    String selectedCategory = type == 'INCOME' ? 'Payment' : 'Materials';
    final categories = type == 'INCOME' 
        ? ['Payment', 'Advance', 'Refund', 'Other']
        : ['Materials', 'Wages', 'Fuel', 'Transport', 'Food', 'Rent', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 20),
              Text('Add $type', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: type == 'INCOME' ? Colors.green : Colors.red)),
              const SizedBox(height: 24),
              
              Text('Amount', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(prefixText: '₹ ', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),

              Text('Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setModalState(() => selectedCategory = val!),
              ),
              const SizedBox(height: 16),

              Text('Remarks', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: remarksController,
                decoration: InputDecoration(hintText: 'e.g. Received from client', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (amountController.text.isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await _apiService.createTransaction({
                        'project_id': widget.project.id,
                        'type': type,
                        'category': selectedCategory,
                        'amount': double.parse(amountController.text),
                        'remarks': remarksController.text,
                        'created_by': widget.user.id,
                      });
                      _loadTransactions();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: type == 'INCOME' ? Colors.green : Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text('Save $type', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Finance & Cashbook', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        actions: [
          IconButton(onPressed: _loadTransactions, icon: const Icon(Icons.refresh, color: Color(0xFF1E293B))),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(),
                Expanded(child: _buildTransactionList()),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddTransactionDialog('EXPENSE'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), foregroundColor: Colors.red, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddTransactionDialog('INCOME'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.1), foregroundColor: Colors.green, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Income', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final balance = _totalIncome - _totalExpense;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Text('Available Balance', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
          const SizedBox(height: 8),
          Text('₹ ${balance.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Income', _totalIncome, Colors.greenAccent),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
              _buildSummaryItem('Expense', _totalExpense, Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        const SizedBox(height: 4),
        Text('₹ ${amount.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 16),
        Text('No transactions yet', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final bool isIncome = tx['type'] == 'INCOME';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: (isIncome ? Colors.green : Colors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.green : Colors.red, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx['category'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (tx['remarks'] != null && tx['remarks'].isNotEmpty)
                      Text(tx['remarks'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    Text(tx['transaction_date'], style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'} ₹${double.parse(tx['amount'].toString()).toStringAsFixed(0)}',
                style: GoogleFonts.outfit(color: isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}
