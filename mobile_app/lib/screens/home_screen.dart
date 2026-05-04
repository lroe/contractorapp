import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dpr_screen.dart';
import 'attendance_screen.dart';
import 'project_management_screen.dart';
import 'tasks_screen.dart';
import 'report_detail_screen.dart';
import 'inventory_screen.dart';
import 'finance_screen.dart';
import 'attendance_report_screen.dart';
import 'documents_screen.dart';
import 'notification_screen.dart';
import '../models/models.dart';

import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config.dart';

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
  void initState() {
    super.initState();
    WebSocketService().connect((message) {
      if (mounted) {
        // Refresh recent activity on any relevant update
        final type = message['type'];
        if (type == 'NEW_DPR' || 
            type == 'NEW_DOCUMENT' || 
            type == 'NEW_MATERIAL_REQUEST' || 
            type == 'MATERIAL_REQUEST_UPDATED' || 
            type == 'MATERIAL_USAGE_LOGGED' ||
            type == 'TASK_UPDATED') {
          setState(() {
            // This will trigger FutureBuilder to re-run
          });
        }
      }
    });
  }

  @override
  void dispose() {
    WebSocketService().disconnect();
    super.dispose();
  }

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
      final projects = await _apiService.getProjects(_currentUser!.organizationId!, userId: _currentUser!.id);
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
    return FutureBuilder<Map<String, dynamic>>(
      future: _apiService.getDashboardStats(_currentUser!.organizationId!, _currentUser!.id, projectId: _selectedProject?.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_isLoadingProjects) {
          // Show placeholders or keep old values
        }
        
        final stats = snapshot.data ?? {
          "stat1_label": isOwner ? 'Active Projects' : 'Pending Tasks',
          "stat1_value": '--',
          "stat2_label": isOwner ? 'Total Revenue' : 'Active Tasks',
          "stat2_value": '--'
        };

        return Row(
          children: [
            _buildStatCard(stats['stat1_label'], stats['stat1_value'], isOwner ? Colors.blue : Colors.orange),
            const SizedBox(width: 16),
            _buildStatCard(stats['stat2_label'], stats['stat2_value'], isOwner ? Colors.green : Colors.blue),
          ],
        );
      },
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
          'DPR Entry',
          Icons.edit_document,
          const Color(0xFF1E293B),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectManagementScreen(
                onProjectTap: (project) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DPRScreen(project: project, user: _currentUser!)),
                ),
              ),
            ),
          ),
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
          'Procure/Stock',
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
        _buildActionCard(
          context,
          'Finance',
          Icons.account_balance_wallet_outlined,
          const Color(0xFF6366F1),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectManagementScreen(
                onProjectTap: (project) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FinanceScreen(project: project, user: _currentUser!)),
                ),
              ),
            ),
          ),
        ),
        _buildActionCard(
          context,
          'Att. Reports',
          Icons.analytics_outlined,
          const Color(0xFF6366F1),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectManagementScreen(
                onProjectTap: (project) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AttendanceReportScreen(project: project)),
                ),
              ),
            ),
          ),
        ),
        _buildActionCard(
          context,
          'Documents',
          Icons.folder_copy_outlined,
          const Color(0xFF8B5CF6),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectManagementScreen(
                user: _currentUser!,
                onProjectTap: (project) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentsScreen(
                      projectId: project.id,
                      projectName: project.name,
                      userId: _currentUser!.id,
                    ),
                  ),
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
          () {
            if (_selectedProject == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a project first')));
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(project: _selectedProject!, user: _currentUser!)));
          },
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
          'Procure/Stock',
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
        _buildActionCard(
          context,
          'Documents',
          Icons.folder_copy_outlined,
          const Color(0xFF8B5CF6),
          () {
            if (_selectedProject == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a project first')));
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DocumentsScreen(
                  projectId: _selectedProject!.id,
                  projectName: _selectedProject!.name,
                  userId: _currentUser!.id,
                ),
              ),
            );
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
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => NotificationScreen(
                      user: _currentUser!,
                      selectedProject: _selectedProject,
                    )
                  )
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<dynamic>>(
          future: _apiService.getRecentActivity(organizationId: _currentUser!.organizationId!, projectId: projectId, userId: _currentUser!.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            }
            final activities = snapshot.data ?? [];
            if (activities.isEmpty) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No activity yet.', style: TextStyle(color: Color(0xFF94A3B8))),
              ));
            }
            return Column(
              children: activities.map((activity) => _buildActivityTile(activity)).toList(),
            );
          },
        ),
      ],
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
                        '$baseUrl${media[0]['media_url']}',
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
                  Text(report['remarks'] ?? 'No remarks provided.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
        final project = _assignedProjects.firstWhere(
          (p) => p.id == projectId,
          orElse: () => Project(id: projectId, name: req['project_name'], status: 'active'),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => InventoryScreen(project: project, user: _currentUser!)),
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
