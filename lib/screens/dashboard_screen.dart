import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../widgets/stat_card.dart';
import 'driver_verification_screen.dart';
import 'all_users_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = AdminFirestoreService();
  DashboardStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _service.getDashboardStats();
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, MMM d yyyy').format(DateTime.now());
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Responsive breakpoints
    final isWeb = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.local_taxi_rounded, color: Colors.white, size: 26),
            SizedBox(width: 10),
            Text(
              'CarPool Admin',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: Center(
          child: ConstrainedBox(
            // Center & cap width on web for a proper dashboard feel
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 40 : (isTablet ? 24 : 16),
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(today),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child:
                            CircularProgressIndicator(color: Color(0xFF1565C0)),
                      ),
                    )
                  else if (_error != null)
                    _buildError()
                  else if (_stats != null)
                    _buildStats(_stats!, isWeb: isWeb, isTablet: isTablet),
                  const SizedBox(height: 28),
                  _buildQuickActions(context, isWeb: isWeb),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String today) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard Overview',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          today,
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 48),
            const SizedBox(height: 12),
            Text(
              'Failed to load stats',
              style: TextStyle(color: Colors.grey[700], fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(
    DashboardStats stats, {
    required bool isWeb,
    required bool isTablet,
  }) {
    final crossAxisCount = isWeb ? 5 : (isTablet ? 3 : 2);

    final cards = [
      StatCard(
        title: 'Total Users',
        value: stats.totalUsers.toString(),
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF1565C0),
        subtitle: 'Registered accounts',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllUsersScreen()),
        ),
      ),
      StatCard(
        title: 'New Today',
        value: stats.newUsersToday.toString(),
        icon: Icons.person_add_alt_1_rounded,
        color: const Color(0xFF00897B),
        subtitle: 'Registered today',
      ),
      StatCard(
        title: 'Active Drivers',
        value: stats.usersWithCars.toString(),
        icon: Icons.directions_car_rounded,
        color: const Color(0xFF6D4C41),
        subtitle: 'Added vehicle docs',
      ),
      StatCard(
        title: 'Pending Review',
        value: stats.pendingVerifications.toString(),
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFE65100),
        subtitle: 'Awaiting approval',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverVerificationScreen(),
          ),
        ),
      ),
      StatCard(
        title: 'Approved Drivers',
        value: stats.approvedDrivers.toString(),
        icon: Icons.verified_rounded,
        color: const Color(0xFF2E7D32),
        subtitle: 'Verified & active',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const DriverVerificationScreen(filter: 'approved'),
          ),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Stats',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 14),
        _buildCardGrid(cards, crossAxisCount),
      ],
    );
  }

  Widget _buildCardGrid(List<Widget> cards, int crossAxisCount) {
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += crossAxisCount) {
      final rowCards = cards.sublist(
        i,
        (i + crossAxisCount).clamp(0, cards.length),
      );
      rows.add(
        // IntrinsicHeight makes all cards in the row as tall as the tallest one
        // Cards size to their own content — no fixed height, no overflow possible
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int j = 0; j < rowCards.length; j++) ...[
                Expanded(child: rowCards[j]),
                if (j < rowCards.length - 1) const SizedBox(width: 14),
              ],
              for (int k = rowCards.length; k < crossAxisCount; k++) ...[
                const SizedBox(width: 14),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
      if (i + crossAxisCount < cards.length) {
        rows.add(const SizedBox(height: 14));
      }
    }
    return Column(children: rows);
  }

  Widget _buildQuickActions(BuildContext context, {required bool isWeb}) {
    final actions = [
      _ActionData(
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFE65100),
        title: 'Review Pending Applications',
        subtitle: 'View submitted docs and approve or reject',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const DriverVerificationScreen(filter: 'pending'),
          ),
        ),
      ),
      _ActionData(
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF1565C0),
        title: 'All Users',
        subtitle: 'Browse all registered users',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllUsersScreen()),
        ),
      ),
      _ActionData(
        icon: Icons.verified_rounded,
        color: const Color(0xFF2E7D32),
        title: 'Approved Drivers',
        subtitle: 'View all verified drivers',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const DriverVerificationScreen(filter: 'approved'),
          ),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 14),
        if (isWeb)
          Row(
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                Expanded(child: _QuickActionTile(data: actions[i])),
                if (i < actions.length - 1) const SizedBox(width: 14),
              ],
            ],
          )
        else
          Column(
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                _QuickActionTile(data: actions[i]),
                if (i < actions.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }
}

class _ActionData {
  const _ActionData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data});
  final _ActionData data;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: data.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
