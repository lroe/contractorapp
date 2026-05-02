import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';

class DPRScreen extends StatefulWidget {
  const DPRScreen({super.key});

  @override
  State<DPRScreen> createState() => _DPRScreenState();
}

class _DPRScreenState extends State<DPRScreen> {
  final List<XFile> _mediaFiles = [];
  final ImagePicker _picker = ImagePicker();
  final _quantityController = TextEditingController();

  Future<void> _pickMedia() async {
    final List<XFile> selectedImages = await _picker.pickMultiImage();
    if (selectedImages.isNotEmpty) {
      setState(() {
        _mediaFiles.addAll(selectedImages);
      });
    }
  }

  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  Future<void> _submitReport() async {
    if (_quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter quantity')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create DPR Entry (IDs are placeholders, in a real app these come from selection)
      // dprData would match schemas.DPREntryCreate
      // For demo, we'll just show the flow
      
      // await _apiService.submitDPR({...}); 
      // await _apiService.uploadMedia(dprId, _mediaFiles.map((e) => e.path).toList());

      await Future.delayed(const Duration(seconds: 2)); // Simulate network

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DPR Submitted Successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Daily Progress', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
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
                _buildInputLabel('Work Quantity (sqft)'),
                const SizedBox(height: 8),
                _buildTextField(_quantityController, 'Enter quantity', TextInputType.number),
                const SizedBox(height: 24),
                _buildInputLabel('Remarks'),
                const SizedBox(height: 8),
                _buildTextField(null, 'Add any specific notes...', TextInputType.multiline, maxLines: 3),
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
      child: const Row(
        children: [
          Icon(Icons.location_on, color: Color(0xFF3B82F6)),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Project Alpha • Block A', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Floor 2 • Area: Living Room', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildTextField(TextEditingController? controller, String hint, TextInputType type, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            _buildInputLabel('Photos & Videos'),
            TextButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(Icons.add_a_photo_outlined, size: 20),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_mediaFiles.isEmpty)
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
            ),
            child: const Center(
              child: Text('No media selected', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _mediaFiles.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_mediaFiles[index].path),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _mediaFiles.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          'Submit Report',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
