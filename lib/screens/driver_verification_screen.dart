import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_document.dart';
import '../services/firestore_service.dart';
import 'driver_detail_screen.dart';

class DriverVerificationScreen extends StatefulWidget {
  const DriverVerificationScreen({super.key, this.filter = 'pending'});

  /// 'pending' | 'approved' | 'all'
  final String filter;

  @override
  State<DriverVerificationScreen> createState() =>
      _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen> {
  final _service = AdminFirestoreService();
  late Stream<List<UserDocument>> _usersStream;

  @override
  void initState() {
    super.initState();
    _reloadStream();
  }

  void _reloadStream({bool forceRefresh = false}) {
    _usersStream = switch (widget.filter) {
      'approved' => _service.approvedDriversStream(forceRefresh: forceRefresh),
      _ => _service.pendingVerificationStream(forceRefresh: forceRefresh),
    };
  }

  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;

    final title = switch (filter) {
      'approved' => 'Approved Drivers',
      _ => 'Pending Applications',
    };

    final emptyMessage = switch (filter) {
      'approved' => 'No approved drivers yet.',
      _ => 'No pending applications.',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _reloadStream(forceRefresh: true)),
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Full refresh from server',
          ),
        ],
      ),
      body: StreamBuilder<List<UserDocument>>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading data',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            );
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _service.syncUsers(forceFullRefresh: true),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _DriverCard(user: users[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.user});
  final UserDocument user;

  @override
  Widget build(BuildContext context) {
    final status = user.verification?.verificationStatus?.toLowerCase() ?? '';
    final submittedAt = user.updatedAt ?? user.createdAt;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'approved':
      case 'verified':
        statusColor = const Color(0xFF2E7D32);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Approved';
        break;
      case 'rejected':
        statusColor = Colors.red[700]!;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = const Color(0xFFE65100);
        statusIcon = Icons.pending_rounded;
        statusLabel = 'Pending';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverDetailScreen(user: user),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _avatar(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (user.phoneNumber != null)
                    Text(
                      user.phoneNumber!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  if (submittedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Submitted ${DateFormat('MMM d, yyyy').format(submittedAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    if (user.hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: CachedNetworkImage(
          imageUrl: user.photoURL!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          placeholder: (_, _) => _defaultAvatar(),
          errorWidget: (_, _, _) => _defaultAvatar(),
        ),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Color(0xFF1565C0),
        size: 28,
      ),
    );
  }
}
