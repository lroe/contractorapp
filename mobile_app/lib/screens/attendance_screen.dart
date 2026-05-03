import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  final Project project;
  final User user;
  const AttendanceScreen({super.key, required this.project, required this.user});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _gangs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGangs();
  }

  Future<void> _loadGangs() async {
    setState(() => _isLoading = true);
    try {
      final gangs = await _apiService.getGangs(widget.project.id);
      setState(() {
        _gangs = gangs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showCreateGangDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Create New Gang', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'e.g. Mason Gang 1'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              Navigator.pop(ctx);
              if (widget.user.organizationId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: User not associated with any organization')));
                return;
              }
              try {
                await _apiService.createGang({
                  'name': nameController.text,
                  'project_id': widget.project.id,
                  'supervisor_id': widget.user.id,
                  'organization_id': widget.user.organizationId,
                });
                _loadGangs();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
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
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Workforce Attendance', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1E293B))),
          Text(widget.project.name, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
        ]),
        actions: [
          IconButton(onPressed: _showCreateGangDialog, icon: const Icon(Icons.group_add_outlined, color: Color(0xFF1E293B))),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _gangs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _gangs.length,
                  itemBuilder: (context, i) => _buildGangCard(_gangs[i]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No Gangs Created Yet', style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showCreateGangDialog,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
            child: const Text('Create Your First Gang'),
          ),
        ],
      ),
    );
  }

  Widget _buildGangCard(dynamic gang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(gang['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        subtitle: const Text('Manage workers & mark attendance'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GangDetailScreen(gang: gang, project: widget.project, user: widget.user)),
        ),
      ),
    );
  }
}

class GangDetailScreen extends StatefulWidget {
  final dynamic gang;
  final Project project;
  final User user;
  const GangDetailScreen({super.key, required this.gang, required this.project, required this.user});

  @override
  State<GangDetailScreen> createState() => _GangDetailScreenState();
}

class _GangDetailScreenState extends State<GangDetailScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _workers = [];
  bool _isLoading = true;
  final Map<String, String> _attendanceMap = {}; // workerId -> status

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      final results = await Future.wait<dynamic>([
        _apiService.getWorkers(widget.gang['id']),
        _apiService.getGangAttendance(widget.gang['id'], dateStr),
      ]);
      
      final workers = results[0] as List<dynamic>;
      final existingAttendance = results[1] as List<dynamic>;

      setState(() {
        _workers = workers;
        
        // 1. Pre-fill from backend if exists
        for (var att in existingAttendance) {
          _attendanceMap[att['worker_id'].toString()] = att['status'];
        }

        // 2. Default others to 'present' only if they aren't already set locally
        for (var w in _workers) {
          final id = w['id'].toString();
          if (!_attendanceMap.containsKey(id)) {
            _attendanceMap[id] = 'present';
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAddWorkerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final rateController = TextEditingController(text: '500');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Worker', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Worker Name')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone (Optional)'), keyboardType: TextInputType.phone),
            TextField(controller: rateController, decoration: const InputDecoration(labelText: 'Daily Rate (₹)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              Navigator.pop(ctx);
              if (widget.user.organizationId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: User not associated with any organization')));
                return;
              }
              try {
                await _apiService.createWorker({
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'daily_rate': double.tryParse(rateController.text) ?? 0,
                  'project_id': widget.project.id,
                  'gang_id': widget.gang['id'],
                  'organization_id': widget.user.organizationId,
                });
                _loadWorkers();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
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
        title: Text(widget.gang['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        actions: [
          IconButton(onPressed: _showAddWorkerDialog, icon: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF1E293B))),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _workers.length,
                    itemBuilder: (context, i) => _buildWorkerRow(_workers[i]),
                  ),
                ),
                if (_workers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: ElevatedButton(
                      onPressed: _saveAttendance,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56), backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: Text('Submit Attendance', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildWorkerRow(dynamic worker) {
    String currentStatus = _attendanceMap[worker['id']] ?? 'present';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(worker['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusBtn('P', 'present', currentStatus, worker['id']),
            _buildStatusBtn('H', 'half_day', currentStatus, worker['id']),
            _buildStatusBtn('A', 'absent', currentStatus, worker['id']),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBtn(String label, String value, String currentStatus, String workerId) {
    bool isSelected = currentStatus == value;
    Color activeColor = value == 'present' ? Colors.green : (value == 'half_day' ? Colors.orange : Colors.red);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => setState(() => _attendanceMap[workerId] = value),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: isSelected ? activeColor : const Color(0xFFF1F5F9),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black54)),
        ),
      ),
    );
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      for (var entry in _attendanceMap.entries) {
        await _apiService.submitAttendance({
          'project_id': widget.project.id,
          'worker_id': entry.key,
          'gang_id': widget.gang['id'],
          'entry_date': dateStr,
          'status': entry.value,
          'marked_by': widget.user.id,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance submitted successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
