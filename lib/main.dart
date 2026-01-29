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

  // NOTE: This function is kept for fallback, but the main logic moved to the Card widget
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
                stream: _supabase.from('profiles').stream(primaryKey: ['id']),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));

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
                          title: Text(user['name'] ?? user['email'] ?? "Customer", style: const TextStyle(color: Colors.white)),
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
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStatsBar(),
            Expanded(child: _buildOrdersGrid()),
          ],
        ),
      ),
      floatingActionButton: _buildQuickActions(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF238636),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.coffee, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("BLISS KITCHEN DISPLAY", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text("Real-time Order Management", style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                const Text("LIVE", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('orders').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final orders = snapshot.data!;
        final pendingCount = orders.where((o) => o['status'] == 'paid').length;
        final preparingCount = orders.where((o) => o['status'] == 'preparing').length;
        final readyCount = orders.where((o) => o['status'] == 'ready').length;

        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildStatCard("PENDING", pendingCount, const Color(0xFFE91E63)),
              const SizedBox(width: 12),
              _buildStatCard("PREPARING", preparingCount, const Color(0xFFFF9800)),
              const SizedBox(width: 12),
              _buildStatCard("READY", readyCount, const Color(0xFF4CAF50)),
              const Spacer(),
              _buildQuickActionBtn(Icons.refresh, "REFRESH", () => setState(() {})),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Text(count.toString(), style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn(IconData icon, String label, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersGrid() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('orders')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF238636)));
        }

        final activeOrders = snapshot.data!.where((order) {
          final String status = order['status']?.toString().toLowerCase() ?? 'pending';
          final bool isCorrectStatus = ['paid', 'preparing', 'ready'].contains(status);
          final bool isBulk = order['is_bulk'] == true;
          return isCorrectStatus && !isBulk;
        }).toList();

        if (activeOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF238636), size: 48),
                ),
                const SizedBox(height: 16),
                const Text("ALL ORDERS COMPLETE", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text("Ready for new orders", style: TextStyle(color: Color(0xFF8B949E), fontSize: 14)),
              ],
            ),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _enrichOrdersWithCustomerNames(activeOrders),
          builder: (context, enrichedSnapshot) {
            if (!enrichedSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF238636)));
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.6,
                ),
                itemCount: enrichedSnapshot.data!.length,
                // CHANGED: Now using the Stateful Card Widget
                itemBuilder: (context, index) => OrderTicketCard(order: enrichedSnapshot.data![index]),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _enrichOrdersWithCustomerNames(List<Map<String, dynamic>> orders) async {
    final List<Map<String, dynamic>> enrichedOrders = [];

    for (final order in orders) {
      final enrichedOrder = Map<String, dynamic>.from(order);

      if (order['user_id'] != null) {
        try {
          final profileData = await _supabase
              .from('profiles')
              .select('name')
              .eq('id', order['user_id'])
              .maybeSingle();

          if (profileData != null && profileData['name'] != null) {
            enrichedOrder['customer_name'] = profileData['name'];
          }
        } catch (e) {
          debugPrint("Error fetching customer name: $e");
        }
      }

      enrichedOrders.add(enrichedOrder);
    }

    return enrichedOrders;
  }

  Widget _buildQuickActions() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF238636),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF238636).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showRewardLookup,
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_activity, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text("REWARDS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// NEW CLASS: Handles the Optimistic (Instant) UI Updates
// -------------------------------------------------------------------------
class OrderTicketCard extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderTicketCard({super.key, required this.order});

  @override
  State<OrderTicketCard> createState() => _OrderTicketCardState();
}

class _OrderTicketCardState extends State<OrderTicketCard> {
  late String _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    // Initialize status from the data passed in
    _currentStatus = widget.order['status']?.toString().toLowerCase() ?? 'paid';
  }

  @override
  void didUpdateWidget(OrderTicketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If Supabase sends a new update from the stream, sync our local state
    // (Only if we aren't currently middle-of-clicking)
    if (!_isUpdating) {
      final streamStatus = widget.order['status']?.toString().toLowerCase() ?? 'paid';
      if (streamStatus != _currentStatus) {
        setState(() {
          _currentStatus = streamStatus;
        });
      }
    }
  }

  Future<void> _handleOptimisticUpdate() async {
    // 1. Calculate the next status
    String nextStatus = _currentStatus == 'preparing' ? "ready" :
    (_currentStatus == 'ready' ? "collected" : "preparing");

    String oldStatus = _currentStatus;

    // 2. INSTANTLY update the UI (Optimistic)
    setState(() {
      _currentStatus = nextStatus;
      _isUpdating = true; // Prevent stream from overwriting us while we work
    });

    // 3. Send to Supabase in background
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'status': nextStatus})
          .eq('id', widget.order['id']);

      // Success! We don't need to do anything, the Stream will eventually catch up
    } catch (e) {
      debugPrint("Error updating order: $e");
      // 4. Revert if there was an error (Rollback)
      if (mounted) {
        setState(() {
          _currentStatus = oldStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection failed. Retrying...")));
      }
    } finally {
      if(mounted) setState(() => _isUpdating = false);
    }
  }

  String _getTimeSinceOrder(String? timestamp) {
    if (timestamp == null) return "0m";
    final startTime = DateTime.tryParse(timestamp) ?? DateTime.now();
    final diff = DateTime.now().difference(startTime);
    if (diff.inMinutes < 1) return "NEW";
    return "${diff.inMinutes}m ago";
  }

  @override
  Widget build(BuildContext context) {
    final String timeLabel = _getTimeSinceOrder(widget.order['created_at']);
    final String orderId = "#${widget.order['id'].toString().substring(0, 6).toUpperCase()}";

    final List<String> items = (widget.order['items_summary']?.toString() ?? "NEW ORDER")
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Use LOCAL _currentStatus for colors and text
    Color statusColor = _currentStatus == 'preparing' ? const Color(0xFFFF9800) :
    (_currentStatus == 'ready' ? const Color(0xFF4CAF50) : const Color(0xFFE91E63));

    String btnText = _currentStatus == 'preparing' ? "MARK READY" :
    (_currentStatus == 'ready' ? "COMPLETE" : "START PREP");

    bool isUrgent = DateTime.now().difference(DateTime.tryParse(widget.order['created_at']) ?? DateTime.now()).inMinutes > 10;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleOptimisticUpdate, // Call the instant update function
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUrgent ? const Color(0xFFE91E63).withOpacity(0.5) : Colors.white.withOpacity(0.1),
              width: isUrgent ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.3))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        orderId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "URGENT",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        timeLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Order items
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ORDER ITEMS",
                        style: TextStyle(
                          color: const Color(0xFF8B949E),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      items[index].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Color(0xFF8B949E), size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.order['customer_name'] ?? 'GUEST',
                                style: const TextStyle(
                                  color: Color(0xFF8B949E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action button area
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(top: BorderSide(color: statusColor.withOpacity(0.3))),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _currentStatus == 'preparing' ? Icons.check_circle :
                        _currentStatus == 'ready' ? Icons.done_all : Icons.play_arrow,
                        color: statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        btnText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}