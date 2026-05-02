import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class InventoryScreen extends StatefulWidget {
  final Project project;
  final User user;
  const InventoryScreen({super.key, required this.project, required this.user});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  List<dynamic> _inventory = [];
  List<dynamic> _requests = [];
  List<dynamic> _materials = [];
  bool _isLoading = true;

  bool get isOwner => widget.user.role == 'owner';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getProjectInventory(widget.project.id),
        _apiService.getMaterialRequests(widget.project.id),
        _apiService.getMaterials(),
      ]);
      setState(() {
        _inventory = results[0];
        _requests = results[1];
        _materials = results[2];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showRequestDialog() {
    String? selectedMaterialId;
    final quantityController = TextEditingController();
    final remarksController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 20),
              Text('Request Material', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              Text('Select Material', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: _materials.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text('${m['name']} (${m['unit']})'))).toList(),
                onChanged: (val) => setModalState(() => selectedMaterialId = val),
              ),
              const SizedBox(height: 16),

              Text('Quantity', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: 'Enter quantity', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),

              Text('Remarks (Optional)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: remarksController,
                decoration: InputDecoration(hintText: 'e.g. For plastering work', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedMaterialId == null || quantityController.text.isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await _apiService.createMaterialRequest({
                        'project_id': widget.project.id,
                        'material_id': selectedMaterialId,
                        'quantity': double.parse(quantityController.text),
                        'remarks': remarksController.text,
                        'requested_by': widget.user.id,
                      });
                      _loadData();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text('Submit Request', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
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
          Text('Inventory & Indents', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
          Text(widget.project.name, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
        ]),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF3B82F6),
          tabs: const [Tab(text: 'Current Stock'), Tab(text: 'Requests')],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildInventoryTab(), _buildRequestsTab()],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestDialog,
        backgroundColor: const Color(0xFF1E293B),
        icon: const Icon(Icons.add_shopping_cart, size: 20),
        label: Text('Request Material', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInventoryTab() {
    if (_inventory.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 16),
        Text('No stock logged yet', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _inventory.length,
      itemBuilder: (context, i) {
        final item = _inventory[i];
        final material = _materials.firstWhere((m) => m['id'] == item['material_id'], orElse: () => null);
        final name = material?['name'] ?? 'Material';
        final unit = material?['unit'] ?? '';
        final qty = item['current_quantity'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.category_outlined, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Current Balance', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$qty', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: qty < 10 ? Colors.red : Colors.black)),
              Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    if (_requests.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.history_outlined, size: 64, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 16),
        Text('No requests found', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (context, i) {
        final req = _requests[i];
        final material = _materials.firstWhere((m) => m['id'] == req['material_id'], orElse: () => null);
        final name = material?['name'] ?? 'Material';
        final status = req['status'] as String;
        
        Color statusColor;
        switch(status) {
          case 'pending': statusColor = Colors.orange; break;
          case 'approved': statusColor = Colors.blue; break;
          case 'received': statusColor = Colors.green; break;
          case 'rejected': statusColor = Colors.red; break;
          default: statusColor = Colors.grey;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: statusColor.withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('Quantity: ${req['quantity']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const Spacer(),
              if (isOwner && status == 'pending') ...[
                TextButton(onPressed: () => _updateRequest(req['id'], 'rejected'), child: const Text('Reject', style: TextStyle(color: Colors.red))),
                ElevatedButton(onPressed: () => _updateRequest(req['id'], 'approved'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)), child: const Text('Approve')),
              ],
              if (!isOwner && status == 'approved') ...[
                ElevatedButton(onPressed: () => _updateRequest(req['id'], 'received'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('Mark Received')),
              ]
            ]),
            if (req['remarks'] != null && req['remarks'].isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('Note: ${req['remarks']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey))),
          ]),
        );
      },
    );
  }

  Future<void> _updateRequest(String id, String status) async {
    try {
      await _apiService.updateMaterialRequestStatus(id, status);
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
