import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import '../models/user_document.dart';
import '../services/firestore_service.dart';

class DriverDetailScreen extends StatelessWidget {
  const DriverDetailScreen({super.key, required this.user});
  final UserDocument user;

  @override
  Widget build(BuildContext context) {
    final ver = user.verification;
    final service = AdminFirestoreService();
    final status = ver?.verificationStatus?.toLowerCase() ?? '';
    final isApproved = user.isDriverApproved;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Driver Application',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(),
            const SizedBox(height: 16),
            _buildStatusBanner(status),
            const SizedBox(height: 20),
            _sectionTitle('CNIC (National ID)'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DocImageCard(
                    label: 'Front',
                    url: ver?.cnicFrontUrl,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DocImageCard(
                    label: 'Back',
                    url: ver?.cnicBackUrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle("Driver's License"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DocImageCard(
                    label: 'Front',
                    url: ver?.licenseFrontUrl,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DocImageCard(
                    label: 'Back',
                    url: ver?.licenseBackUrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Vehicle Documents'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DocImageCard(
                    label: 'Front',
                    url: ver?.vehicleDocFrontUrl,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DocImageCard(
                    label: 'Back',
                    url: ver?.vehicleDocBackUrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (!isApproved && status != 'rejected')
              _buildActionButtons(context, service, isApproved: isApproved),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
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
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user.phoneNumber != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        user.phoneNumber!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
                if (user.gender != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        user.gender!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
                if (user.createdAt != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Joined ${DateFormat('MMM d, yyyy').format(user.createdAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'approved':
      case 'verified':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
        label = 'Application Approved';
        break;
      case 'rejected':
        bg = const Color(0xFFFFEBEE);
        fg = Colors.red[700]!;
        icon = Icons.cancel_rounded;
        label = 'Application Rejected';
        break;
      default:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        icon = Icons.pending_actions_rounded;
        label = 'Pending Review';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    AdminFirestoreService service, {
    required bool isApproved,
  }) {
    return Row(
      children: [
        if (!isApproved)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _confirmAction(
                context,
                title: 'Approve Driver',
                message:
                    'Are you sure you want to approve ${user.displayName} as a driver?',
                confirmLabel: 'Approve',
                confirmColor: const Color(0xFF2E7D32),
                onConfirm: () async {
                  await service.approveDriver(user.id!);
                  if (context.mounted) {
                    _showSnackBar(
                      context,
                      'Driver approved — active rides marked Verified on Explore.',
                      isSuccess: true,
                    );
                    Navigator.pop(context);
                  }
                },
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (!isApproved) const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirmAction(
              context,
              title: 'Reject Application',
              message:
                  'Are you sure you want to reject ${user.displayName}\'s application?',
              confirmLabel: 'Reject',
              confirmColor: Colors.red[700]!,
              onConfirm: () async {
                await service.rejectDriver(user.id!);
                if (context.mounted) {
                  _showSnackBar(context, 'Application rejected.',
                      isSuccess: false);
                  Navigator.pop(context);
                }
              },
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[700],
              side: BorderSide(color: Colors.red[300]!),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required Future<void> Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await onConfirm();
              } catch (e) {
                if (context.mounted) {
                  _showSnackBar(context, 'Error: $e', isSuccess: false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF2E7D32) : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _avatar() {
    if (user.hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: CachedNetworkImage(
          imageUrl: user.photoURL!,
          width: 60,
          height: 60,
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
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Color(0xFF1565C0),
        size: 32,
      ),
    );
  }
}

class _DocImageCard extends StatelessWidget {
  const _DocImageCard({required this.label, required this.url});
  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasImage = url != null && url!.trim().isNotEmpty;

    return GestureDetector(
      onTap: hasImage
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _FullImageViewer(url: url!, label: label),
                ),
              )
          : null,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasImage
                ? const Color(0xFF1565C0).withValues(alpha: 0.2)
                : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: url!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      errorWidget: (_, _, _) => _emptyState(),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black45,
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : _emptyState(),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_not_supported_outlined,
            color: Colors.grey[300], size: 28),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
        Text(
          'Not uploaded',
          style: TextStyle(fontSize: 10, color: Colors.grey[300]),
        ),
      ],
    );
  }
}

class _FullImageViewer extends StatelessWidget {
  const _FullImageViewer({required this.url, required this.label});
  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(label, style: const TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(url),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, _) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
