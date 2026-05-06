import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/offline_attendance_manager.dart';
import '../services/sync_queue_manager.dart';

class AttendanceScreen extends StatefulWidget {
  final Project project;
  final User user;
  const AttendanceScreen({super.key, required this.project, required this.user});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _gangs = [];
  bool _isLoading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _initializeOfflineManager();
    _checkConnectivity();
    _loadGangs();
  }

  Future<void> _initializeOfflineManager() async {
    await OfflineAttendanceManager.initialize();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = !connectivityResult.contains(ConnectivityResult.none);
    });

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = !result.contains(ConnectivityResult.none);
      });
    });
  }

  Future<void> _loadGangs() async {
    setState(() => _isLoading = true);
    try {
      if (_isOnline) {
        // Load from API and cache locally
        final gangs = await _apiService.getGangs(widget.project.id);
        setState(() {
          _gangs = gangs;
          _isLoading = false;
        });
        // Cache gangs for offline use
        await OfflineAttendanceManager.cacheGangs(widget.project.id, gangs);
      } else {
        // Load from cache
        final cachedGangs = OfflineAttendanceManager.getCachedGangs(widget.project.id);
        setState(() {
          _gangs = cachedGangs;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Try to load from cache if API fails
      final cachedGangs = OfflineAttendanceManager.getCachedGangs(widget.project.id);
      if (cachedGangs.isNotEmpty) {
        setState(() {
          _gangs = cachedGangs;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCreateGangDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Create New Gang', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'e.g. Mason Gang 1'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              Navigator.pop(ctx);
              if (widget.user.organizationId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: User not associated with any organization')));
                return;
              }
              try {
                await _apiService.createGang({
                  'name': nameController.text,
                  'project_id': widget.project.id,
                  'supervisor_id': widget.user.id,
                  'organization_id': widget.user.organizationId,
                });
                _loadGangs();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Workforce Attendance', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1E293B))),
          Text(widget.project.name, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
        ]),
        actions: [
          if (!_isOnline)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('Offline', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          IconButton(onPressed: _showCreateGangDialog, icon: const Icon(Icons.group_add_outlined, color: Color(0xFF1E293B))),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _gangs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _gangs.length,
                  itemBuilder: (context, i) => _buildGangCard(_gangs[i]),
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

  Widget _buildGangCard(dynamic gang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(gang['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        subtitle: const Text('Manage workers & mark attendance'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GangDetailScreen(gang: gang, project: widget.project, user: widget.user)),
        ),
      ),
    );
  }
}

class GangDetailScreen extends StatefulWidget {
  final dynamic gang;
  final Project project;
  final User user;
  const GangDetailScreen({super.key, required this.gang, required this.project, required this.user});

  @override
  State<GangDetailScreen> createState() => _GangDetailScreenState();
}

class _GangDetailScreenState extends State<GangDetailScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _workers = [];
  bool _isLoading = true;
  final Map<String, String> _attendanceMap = {}; // workerId -> status
  XFile? _groupPhoto;
  final ImagePicker _picker = ImagePicker();
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadWorkers();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = !connectivityResult.contains(ConnectivityResult.none);
    });

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = !result.contains(ConnectivityResult.none);
      });
    });
  }

  Future<void> _pickPhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (photo != null) {
      setState(() => _groupPhoto = photo);
    }
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      if (_isOnline) {
        // Load from API and cache locally
        final results = await Future.wait<dynamic>([
          _apiService.getWorkers(widget.gang['id']),
          _apiService.getGangAttendance(widget.gang['id'], dateStr),
        ]);

        final workers = results[0] as List<dynamic>;
        final existingAttendance = results[1] as List<dynamic>;

        setState(() {
          _workers = workers;

          // 1. Pre-fill from backend if exists
          for (var att in existingAttendance) {
            _attendanceMap[att['worker_id'].toString()] = att['status'];
          }

          // 2. Default others to 'present' only if they aren't already set locally
          for (var w in _workers) {
            final id = w['id'].toString();
            if (!_attendanceMap.containsKey(id)) {
              _attendanceMap[id] = 'present';
            }
          }
          _isLoading = false;
        });

        // Cache workers for offline use
        await OfflineAttendanceManager.cacheWorkers(widget.gang['id'], workers);
      } else {
        // Load from cache
        final cachedWorkers = OfflineAttendanceManager.getCachedWorkers(widget.gang['id']);
        final localAttendance = OfflineAttendanceManager.getAttendanceForGang(widget.gang['id'], now);

        setState(() {
          _workers = cachedWorkers;

          // Load local attendance data
          for (var att in localAttendance) {
            _attendanceMap[att.workerId] = att.status;
          }

          // Default others to 'present' if not set
          for (var w in _workers) {
            final id = w['id'].toString();
            if (!_attendanceMap.containsKey(id)) {
              _attendanceMap[id] = 'present';
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      // Try to load from cache if API fails
      final cachedWorkers = OfflineAttendanceManager.getCachedWorkers(widget.gang['id']);
      final now = DateTime.now();
      final localAttendance = OfflineAttendanceManager.getAttendanceForGang(widget.gang['id'], now);

      if (cachedWorkers.isNotEmpty) {
        setState(() {
          _workers = cachedWorkers;

          // Load local attendance data
          for (var att in localAttendance) {
            _attendanceMap[att.workerId] = att.status;
          }

          // Default others to 'present' if not set
          for (var w in _workers) {
            final id = w['id'].toString();
            if (!_attendanceMap.containsKey(id)) {
              _attendanceMap[id] = 'present';
            }
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddWorkerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final rateController = TextEditingController(text: '500');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Worker', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Worker Name')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone (Optional)'), keyboardType: TextInputType.phone),
            TextField(controller: rateController, decoration: const InputDecoration(labelText: 'Daily Rate (₹)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              Navigator.pop(ctx);
              if (widget.user.organizationId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: User not associated with any organization')));
                return;
              }
              try {
                await _apiService.createWorker({
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'daily_rate': double.tryParse(rateController.text) ?? 0,
                  'project_id': widget.project.id,
                  'gang_id': widget.gang['id'],
                  'organization_id': widget.user.organizationId,
                });
                _loadWorkers();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.gang['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        actions: [
          if (!_isOnline)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('Offline', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          IconButton(onPressed: _showAddWorkerDialog, icon: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF1E293B))),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _workers.length,
                    itemBuilder: (context, i) => _buildWorkerRow(_workers[i]),
                  ),
                ),
                if (_workers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        if (_groupPhoto != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: DecorationImage(
                                image: FileImage(File(_groupPhoto!.path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: IconButton(
                                    onPressed: () => setState(() => _groupPhoto = null),
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Take Group Photo'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _saveAttendance,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text('Submit Attendance', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildWorkerRow(dynamic worker) {
    String currentStatus = _attendanceMap[worker['id']] ?? 'present';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(worker['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusBtn('P', 'present', currentStatus, worker['id']),
            _buildStatusBtn('H', 'half_day', currentStatus, worker['id']),
            _buildStatusBtn('A', 'absent', currentStatus, worker['id']),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBtn(String label, String value, String currentStatus, String workerId) {
    bool isSelected = currentStatus == value;
    Color activeColor = value == 'present' ? Colors.green : (value == 'half_day' ? Colors.orange : Colors.red);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => setState(() => _attendanceMap[workerId] = value),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: isSelected ? activeColor : const Color(0xFFF1F5F9),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black54)),
        ),
      ),
    );
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Save group photo locally if taken
      String? localPhotoPath;
      if (_groupPhoto != null) {
        localPhotoPath = await OfflineAttendanceManager.saveGroupPhoto(
          widget.gang['id'],
          now,
          _groupPhoto!.path,
        );
      }

      if (_isOnline) {
        // Submit to server directly
        for (var entry in _attendanceMap.entries) {
          await _apiService.submitAttendance({
            'project_id': widget.project.id,
            'worker_id': entry.key,
            'gang_id': widget.gang['id'],
            'entry_date': dateStr,
            'status': entry.value,
            'marked_by': widget.user.id,
          });
        }

        if (_groupPhoto != null) {
          await _apiService.uploadAttendancePhoto(
            widget.gang['id'],
            dateStr,
            _groupPhoto!.path,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance submitted successfully!')));
          Navigator.pop(context);
        }
      } else {
        // Save locally and queue for sync
        for (var entry in _attendanceMap.entries) {
          final attendanceId = '${widget.gang['id']}_${entry.key}_$dateStr';
          final attendance = Attendance(
            id: attendanceId,
            workerId: entry.key,
            gangId: widget.gang['id'],
            date: now,
            status: entry.value,
            isSynced: false,
            groupPhotoPath: localPhotoPath,
          );

          await OfflineAttendanceManager.saveAttendanceRecord(attendance);

          // Add to sync queue
          await SyncQueueManager.queueOperation(
            'attendance',
            {
              'project_id': widget.project.id,
              'worker_id': entry.key,
              'gang_id': widget.gang['id'],
              'entry_date': dateStr,
              'status': entry.value,
              'marked_by': widget.user.id,
              'group_photo_path': localPhotoPath,
            },
            customId: attendanceId,
          );
        }

        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance saved offline. Will sync when online.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
