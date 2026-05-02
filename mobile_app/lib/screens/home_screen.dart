import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dpr_screen.dart';
import 'attendance_screen.dart';
import 'project_management_screen.dart';
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
              Text(
                'Quick Actions',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              if (!isOwner && _assignedProjects.isEmpty && !_isLoadingProjects)
                _buildNoAssignmentWarning()
              else
                _buildActionGrid(context, isOwner),
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
      ],
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
