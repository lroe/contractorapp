import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

class ProjectManagementScreen extends StatefulWidget {
  const ProjectManagementScreen({super.key});

  @override
  State<ProjectManagementScreen> createState() => _ProjectManagementScreenState();
}

class _ProjectManagementScreenState extends State<ProjectManagementScreen> {
  late Box<Project> _projectBox;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    _projectBox = Hive.box<Project>('projects');
    setState(() => _isLoading = false);
  }

  void _showCreateProjectDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Project'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Project Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final newProject = Project(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  status: 'active',
                );
                _projectBox.add(newProject);
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
        title: Text('My Projects', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _showCreateProjectDialog, icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder(
              valueListenable: _projectBox.listenable(),
              builder: (context, Box<Project> box, _) {
                if (box.isEmpty) return _buildEmptyState();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final project = box.getAt(index)!;
                    return _buildProjectCard(project);
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
          Icon(Icons.business_center_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No Projects Defined', style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showCreateProjectDialog,
            child: const Text('Add Project'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        title: Text(project.name, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text('Status: ${project.status}', style: const TextStyle(color: Colors.green)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Navigate to assign supervisor
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AssignSupervisorScreen(project: project)),
          );
        },
      ),
    );
  }
}

class AssignSupervisorScreen extends StatelessWidget {
  final Project project;
  const AssignSupervisorScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Supervisor', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project: ${project.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Text('Available Supervisors', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildSupervisorTile('Jeevan Kumar', 'Supervisor'),
                  _buildSupervisorTile('Akku Singh', 'Supervisor'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupervisorTile(String name, String role) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFF1F5F9)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(role),
        trailing: ElevatedButton(
          onPressed: () {},
          child: const Text('Assign'),
        ),
      ),
    );
  }
}
