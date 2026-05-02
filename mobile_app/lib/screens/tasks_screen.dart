import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'report_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  final Project project;
  final User user;
  const TasksScreen({super.key, required this.project, required this.user});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _tasks = [];
  List<dynamic> _workTypes = [];
  bool _isLoading = true;
  // taskId -> last time the user viewed this task's reports
  Map<String, DateTime> _lastViewed = {};
  // taskId -> latest report created_at
  Map<String, DateTime?> _latestReport = {};

  bool get isOwner => widget.user.role == 'owner';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      final results = await Future.wait([
        _apiService.getProjectTasks(widget.project.id),
        _apiService.getWorkTypes(),
      ]);

      final tasks = results[0] as List<dynamic>;

      // For each task, fetch the latest report date to determine unseen status
      final latestReport = <String, DateTime?>{};
      await Future.wait(tasks.map((task) async {
        try {
          final taskId = task['id'].toString();
          final dprs = await _apiService.getTaskDPRs(taskId);
          if (dprs.isNotEmpty) {
            final latest = dprs.first['created_at'] as String?;
            latestReport[taskId] = latest != null ? DateTime.tryParse(latest) : null;
          } else {
            latestReport[taskId] = null;
          }
        } catch (_) {}
      }));

      // Load last-viewed timestamps from prefs
      final lastViewed = <String, DateTime>{};
      for (final task in tasks) {
        final taskId = task['id'].toString();
        final key = 'task_viewed_${widget.user.id}_$taskId';
        final stored = prefs.getString(key);
        if (stored != null) {
          lastViewed[taskId] = DateTime.parse(stored);
        }
      }

      setState(() {
        _tasks = tasks;
        _workTypes = results[1];
        _latestReport = latestReport;
        _lastViewed = lastViewed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  bool _hasUnseen(String taskId) {
    final latest = _latestReport[taskId];
    if (latest == null) return false;
    final viewed = _lastViewed[taskId];
    if (viewed == null) return true; // never viewed
    return latest.isAfter(viewed);
  }

  Future<void> _markViewed(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'task_viewed_${widget.user.id}_$taskId';
    final now = DateTime.now().toIso8601String();
    await prefs.setString(key, now);
    setState(() => _lastViewed[taskId] = DateTime.now());
  }

  void _showCreateTaskDialog() {
    final quantityController = TextEditingController();
    final unitController = TextEditingController();
    String? selectedWorkTypeId;
    DateTime? selectedDeadline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 20),
              Text('Add New Task', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Text('Work Type', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Select work type'),
                    value: selectedWorkTypeId,
                    items: _workTypes.map<DropdownMenuItem<String>>((wt) => DropdownMenuItem<String>(
                      value: wt['id'].toString(),
                      child: Text('${wt['name']} (${wt['unit'] ?? 'unit'})'),
                    )).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedWorkTypeId = val;
                        unitController.text = _workTypes.firstWhere((w) => w['id'].toString() == val)['unit'] ?? '';
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Target Quantity', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
              const SizedBox(height: 8),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 500',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixText: unitController.text,
                ),
              ),
              const SizedBox(height: 16),
              Text('Deadline (Optional)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setModalState(() => selectedDeadline = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 12),
                    Text(
                      selectedDeadline != null ? '${selectedDeadline!.day}/${selectedDeadline!.month}/${selectedDeadline!.year}' : 'Pick a date',
                      style: TextStyle(color: selectedDeadline != null ? Colors.black : const Color(0xFF94A3B8)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedWorkTypeId == null || quantityController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in work type and quantity')));
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      await _apiService.createTask({
                        'project_id': widget.project.id,
                        'work_type_id': selectedWorkTypeId,
                        'target_quantity': double.parse(quantityController.text),
                        'unit': unitController.text,
                        'deadline': selectedDeadline?.toIso8601String().split('T')[0],
                        'status': 'pending',
                        'created_by': widget.user.id,
                      });
                      _loadData();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Create Task', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(String taskId, String newStatus) async {
    try {
      await _apiService.updateTaskStatus(taskId, newStatus);
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tasks', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
          Text(widget.project.name, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
        ]),
        actions: isOwner
            ? [Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ElevatedButton.icon(
                  onPressed: _workTypes.isEmpty ? null : _showCreateTaskDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              )]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    itemBuilder: (ctx, i) => _buildTaskCard(_tasks[i]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.task_outlined, size: 64, color: Color(0xFFCBD5E1)),
      const SizedBox(height: 16),
      Text('No tasks yet', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
      const SizedBox(height: 8),
      Text(isOwner ? 'Tap "Add Task" to create the first task.' : 'No tasks assigned yet.', style: const TextStyle(color: Color(0xFFCBD5E1)), textAlign: TextAlign.center),
    ]));
  }

  Widget _buildTaskCard(dynamic task) {
    final status = task['status'] ?? 'pending';
    final deadline = task['deadline'];
    final taskId = task['id'].toString();
    final unseen = _hasUnseen(taskId);

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'in_progress': statusColor = const Color(0xFF3B82F6); statusIcon = Icons.timelapse; break;
      case 'completed':   statusColor = const Color(0xFF10B981); statusIcon = Icons.check_circle; break;
      default:            statusColor = const Color(0xFFF59E0B); statusIcon = Icons.radio_button_unchecked;
    }

    final workType = _workTypes.isNotEmpty
        ? _workTypes.firstWhere((w) => w['id'].toString() == task['work_type_id']?.toString(), orElse: () => null)
        : null;
    final workTypeName = workType?['name'] ?? 'Task';
    final unit = task['unit'] ?? '';
    final targetQty = task['target_quantity'] ?? 0;

    return GestureDetector(
      onTap: () async {
        await _markViewed(taskId);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task, workTypeName: workTypeName)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: unseen ? Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Stack(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                if (unseen)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                    ),
                  ),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(workTypeName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16))),
                  if (unseen) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(8)),
                      child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
                Text('Target: $targetQty $unit', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ])),
              PopupMenuButton<String>(
                tooltip: 'Update status',
                icon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 16, color: statusColor),
                  ]),
                ),
                onSelected: (s) => _updateStatus(taskId, s),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'pending', child: Text('⏳  Pending')),
                  const PopupMenuItem(value: 'in_progress', child: Text('🔵  In Progress')),
                  const PopupMenuItem(value: 'completed', child: Text('✅  Completed')),
                ],
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              if (deadline != null) ...[
                const Icon(Icons.calendar_today, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 5),
                Text('Deadline: $deadline', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const Spacer(),
              ] else const Spacer(),
              const Icon(Icons.chevron_right, size: 15, color: Color(0xFFCBD5E1)),
              const Text('View reports', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
            ]),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: LinearProgressIndicator(
              value: status == 'completed' ? 1.0 : status == 'in_progress' ? 0.5 : 0.0,
              backgroundColor: const Color(0xFFF1F5F9),
              color: statusColor,
              minHeight: 6,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Task Detail Screen ───────────────────────────────────────────────────────

class TaskDetailScreen extends StatelessWidget {
  final dynamic task;
  final String workTypeName;
  const TaskDetailScreen({super.key, required this.task, required this.workTypeName});

  @override
  Widget build(BuildContext context) {
    final status = task['status'] ?? 'pending';
    final statusColor = status == 'completed' ? const Color(0xFF10B981) : status == 'in_progress' ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(workTypeName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(workTypeName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            _infoRow(Icons.flag_outlined, 'Target', '${task['target_quantity']} ${task['unit'] ?? ''}'),
            if (task['deadline'] != null) _infoRow(Icons.calendar_today, 'Deadline', task['deadline']),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: status == 'completed' ? 1.0 : status == 'in_progress' ? 0.5 : 0.0,
              backgroundColor: const Color(0xFFF1F5F9),
              color: statusColor,
              minHeight: 8,
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('Linked Reports', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: ApiService().getTaskDPRs(task['id'].toString()),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final reports = snapshot.data ?? [];
              if (reports.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.description_outlined, size: 48, color: Color(0xFFCBD5E1)),
                const SizedBox(height: 12),
                Text('No reports linked yet.', style: TextStyle(color: Colors.grey[400])),
              ]));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, i) {
                  final report = reports[i] as Map<String, dynamic>;
                  final media = report['media'] as List<dynamic>? ?? [];
                  final hasMedia = media.isNotEmpty;
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => ReportDetailScreen(report: report))),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: hasMedia
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    'http://localhost:8000${media[0]['media_url']}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) => const Icon(Icons.description_outlined, color: Color(0xFF3B82F6), size: 18),
                                  ),
                                )
                              : const Icon(Icons.description_outlined, color: Color(0xFF3B82F6), size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(report['remarks'] ?? 'Report Submitted', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('📅 ${report['entry_date']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        ])),
                        const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 18),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}
