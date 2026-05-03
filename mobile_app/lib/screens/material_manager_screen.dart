import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class MaterialManagerScreen extends StatefulWidget {
  final User user;
  const MaterialManagerScreen({super.key, required this.user});

  @override
  State<MaterialManagerScreen> createState() => _MaterialManagerScreenState();
}

class _MaterialManagerScreenState extends State<MaterialManagerScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
            bottom: TabBar(
              controller: _tabs,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: const Color(0xFF38BDF8),
              indicatorWeight: 3,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Dashboard'),
                Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Purchase Orders'),
                Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Vendors'),
                Tab(icon: Icon(Icons.swap_horiz_outlined, size: 18), text: 'Transfers'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _DashboardTab(api: _api),
            _PurchaseOrdersTab(api: _api, user: widget.user),
            _VendorsTab(api: _api),
            _TransfersTab(api: _api, user: widget.user),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8).withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.store_outlined, color: Color(0xFF38BDF8), size: 28),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Material Manager', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Hello, ${widget.user.name}', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
        ]),
      ]),
    );
  }
}

// ─── Dashboard Tab ─────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final ApiService api;
  const _DashboardTab({required this.api});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: api.getMaterialManagerDashboard(),
      builder: (ctx, snap) {
        final data = snap.data ?? {};
        return RefreshIndicator(
          onRefresh: () async { (ctx as Element).markNeedsBuild(); },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Overview', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.4,
                children: [
                  _statCard('Pending POs', '${data['pending_pos'] ?? '--'}', Icons.receipt_long_outlined, const Color(0xFFF59E0B)),
                  _statCard('Active Vendors', '${data['active_vendors'] ?? '--'}', Icons.people_outline, const Color(0xFF3B82F6)),
                  _statCard('Total Materials', '${data['total_materials'] ?? '--'}', Icons.inventory_2_outlined, const Color(0xFF10B981)),
                  _statCard('Pending Transfers', '${data['pending_transfers'] ?? '--'}', Icons.swap_horiz, const Color(0xFF8B5CF6)),
                ],
              ),
              const SizedBox(height: 24),
              Text('Quick Actions', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              const SizedBox(height: 12),
              _quickAction(context, Icons.add_shopping_cart, 'New Purchase Order', const Color(0xFFF59E0B), () {
                // Navigate to PO tab
              }),
              _quickAction(context, Icons.warning_amber_rounded, 'Low Stock Alerts', const Color(0xFFEF4444), () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const _LowStockScreen()));
              }),
              _quickAction(context, Icons.compare_arrows, 'Create Transfer', const Color(0xFF8B5CF6), () {}),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const Spacer(),
        Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      ]),
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1E293B))),
          const Spacer(),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ]),
      ),
    );
  }
}

// ─── Purchase Orders Tab ────────────────────────────────────────────────────────

class _PurchaseOrdersTab extends StatefulWidget {
  final ApiService api;
  final User user;
  const _PurchaseOrdersTab({required this.api, required this.user});

  @override
  State<_PurchaseOrdersTab> createState() => _PurchaseOrdersTabState();
}

class _PurchaseOrdersTabState extends State<_PurchaseOrdersTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getPurchaseOrders();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final pos = snap.data ?? [];
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = widget.api.getPurchaseOrders()),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...pos.map((po) => _buildPOCard(po)),
              if (pos.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(children: [
                      const Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      Text('No purchase orders yet', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 16)),
                    ]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPOCard(dynamic po) {
    final status = po['status'] ?? 'draft';
    final colors = {
      'draft': Colors.grey, 'sent': Colors.blue, 'partially_received': Colors.orange,
      'received': Colors.green, 'cancelled': Colors.red,
    };
    final color = colors[status] ?? Colors.grey;
    final items = po['items'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(po['po_number'] ?? 'Draft PO', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Vendor: ${po['vendor']?['name'] ?? 'Unknown'}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text('Items: ${items.length}  |  Total: ₹${double.tryParse(po['total_amount'].toString())?.toStringAsFixed(0) ?? '0'}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        if (status == 'draft') ...[ 
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  try {
                    await widget.api.updatePOStatus(po['id'], 'sent', approvedBy: widget.user.id);
                    setState(() => _future = widget.api.getPurchaseOrders());
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PO sent to vendor ✅')));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Approve & Send'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ─── Vendors Tab ────────────────────────────────────────────────────────────────

class _VendorsTab extends StatefulWidget {
  final ApiService api;
  const _VendorsTab({required this.api});

  @override
  State<_VendorsTab> createState() => _VendorsTabState();
}

class _VendorsTabState extends State<_VendorsTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getVendors();
  }

  void _showAddVendorDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add Vendor', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: nameCtrl, decoration: _inputDeco('Vendor Name')),
          const SizedBox(height: 10),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: _inputDeco('Phone Number')),
          const SizedBox(height: 10),
          TextField(controller: gstinCtrl, decoration: _inputDeco('GSTIN (Optional)')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await widget.api.createVendor({'name': nameCtrl.text, 'phone': phoneCtrl.text, 'gstin': gstinCtrl.text});
                  setState(() => _future = widget.api.getVendors());
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text('Add Vendor', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVendorDialog,
        backgroundColor: const Color(0xFF0F172A),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Vendor', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final vendors = snap.data ?? [];
          if (vendors.isEmpty) return Center(child: Text('No vendors yet', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8))));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: vendors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final v = vendors[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.business_outlined, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v['name'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (v['phone'] != null && v['phone'].isNotEmpty)
                      Text(v['phone'], style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    if (v['gstin'] != null && v['gstin'].isNotEmpty)
                      Text('GSTIN: ${v['gstin']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ])),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Transfers Tab ────────────────────────────────────────────────────────────

class _TransfersTab extends StatefulWidget {
  final ApiService api;
  final User user;
  const _TransfersTab({required this.api, required this.user});

  @override
  State<_TransfersTab> createState() => _TransfersTabState();
}

class _TransfersTabState extends State<_TransfersTab> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.swap_horiz_outlined, size: 64, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 12),
        Text('Inter-site Transfers', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Text('Select a project pair to initiate\nor review a material transfer.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: const Color(0xFF94A3B8))),
      ]),
    );
  }
}

// ─── Low Stock Alerts Screen ──────────────────────────────────────────────────

class _LowStockScreen extends StatelessWidget {
  const _LowStockScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Low Stock Alerts', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      ),
      body: Center(child: Text('Configure min stock levels per material in the materials list to see alerts here.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 15))),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

InputDecoration _inputDeco(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: const Color(0xFFF8FAFC),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
);
