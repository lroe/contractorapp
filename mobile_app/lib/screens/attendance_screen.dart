import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Box<Gang> _gangBox;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    _gangBox = Hive.box<Gang>('gangs');
    setState(() => _isLoading = false);
  }

  void _showCreateGangDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Gang'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Gang Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final newGang = Gang(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  projectId: 'demo-project',
                );
                _gangBox.add(newGang);
                setState(() {});
                Navigator.pop(context);
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
        title: Text('Attendance & Gangs', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _showCreateGangDialog, icon: const Icon(Icons.group_add_outlined)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder(
              valueListenable: _gangBox.listenable(),
              builder: (context, Box<Gang> box, _) {
                if (box.isEmpty) return _buildEmptyState();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final gang = box.getAt(index)!;
                    return _buildGangCard(gang);
                  },
                );
              },
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

  Widget _buildGangCard(Gang gang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        title: Text(gang.name, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: const Text('Tap to manage workers'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GangDetailScreen(gang: gang)),
        ),
      ),
    );
  }
}

class GangDetailScreen extends StatefulWidget {
  final Gang gang;
  const GangDetailScreen({super.key, required this.gang});

  @override
  State<GangDetailScreen> createState() => _GangDetailScreenState();
}

class _GangDetailScreenState extends State<GangDetailScreen> {
  late Box<Worker> _workerBox;
  late Box<Attendance> _attendanceBox;
  List<Worker> _gangWorkers = [];

  @override
  void initState() {
    super.initState();
    _workerBox = Hive.box<Worker>('workers');
    _attendanceBox = Hive.box<Attendance>('attendance');
    _loadWorkers();
  }

  void _loadWorkers() {
    setState(() {
      _gangWorkers = _workerBox.values.where((w) => w.gangId == widget.gang.id).toList();
    });
  }

  void _addWorker() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Worker'),
        content: TextField(controller: nameController, decoration: const InputDecoration(hintText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final worker = Worker(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  gangId: widget.gang.id,
                );
                _workerBox.add(worker);
                _loadWorkers();
                Navigator.pop(context);
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
      appBar: AppBar(
        title: Text(widget.gang.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _addWorker, icon: const Icon(Icons.person_add))],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _gangWorkers.length,
              itemBuilder: (context, index) {
                final worker = _gangWorkers[index];
                return _buildWorkerRow(worker);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance Saved Locally')));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Attendance'),
            ),
          ),
        ],
      ),
    );
  }

  final Map<String, String> _attendanceMap = {}; // workerId -> status

  Widget _buildWorkerRow(Worker worker) {
    String currentStatus = _attendanceMap[worker.id] ?? 'present';
    return ListTile(
      title: Text(worker.name, style: GoogleFonts.outfit()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusBtn('P', 'present', currentStatus, worker),
          _buildStatusBtn('H', 'half_day', currentStatus, worker),
          _buildStatusBtn('A', 'absent', currentStatus, worker),
        ],
      ),
    );
  }

  Widget _buildStatusBtn(String label, String value, String currentStatus, Worker worker) {
    bool isSelected = currentStatus == value;
    Color activeColor = value == 'present' ? Colors.green : (value == 'half_day' ? Colors.orange : Colors.red);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _attendanceMap[worker.id] = value;
          });
        },
        child: CircleAvatar(
          radius: 18,
          backgroundColor: isSelected ? activeColor : Colors.grey[200],
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
