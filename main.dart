import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Ensure the engine is ready
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://wunkujstxrjifcqefiju.supabase.co',
    anonKey: 'sb_publishable_skytJZ8rGKW7oZ2TwjIKIw_SRIOJmHv',
  );

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BaristaKDSPage(),
  ));
}

// ==========================================
// BARISTA KDS PAGE (Filtered for Paid Orders)
// ==========================================
class BaristaKDSPage extends StatefulWidget {
  const BaristaKDSPage({super.key});

  @override
  State<BaristaKDSPage> createState() => _BaristaKDSPageState();
}

class _BaristaKDSPageState extends State<BaristaKDSPage> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initTerminalSettings();
  }

  Future<void> _initTerminalSettings() async {
    await Future.delayed(const Duration(milliseconds: 100));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await _supabase.from('orders').update({'status': newStatus}).eq('id', id);
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            const Icon(Icons.coffee_maker, color: Colors.amber, size: 30),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FIXED: Changed FontWeight.black to FontWeight.bold
                const Text("BLISS TERMINAL", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
                Text("LIVE KITCHEN FEED", style: TextStyle(fontSize: 12, color: Colors.amber.withOpacity(0.8))),
              ],
            ),
          ],
        ),
        actions: [
          _buildStatChip("ACTIVE", Colors.white24),
          const SizedBox(width: 20),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase.from('orders').stream(primaryKey: ['id']).order('created_at', ascending: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));

          final activeOrders = snapshot.data!.where((order) {
            final String status = order['status']?.toString().toLowerCase() ?? 'pending';
            return status == 'paid' || status == 'preparing' || status == 'ready';
          }).toList();

          if (activeOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 100, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 20),
                  const Text("ALL CLEAR", style: TextStyle(color: Colors.white24, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.65,
            ),
            itemCount: activeOrders.length,
            itemBuilder: (context, index) {
              final order = activeOrders[index];
              return _buildModernOrderTicket(order);
            },
          );
        },
      ),
    );
  }

  Widget _buildModernOrderTicket(Map<String, dynamic> order) {
    final String status = order['status']?.toString().toLowerCase() ?? 'paid';
    final String timeLabel = _getTimeSinceOrder(order['created_at']);

    // Split the items summary into a list
    // This assumes items are separated by commas (e.g., "Latte, Muffin, Water")
    final List<String> items = (order['items_summary']?.toString() ?? "NEW ORDER")
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    Color statusColor;
    String btnText;
    String nextStatus;

    if (status == 'preparing') {
      statusColor = Colors.orange;
      btnText = "MARK AS READY";
      nextStatus = "ready";
    } else if (status == 'ready') {
      statusColor = Colors.green;
      btnText = "DONE / COLLECTED";
      nextStatus = "collected";
    } else {
      statusColor = const Color(0xFFE91E63);
      btnText = "START ORDER";
      nextStatus = "preparing";
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TICKET HEADER
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("#${order['id'].toString().substring(0, 4)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(timeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          // ITEMS LIST (VERTICAL)
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // This generates a vertical list of items
                    ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("• ", style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              item.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5
                              ),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white10),
                    Text("CUSTOMER: ${order['customer_name'] ?? 'Guest'}",
                        style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
          ),

          // ACTION BUTTON
          InkWell(
            onTap: () => _updateStatus(order['id'].toString(), nextStatus),
            child: Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                border: Border(top: BorderSide(color: statusColor.withOpacity(0.3))),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Center(
                child: Text(
                  btnText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  String _getTimeSinceOrder(String? timestamp) {
    if (timestamp == null) return "0m";
    final startTime = DateTime.tryParse(timestamp) ?? DateTime.now();
    final diff = DateTime.now().difference(startTime);
    if (diff.inMinutes < 1) return "NEW";
    return "${diff.inMinutes}m ago";
  }
}