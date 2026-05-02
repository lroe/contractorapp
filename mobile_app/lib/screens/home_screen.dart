import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dpr_screen.dart';
import 'attendance_screen.dart';
import 'project_management_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String role = ModalRoute.of(context)!.settings.arguments as String? ?? 'supervisor';
    final bool isOwner = role == 'owner';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(role),
              const SizedBox(height: 32),
              _buildStatsRow(isOwner),
              const SizedBox(height: 32),
              Text(
                'Quick Actions',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              _buildActionGrid(context, isOwner),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String role) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${role == 'owner' ? 'Contractor' : 'Jeevan'}',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            Text(
              role == 'owner' ? 'Business Owner' : 'Site Supervisor • Project Alpha',
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
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectManagementScreen())),
        ),
        _buildActionCard(
          context,
          'Supervisors',
          Icons.person_search,
          const Color(0xFF3B82F6),
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectManagementScreen())),
        ),
        _buildActionCard(
          context,
          'Reports',
          Icons.bar_chart,
          const Color(0xFFF59E0B),
          () {},
        ),
        _buildActionCard(
          context,
          'Settings',
          Icons.settings,
          const Color(0xFF64748B),
          () {},
        ),
      ] : [
        _buildActionCard(
          context,
          'DPR Entry',
          Icons.edit_document,
          const Color(0xFF3B82F6),
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DPRScreen())),
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
          'Inventory',
          Icons.inventory_2,
          const Color(0xFFF59E0B),
          () {},
        ),
        _buildActionCard(
          context,
          'Settings',
          Icons.settings,
          const Color(0xFF64748B),
          () {},
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
