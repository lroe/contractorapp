import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AttendanceReportScreen extends StatefulWidget {
  final Project project;
  const AttendanceReportScreen({super.key, required this.project});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _rateController = TextEditingController(text: '500');
  List<dynamic> _summary = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getAttendanceSummary(widget.project.id);
      setState(() {
        _summary = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  double get _totalManDays => _summary.fold(0.0, (sum, item) => sum + (double.tryParse(item['count'].toString()) ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final dailyRate = double.tryParse(_rateController.text) ?? 0.0;
    final totalCost = _totalManDays * dailyRate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Attendance Report', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1E293B))),
          Text(widget.project.name, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
        ]),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildInputCard(totalCost),
                Expanded(child: _buildSummaryList()),
              ],
            ),
    );
  }

  Widget _buildInputCard(double totalCost) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Man-days', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('$_totalManDays Days', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total Labor Cost', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('₹ ${totalCost.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.currency_rupee, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('Daily Rate per Head:', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
              const Spacer(),
              SizedBox(
                width: 80,
                height: 36,
                child: TextField(
                  controller: _rateController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryList() {
    if (_summary.isEmpty) {
      return Center(child: Text('No attendance data available', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8))));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _summary.length,
      itemBuilder: (context, index) {
        final item = _summary[index];
        final date = item['date'];
        final count = item['count'];
        final cost = count * (double.tryParse(_rateController.text) ?? 0.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9))),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${item['count']} Man-days', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              Text(
                '₹ ${cost.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1E293B)),
              ),
            ],
          ),
        );
      },
    );
  }
}
