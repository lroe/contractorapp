import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'package:uuid/uuid.dart';
import 'documents_screen.dart';

class ProjectManagementScreen extends StatefulWidget {
  final User? user; // Null if just viewing projects
  final Function(Project)? onProjectTap;
  const ProjectManagementScreen({super.key, this.user, this.onProjectTap});

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
    await _syncProjects();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _syncProjects() async {
    if (widget.user == null) return;
    try {
      final remoteProjects = await ApiService().getProjects(widget.user!.organizationId!, userId: widget.user!.id);
      await _projectBox.clear();
      await _projectBox.addAll(remoteProjects);
    } catch (e) {
      debugPrint('Error syncing projects: $e');
    }
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
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                try {
                  // Create on backend first to get a valid UUID
                  final createdProject = await ApiService().createProject(
                    nameController.text,
                    widget.user!.organizationId!,
                  );
                  _projectBox.add(createdProject);
                  if (mounted) setState(() {});
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to sync project with backend: $e')),
                  );
                }
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.description_outlined, color: Colors.blueAccent),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentsScreen(
                      projectId: project.id,
                      projectName: project.name,
                      userId: widget.user?.id ?? '',
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                project.delete();
                setState(() {});
              },
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          if (widget.onProjectTap != null) {
            widget.onProjectTap!(project);
            return;
          }
          // Default: Navigate to assign supervisor
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AssignSupervisorScreen(project: project, organizationId: widget.user!.organizationId!)),
          );
        },
      ),
    );
  }
}

class AssignSupervisorScreen extends StatefulWidget {
  final Project project;
  final String organizationId;
  const AssignSupervisorScreen({super.key, required this.project, required this.organizationId});

  @override
  State<AssignSupervisorScreen> createState() => _AssignSupervisorScreenState();
}

class _AssignSupervisorScreenState extends State<AssignSupervisorScreen> {
  final ApiService _apiService = ApiService();
  List<User> _allSupervisors = [];
  List<User> _assignedSupervisors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.listUsers(role: 'supervisor', organizationId: widget.organizationId),
        _apiService.getProjectSupervisors(widget.project.id),
      ]);
      setState(() {
        _allSupervisors = results[0];
        _assignedSupervisors = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  bool _isAssigned(String userId) {
    return _assignedSupervisors.any((u) => u.id == userId);
  }

  Future<void> _toggleAssignment(User supervisor) async {
    final assigned = _isAssigned(supervisor.id);
    try {
      if (assigned) {
        await _apiService.unassignSupervisor(widget.project.id, supervisor.id);
      } else {
        await _apiService.assignSupervisor(widget.project.id, supervisor.id);
      }
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(assigned ? 'Removed ${supervisor.name}' : 'Assigned ${supervisor.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

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
            Text('Project: ${widget.project.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Text('All Supervisors', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _allSupervisors.isEmpty
                      ? const Center(child: Text('No supervisors found.'))
                      : ListView.builder(
                          itemCount: _allSupervisors.length,
                          itemBuilder: (context, index) {
                            final supervisor = _allSupervisors[index];
                            return _buildSupervisorTile(supervisor);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupervisorTile(User supervisor) {
    final assigned = _isAssigned(supervisor.id);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: assigned ? const Color(0xFF3B82F6).withOpacity(0.3) : const Color(0xFFF1F5F9), width: assigned ? 1.5 : 1),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: assigned ? const Color(0xFF3B82F6).withOpacity(0.1) : const Color(0xFFF1F5F9),
          child: Icon(Icons.person, color: assigned ? const Color(0xFF3B82F6) : Colors.grey),
        ),
        title: Text(supervisor.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Role: ${supervisor.role} • ${supervisor.phone}'),
        trailing: ElevatedButton(
          onPressed: () => _toggleAssignment(supervisor),
          style: ElevatedButton.styleFrom(
            backgroundColor: assigned ? const Color(0xFF10B981) : const Color(0xFF1E293B),
            foregroundColor: Colors.white,
          ),
          child: Text(assigned ? 'Assigned' : 'Assign'),
        ),
      ),
    );
  }
}
