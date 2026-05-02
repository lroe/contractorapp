import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen view for a single DPR report entry.
class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  const ReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final remarks = report['remarks'] as String? ?? '';
    final date = report['entry_date'] as String? ?? '';
    final createdAt = report['created_at'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Site Report', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            _sectionCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.description_outlined, color: Color(0xFF3B82F6), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Progress Report', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        _metaRow(Icons.calendar_today, 'Date: $date'),
                        if (createdAt.isNotEmpty)
                          _metaRow(Icons.access_time, 'Submitted: ${_formatTimestamp(createdAt)}'),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Text('SUBMITTED', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Linked task badge (if any)
            if (report['linked_task_id'] != null) ...[
              _sectionCard(
                child: Row(
                  children: [
                    const Icon(Icons.link, color: Color(0xFF3B82F6), size: 18),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('This report is linked to a task', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600))),
                  ],
                ),
                color: const Color(0xFF3B82F6).withOpacity(0.06),
              ),
              const SizedBox(height: 16),
            ],

            // Remarks
            _sectionHeader('📝 Remarks / Updates'),
            const SizedBox(height: 10),
            _sectionCard(
              child: remarks.isEmpty
                  ? const Text('No remarks provided.', style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic))
                  : Text(remarks, style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF1E293B))),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1E293B)));
  }

  Widget _sectionCard({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: color == null ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))] : null,
        border: color != null ? Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)) : null,
      ),
      child: child,
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ],
      ),
    );
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
