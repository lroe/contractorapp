import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'package:intl/intl.dart';
import '../config.dart';

class DocumentsScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String userId;

  const DocumentsScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.userId,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final ApiService _apiService = ApiService();
  List<ProjectDocument> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
    WebSocketService().connect((message) {
      if (mounted && message['type'] == 'NEW_DOCUMENT' && message['project_id'] == widget.projectId) {
        _fetchDocuments();
      }
    });
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _apiService.getProjectDocuments(widget.projectId);
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching documents: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadFiles() async {
    FilePickerResult? result = await FilePicker.pickFiles(allowMultiple: true);

    if (result != null && result.files.isNotEmpty) {
      List<File> files = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();

      if (files.isEmpty) return;

      try {
        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );
        }

        await _apiService.uploadProjectDocuments(
          projectId: widget.projectId,
          uploadedBy: widget.userId,
          files: files,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading indicator
          _fetchDocuments(); // Refresh list
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Uploaded ${files.length} document(s) successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading documents: $e')),
          );
        }
      }
    }
  }

  Future<void> _openDocument(String url) async {
    final fullUrl = url.startsWith('http') ? url : '$baseUrl$url';
    final uri = Uri.parse(fullUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Documents'),
            Text(
              widget.projectName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDocuments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No documents uploaded yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: _getIconForFileType(doc.fileType),
                        title: Text(doc.name),
                        subtitle: Text(
                          'Uploaded: ${DateFormat('dd MMM yyyy, hh:mm a').format(doc.uploadedAt)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 20),
                        onTap: () => _openDocument(doc.fileUrl),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndUploadFiles,
        label: const Text('Upload'),
        icon: const Icon(Icons.upload_file),
      ),
    );
  }

  Widget _getIconForFileType(String? type) {
    IconData iconData;
    Color color;

    switch (type?.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        color = Colors.blue;
        break;
      case 'xls':
      case 'xlsx':
        iconData = Icons.table_chart;
        color = Colors.green;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        iconData = Icons.image;
        color = Colors.orange;
        break;
      default:
        iconData = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Icon(iconData, color: color, size: 32);
  }
}
