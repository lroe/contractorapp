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
  double get _totalProjectCost => _summary.fold(0.0, (sum, item) => sum + (double.tryParse(item['cost'].toString()) ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Workforce Financials', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1E293B))),
          Text(widget.project.name, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
        ]),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProjectOverviewCard(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text('DAILY LEDGER', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 1.2)),
                    ],
                  ),
                ),
                Expanded(child: _buildSummaryList()),
              ],
            ),
    );
  }

  Widget _buildProjectOverviewCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text('Total Project Labor Cost', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text('₹ ${_totalProjectCost.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOverviewStat('Attendance', '$_totalManDays', 'Days'),
                Container(width: 1, height: 30, color: Colors.white.withOpacity(0.1)),
                _buildOverviewStat('Avg. Daily', '₹ ${(_totalProjectCost / (_summary.length > 0 ? _summary.length : 1)).toStringAsFixed(0)}', 'Cost'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Text(unit, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
          ],
        ),
      ],
    );
  }

  void _showDetails(String date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Audit: $date', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('Worker-wise cost breakdown', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                  const Icon(Icons.verified_user_outlined, color: Color(0xFF10B981)),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _apiService.getAttendanceDetail(widget.project.id, date),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final details = snapshot.data ?? [];
                  if (details.isEmpty) return Center(child: Text('No attendance recorded for this date', style: GoogleFonts.outfit(color: Colors.grey)));
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: details.length,
                    itemBuilder: (context, index) {
                      final w = details[index];
                      final status = w['status'] ?? 'absent';
                      final color = status == 'present' ? const Color(0xFF10B981) : status == 'half_day' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
                      final double rate = (double.tryParse(w['rate'].toString()) ?? 0.0);
                      final double dailyEarned = status == 'present' ? rate : (status == 'half_day' ? rate / 2 : 0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(Icons.person, color: color, size: 20)),
                          title: Text(w['worker_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          subtitle: Text(w['gang'] ?? 'Independent', style: const TextStyle(fontSize: 12)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹ ${dailyEarned.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                              Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryList() {
    if (_summary.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.event_busy, size: 64, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 16),
        Text('No attendance data available', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8))),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _summary.length,
      itemBuilder: (context, index) {
        final item = _summary[index];
        final date = item['date'];
        final cost = (double.tryParse(item['cost'].toString()) ?? 0.0);

        return GestureDetector(
          onTap: () => _showDetails(date),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(20), 
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF3B82F6), size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(date, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1E293B))),
                      Text('${item['count']} Man-days Logged', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹ ${cost.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1E293B))),
                    const Text('Daily Cost', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        );
      },
    );
  }
}
