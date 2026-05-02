import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../models/models.dart';

class DPRScreen extends StatefulWidget {
  final Project project;
  final User user;
  const DPRScreen({super.key, required this.project, required this.user});

  @override
  State<DPRScreen> createState() => _DPRScreenState();
}

class _DPRScreenState extends State<DPRScreen> {
  final List<XFile> _mediaFiles = [];
  final ImagePicker _picker = ImagePicker();
  final _remarksController = TextEditingController();
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  Future<void> _pickMedia() async {
    final List<XFile> selectedImages = await _picker.pickMultiImage();
    if (selectedImages.isNotEmpty) {
      setState(() {
        _mediaFiles.addAll(selectedImages);
      });
    }
  }

  Future<void> _submitReport() async {
    if (_remarksController.text.isEmpty && _mediaFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add remarks or a photo')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dprData = {
        "project_id": widget.project.id,
        "supervisor_id": widget.user.id,
        "entry_date": DateTime.now().toIso8601String().split('T')[0],
        "work_type_id": null,
        "block_id": null,
        "floor_id": null,
        "area_id": null,
        "quantity": null,
        "remarks": _remarksController.text,
        "linked_task_id": null,
      };

      await _apiService.submitDPR(dprData);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report Submitted Successfully!')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _viewReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReportsListScreen(project: widget.project)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Daily Progress', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _viewReports, icon: const Icon(Icons.history)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 32),
                _buildInputLabel('Update / Remarks'),
                const SizedBox(height: 8),
                _buildTextField(_remarksController, 'What happened on site today?', TextInputType.multiline, maxLines: 5),
                const SizedBox(height: 32),
                _buildMediaSection(),
                const SizedBox(height: 48),
                _buildSubmitButton(),
              ],
            ),
          ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Color(0xFF3B82F6)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Project: ${widget.project.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text('Site Reporting Mode', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)));
  }

  Widget _buildTextField(TextEditingController? controller, String hint, TextInputType type, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInputLabel('Site Photos'),
            TextButton.icon(onPressed: _pickMedia, icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Add')),
          ],
        ),
        const SizedBox(height: 8),
        if (_mediaFiles.isEmpty)
          _buildEmptyMediaBox()
        else
          _buildMediaList(),
      ],
    );
  }

  Widget _buildEmptyMediaBox() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: const Center(child: Text('No photos added', style: TextStyle(color: Color(0xFF94A3B8)))),
    );
  }

  Widget _buildMediaList() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _mediaFiles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(_mediaFiles[index].path), width: 120, height: 120, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _submitReport,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: Text('Submit Report', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class ReportsListScreen extends StatelessWidget {
  final Project project;
  const ReportsListScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Project Reports: ${project.name}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService().getProjectDPRs(project.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final reports = snapshot.data ?? [];
          if (reports.isEmpty) return const Center(child: Text('No reports found for this project.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Date: ${report['entry_date']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(report['remarks'] ?? 'No remarks', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
