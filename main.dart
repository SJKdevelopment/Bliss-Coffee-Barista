import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wunkujstxrjifcqefiju.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1bmt1anN0eHJqaWZjcWVmaWp1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NjM3OTQxNiwiZXhwIjoyMDgxOTU1NDE2fQ.yRXzeqTEaZtXfcUgJvRh7W_Lb0lYT7rD4H--sZKo7ww',
  );

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BaristaKDSPage(),
  ));
}

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

  /// Logic to redeem either a Loyalty or Referral reward
  Future<void> _redeemReward(String profileId, String? loyaltyCode, String? refCode) async {
    try {
      Map<String, dynamic> updateData = {'is_redeemed': true};

      if (loyaltyCode != null) {
        updateData['loyalty_redemption_code'] = null;
        updateData['stamps_count'] = 0;
      } else if (refCode != null) {
        updateData['redemption_code'] = null;
      }

      // Add .select() at the end to force Supabase to return the updated data
      // If 'data' is empty, it means RLS blocked the update or the ID was wrong.
      final data = await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', profileId)
          .select();

      if (data.isEmpty) {
        throw Exception("No rows updated. Check RLS policies!");
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reward Redeemed!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Redemption Error: $e");
      // Show the actual error to the Barista so they know it didn't save
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _showRewardLookup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("ACTIVE REWARD CODES", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                // Listen for any user that has a code in either column
                stream: _supabase.from('profiles').stream(primaryKey: ['id']),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));

                  // Filter users with at least one active (unredeemed) code
                  final eligibleUsers = snapshot.data!.where((user) {
                    bool hasLoyalty = user['loyalty_redemption_code'] != null;
                    bool hasReferral = user['redemption_code'] != null;
                    return hasLoyalty || hasReferral;
                  }).toList();

                  if (eligibleUsers.isEmpty) return const Center(child: Text("No active rewards", style: TextStyle(color: Colors.white24)));

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: eligibleUsers.length,
                    itemBuilder: (context, index) {
                      final user = eligibleUsers[index];
                      final lCode = user['loyalty_redemption_code'];
                      final rCode = user['redemption_code'];

                      return Card(
                        color: Colors.white.withOpacity(0.05),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Icon(
                              Icons.card_giftcard,
                              color: lCode != null ? Colors.brown[300] : Colors.green[300]
                          ),
                          title: Text(user['email'] ?? "Customer", style: const TextStyle(color: Colors.white)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (lCode != null) Text("LOYALTY: $lCode", style: TextStyle(color: Colors.brown[200])),
                              if (rCode != null) Text("REFERRAL: $rCode", style: TextStyle(color: Colors.green[200])),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _redeemReward(user['id'], lCode, rCode),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("CLAIM"),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("BLISS TERMINAL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRewardLookup,
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.local_activity, color: Colors.black),
        label: const Text("REWARDS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase.from('orders').stream(primaryKey: ['id']).order('created_at', ascending: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));

          final activeOrders = snapshot.data!.where((order) {
            final String status = order['status']?.toString().toLowerCase() ?? 'pending';
            final bool isCorrectStatus = ['paid', 'preparing', 'ready'].contains(status);
            final bool isBulk = order['is_bulk'] == true;
            return isCorrectStatus && !isBulk;
          }).toList();

          if (activeOrders.isEmpty) {
            return const Center(
              child: Text("ALL CLEAR", style: TextStyle(color: Colors.white24, fontSize: 32, fontWeight: FontWeight.bold)),
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
            itemBuilder: (context, index) => _buildModernOrderTicket(activeOrders[index]),
          );
        },
      ),
    );
  }

  Widget _buildModernOrderTicket(Map<String, dynamic> order) {
    final String status = order['status']?.toString().toLowerCase() ?? 'paid';
    final String timeLabel = _getTimeSinceOrder(order['created_at']);

    final List<String> items = (order['items_summary']?.toString() ?? "NEW ORDER")
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    Color statusColor = status == 'preparing' ? Colors.orange : (status == 'ready' ? Colors.green : const Color(0xFFE91E63));
    String btnText = status == 'preparing' ? "MARK AS READY" : (status == 'ready' ? "DONE / COLLECTED" : "START ORDER");
    String nextStatus = status == 'preparing' ? "ready" : (status == 'ready' ? "collected" : "preparing");

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: statusColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("#${order['id'].toString().substring(0, 4)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                Text(timeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items.map((item) => Text("• ${item.toUpperCase()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                  const Spacer(),
                  Text("CUST: ${order['customer_name'] ?? 'Guest'}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => _updateStatus(order['id'].toString(), nextStatus),
            child: Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
              child: Center(child: Text(btnText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
            ),
          ),
        ],
      ),
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
