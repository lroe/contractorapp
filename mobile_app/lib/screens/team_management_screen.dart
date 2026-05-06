import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class TeamManagementScreen extends StatefulWidget {
  final User user;

  const TeamManagementScreen({super.key, required this.user});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final ApiService _apiService = ApiService();
  List<User> _teamMembers = [];
  bool _isLoading = true;
  bool _isInviting = false;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    try {
      final members = await _apiService.listUsers(
        organizationId: widget.user.organizationId!,
      );
      if (!mounted) return;
      setState(() {
        _teamMembers = members;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load team members: $e')),
      );
    }
  }

  void _showInviteDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRole = 'supervisor';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Invite Team Member',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter full name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter email address',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(
                  value: 'supervisor',
                  child: Text('Supervisor'),
                ),
                DropdownMenuItem(value: 'owner', child: Text('Owner')),
              ],
              onChanged: (value) => selectedRole = value!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isInviting
                ? null
                : () => _inviteUser(
                    nameController.text,
                    emailController.text,
                    selectedRole,
                  ),
            child: _isInviting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Invite'),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteUser(String name, String email, String role) async {
    if (name.isEmpty || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isInviting = true);
    try {
      await _apiService.inviteUser(
        widget.user.organizationId!,
        email,
        name,
        role,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _loadTeamMembers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name has been invited as $role')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to invite user: $e')));
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Team Management',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Team Members (${_teamMembers.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showInviteDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Invite'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _teamMembers.isEmpty
                        ? Center(
                            child: Text(
                              'No team members yet',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _teamMembers.length,
                            itemBuilder: (context, index) {
                              final member = _teamMembers[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getRoleColor(member.role),
                                    child: Text(
                                      member.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    member.name,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(member.email ?? member.phone),
                                      Text(
                                        member.role
                                            .replaceAll('_', ' ')
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getRoleColor(member.role),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(
                                    member.authProvider == 'google'
                                        ? Icons.account_circle
                                        : Icons.lock,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.green;
      case 'supervisor':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
