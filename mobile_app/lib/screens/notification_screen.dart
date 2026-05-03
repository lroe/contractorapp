import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'report_detail_screen.dart';
import 'inventory_screen.dart';

class NotificationScreen extends StatefulWidget {
  final User user;
  final Project? selectedProject;
  const NotificationScreen({super.key, required this.user, this.selectedProject});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      // Fetching more activity for the dedicated screen
      final data = await _apiService.getRecentActivity(
        projectId: widget.selectedProject?.id,
        userId: widget.user.id,
      );
      setState(() {
        _activities = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Activity Feed', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadActivities,
              child: _activities.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _activities.length,
                      itemBuilder: (context, index) => _buildActivityTile(_activities[index]),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_none_rounded, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text('No notifications yet', style: GoogleFonts.outfit(fontSize: 18, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildActivityTile(dynamic activity) {
    final type = activity['type'];
    final data = activity['data'];
    
    switch(type) {
      case 'dpr': return _buildDPRTile(data);
      case 'material_request': return _buildMaterialRequestTile(data);
      case 'attendance': return _buildAttendanceTile(data);
      default: return const SizedBox();
    }
  }

  Widget _buildDPRTile(dynamic report) {
    final media = report['media'] as List<dynamic>? ?? [];
    final hasMedia = media.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ReportDetailScreen(report: Map<String, dynamic>.from(report))),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _tileDecoration(),
        child: Row(
          children: [
            _tileIcon(
              hasMedia
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        'http://localhost:8000${media[0]['media_url']}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Icon(Icons.description_outlined, color: Color(0xFF3B82F6)),
                      ),
                    )
                  : const Icon(Icons.description_outlined, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Site Report', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(report['remarks'] ?? 'No remarks provided.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('📅 ${report['entry_date']}', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialRequestTile(dynamic req) {
    final status = req['status'];
    Color statusColor = status == 'pending' ? Colors.orange : (status == 'approved' ? Colors.blue : Colors.green);
    
    return GestureDetector(
      onTap: () {
        final projectId = req['project_id'];
        final project = Project(id: projectId, name: req['project_name'], status: 'active');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => InventoryScreen(project: project, user: widget.user)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _tileDecoration(),
        child: Row(
          children: [
            _tileIcon(Icon(Icons.shopping_cart_outlined, color: statusColor)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${req['material_name']} Requested', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${req['quantity']} ${req['unit']} for ${req['project_name']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTile(dynamic att) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _tileDecoration(),
      child: Row(
        children: [
          _tileIcon(const Icon(Icons.person_pin_outlined, color: Color(0xFF10B981))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance Marked', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${att['worker_name']} was ${att['status']} at ${att['project_name']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 4),
                Text('📅 ${att['entry_date']}', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _tileDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF1F5F9)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
    );
  }

  Widget _tileIcon(Widget child) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: Center(child: child),
    );
  }
}
