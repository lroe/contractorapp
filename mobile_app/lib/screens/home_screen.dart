import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dpr_screen.dart';
import 'attendance_screen.dart';
import 'project_management_screen.dart';
import 'tasks_screen.dart';
import 'report_detail_screen.dart';
import 'inventory_screen.dart';
import '../models/models.dart';

import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  User? _currentUser;
  List<Project> _assignedProjects = [];
  Project? _selectedProject;
  bool _isLoadingProjects = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_currentUser == null) {
      _currentUser = ModalRoute.of(context)!.settings.arguments as User?;
      if (_currentUser != null && _currentUser!.role == 'supervisor') {
        _loadAssignedProjects();
      }
    }
  }

  Future<void> _loadAssignedProjects() async {
    setState(() => _isLoadingProjects = true);
    try {
      final projects = await _apiService.getProjectsForUser(_currentUser!.id);
      setState(() {
        _assignedProjects = projects;
        if (_assignedProjects.isNotEmpty) {
          _selectedProject = _assignedProjects.first;
        }
        _isLoadingProjects = false;
      });
    } catch (e) {
      setState(() => _isLoadingProjects = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final bool isOwner = _currentUser!.role == 'owner';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(_currentUser!),
              const SizedBox(height: 24),
              if (!isOwner) _buildProjectSelector(),
              const SizedBox(height: 24),
              _buildStatsRow(isOwner),
              const SizedBox(height: 32),
              _buildRecentActivity(),
              const SizedBox(height: 32),
              Text(
                'Quick Actions',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              if (!isOwner && _assignedProjects.isEmpty && !_isLoadingProjects)
                _buildNoAssignmentWarning()
              else
                _buildActionGrid(context, isOwner),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectSelector() {
    if (_isLoadingProjects) return const LinearProgressIndicator();
    if (_assignedProjects.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Project>(
          value: _selectedProject,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: _assignedProjects.map((Project p) {
            return DropdownMenuItem<Project>(
              value: p,
              child: Text('Active Project: ${p.name}', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            );
          }).toList(),
          onChanged: (Project? newValue) {
            setState(() {
              _selectedProject = newValue;
            });
          },
        ),
      ),
    );
  }

  Widget _buildNoAssignmentWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
          const SizedBox(height: 16),
          Text(
            'You aren\'t assigned any projects',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[900]),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please contact the owner to get access to project tasks.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(User user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${user.name}',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            Text(
              user.role == 'owner' 
                  ? 'Business Owner' 
                  : (_selectedProject != null ? 'Project: ${_selectedProject!.name}' : 'No Project Assigned'),
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFE2E8F0),
          child: Icon(Icons.person_outline, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isOwner) {
    return Row(
      children: [
        _buildStatCard(isOwner ? 'Active Projects' : 'Pending Tasks', isOwner ? '04' : '12', isOwner ? Colors.blue : Colors.orange),
        const SizedBox(width: 16),
        _buildStatCard(isOwner ? 'Total Revenue' : 'Work Progress', isOwner ? '₹1.2M' : '65%', isOwner ? Colors.green : Colors.blue),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, bool isOwner) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: isOwner ? [
        _buildActionCard(
          context,
          'Create Project',
          Icons.add_business,
          const Color(0xFF1E293B),
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectManagementScreen(user: _currentUser!))),
        ),
        _buildActionCard(
          context,
          'Supervisors',
          Icons.person_search,
          const Color(0xFF3B82F6),
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectManagementScreen(user: _currentUser!))),
        ),
        _buildActionCard(
          context,
          'View Reports',
          Icons.assessment,
          const Color(0xFF10B981),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectManagementScreen(
                onProjectTap: (project) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ReportsListScreen(project: project)),
                ),
              ),
            ),
          ),
        ),
        _buildActionCard(
          context,
          'Tasks',
          Icons.task_alt,
          const Color(0xFFF59E0B),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectManagementScreen(
                onProjectTap: (project) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TasksScreen(project: project, user: _currentUser!)),
                ),
              ),
            ),
          ),
        ),
        _buildActionCard(
          context,
          'Inventory',
          Icons.inventory_2_outlined,
          const Color(0xFFEC4899),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectManagementScreen(
                onProjectTap: (project) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => InventoryScreen(project: project, user: _currentUser!)),
                ),
              ),
            ),
          ),
        ),
      ] : [
        _buildActionCard(
          context,
          'DPR Entry',
          Icons.edit_document,
          const Color(0xFF1E293B),
          () {
            if (_selectedProject == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a project first')));
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (context) => DPRScreen(project: _selectedProject!, user: _currentUser!)));
          },
        ),
        _buildActionCard(
          context,
          'Reports',
          Icons.insights,
          const Color(0xFF3B82F6),
          () {
            if (_selectedProject == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a project first')));
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsListScreen(project: _selectedProject!)));
          },
        ),
        _buildActionCard(
          context,
          'Attendance',
          Icons.people_alt,
          const Color(0xFF10B981),
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceScreen())),
        ),
        _buildActionCard(
          context,
          'Tasks',
          Icons.task_alt,
          const Color(0xFFF59E0B),
          () {
            if (_selectedProject == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a project first')));
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (context) => TasksScreen(project: _selectedProject!, user: _currentUser!)));
          },
        ),
        _buildActionCard(
          context,
          'Inventory',
          Icons.inventory_2_outlined,
          const Color(0xFFEC4899),
          () {
            if (_selectedProject == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a project first')));
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryScreen(project: _selectedProject!, user: _currentUser!)));
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final projectId = _selectedProject?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activity', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () {
                if (_selectedProject != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsListScreen(project: _selectedProject!)));
                } else {
                  // If Owner or no project selected, show all project reports via management screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProjectManagementScreen(
                        onProjectTap: (project) => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ReportsListScreen(project: project)),
                        ),
                      ),
                    ),
                  );
                }
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<dynamic>>(
          future: projectId != null ? _apiService.getProjectDPRs(projectId) : _apiService.getRecentReports(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final reports = snapshot.data ?? [];
            if (reports.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No recent reports.')));

            return Column(
              children: reports.take(3).map((report) => _buildActivityTile(report)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityTile(dynamic report) {
    final hasLinkedTask = report['linked_task_id'] != null;
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: hasMedia
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
                  Row(children: [
                    Flexible(
                      child: Text(
                        report['remarks']?.isNotEmpty == true ? report['remarks'] : 'Report Submitted',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (hasLinkedTask) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Text('linked', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text('📅 ${report['entry_date']}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
