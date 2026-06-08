import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_document.dart';
import '../services/firestore_service.dart';
import 'driver_detail_screen.dart';
import 'user_detail_screen.dart';

class AllUsersScreen extends StatefulWidget {
  const AllUsersScreen({super.key});

  @override
  State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  final _service = AdminFirestoreService();
  String _searchQuery = '';
  late Stream<List<UserDocument>> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = _service.allUsersStream();
  }

  void _fullRefresh() {
    setState(() {
      _usersStream = _service.allUsersStream(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'All Users',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _fullRefresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Full refresh from server',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<List<UserDocument>>(
              stream: _usersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }
                final all = snapshot.data ?? [];
                final filtered = _searchQuery.isEmpty
                    ? all
                    : all.where((u) {
                        final q = _searchQuery.toLowerCase();
                        return u.displayName.toLowerCase().contains(q) ||
                            (u.phoneNumber?.contains(q) ?? false);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No users found'
                              : 'No results for "$_searchQuery"',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 15),
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
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _UserTile(user: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by name or phone...',
          hintStyle: const TextStyle(color: Colors.white60),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final UserDocument user;

  @override
  Widget build(BuildContext context) {
    final hasVerification = user.hasSubmittedDocs;
    final status = user.verification?.verificationStatus?.toLowerCase();

    final badges = <({String label, Color color})>[];
    if (user.isRegisteredDriver || user.isDriverApproved) {
      badges.add((label: 'Driver', color: const Color(0xFF6D4C41)));
    }
    if (user.isDriverApproved) {
      badges.add((label: 'Approved', color: const Color(0xFF2E7D32)));
    } else if (hasVerification && status == 'pending') {
      badges.add((label: 'Pending', color: const Color(0xFFE65100)));
    }
    if (!user.isEnabled) {
      badges.add((label: 'Disabled', color: Colors.red[700]!));
    }

    return GestureDetector(
      onTap: () {
        if (user.id == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserDetailScreen(userId: user.id!),
          ),
        );
      },
      onLongPress: hasVerification
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverDetailScreen(user: user),
                ),
              )
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _avatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: user.isEnabled
                                ? Colors.grey[900]
                                : Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final badge in badges) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badge.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badge.color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (user.phoneNumber != null)
                    Text(
                      user.phoneNumber!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  if (user.createdAt != null)
                    Text(
                      'Joined ${DateFormat('MMM d, yyyy').format(user.createdAt!)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                ],
              ),
            ),
            if (user.id != null)
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    if (user.hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CachedNetworkImage(
          imageUrl: user.photoURL!,
          width: 44,
          height: 44,
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(Icons.person_rounded,
          color: Color(0xFF1565C0), size: 24),
    );
  }
}
