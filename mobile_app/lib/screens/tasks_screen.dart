import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';

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

  bool get isOwner => widget.user.role == 'owner';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getProjectTasks(widget.project.id),
        _apiService.getWorkTypes(),
      ]);
      setState(() {
        _tasks = results[0];
        _workTypes = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showCreateTaskDialog() {
    final quantityController = TextEditingController();
    final unitController = TextEditingController();
    String? selectedWorkTypeId;
    String? selectedWorkTypeName;
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
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(height: 20),
              Text('Add New Task', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // Work Type Dropdown
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
                    items: _workTypes.map<DropdownMenuItem<String>>((wt) {
                      return DropdownMenuItem<String>(
                        value: wt['id'].toString(),
                        child: Text('${wt['name']} (${wt['unit'] ?? 'unit'})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedWorkTypeId = val;
                        selectedWorkTypeName = _workTypes.firstWhere((w) => w['id'].toString() == val)['name'];
                        unitController.text = _workTypes.firstWhere((w) => w['id'].toString() == val)['unit'] ?? '';
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Target Quantity
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

              // Deadline
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
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 12),
                      Text(
                        selectedDeadline != null
                            ? '${selectedDeadline!.day}/${selectedDeadline!.month}/${selectedDeadline!.year}'
                            : 'Pick a date',
                        style: TextStyle(color: selectedDeadline != null ? Colors.black : const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
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

  Future<void> _updateStatus(String taskId, String currentStatus) async {
    final statusOptions = ['pending', 'in_progress', 'completed'];
    final next = statusOptions[(statusOptions.indexOf(currentStatus) + 1) % statusOptions.length];
    try {
      await _apiService.updateTaskStatus(taskId, next);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tasks', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
            Text(widget.project.name, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
          ],
        ),
        actions: isOwner
            ? [
                Padding(
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
                ),
              ]
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.task_outlined, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text('No tasks yet', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Text(
            isOwner ? 'Tap "Add Task" to create the first task.' : 'No tasks have been assigned to this project yet.',
            style: const TextStyle(color: Color(0xFFCBD5E1)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(dynamic task) {
    final status = task['status'] ?? 'pending';
    final deadline = task['deadline'];

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'in_progress':
        statusColor = const Color(0xFF3B82F6);
        statusIcon = Icons.timelapse;
        break;
      case 'completed':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.radio_button_unchecked;
    }

    // Find work type name
    final workTypeId = task['work_type_id'];
    final workType = _workTypes.isNotEmpty
        ? _workTypes.firstWhere((w) => w['id'].toString() == workTypeId?.toString(), orElse: () => null)
        : null;
    final workTypeName = workType?['name'] ?? 'Task';
    final unit = task['unit'] ?? '';
    final targetQty = task['target_quantity'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workTypeName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Target: $targetQty $unit', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ],
                  ),
                ),
                // Status badge — tap to cycle (supervisors only, for now)
                GestureDetector(
                  onTap: !isOwner ? () => _updateStatus(task['id'].toString(), status) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Deadline row
          if (deadline != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text('Deadline: $deadline', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ],
              ),
            ),

          // Progress bar placeholder (in_progress = 50%, completed = 100%)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: LinearProgressIndicator(
              value: status == 'completed' ? 1.0 : status == 'in_progress' ? 0.5 : 0.0,
              backgroundColor: const Color(0xFFF1F5F9),
              color: statusColor,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
