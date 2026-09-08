import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../auth_service.dart';
import '../models/user_model.dart';
import '../services/security_event_service.dart';
import '../theme_helpers.dart';
import 'camera_screen.dart';
import 'welcome_screen.dart';

class AlertsScreen extends StatefulWidget {
  final VoidCallback? onOpenCamera;

  const AlertsScreen({super.key, this.onOpenCamera});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String? _lastShownAlertId;
  bool _receivedInitialAlerts = false;
  final ScrollController _alertsScrollController = ScrollController();

  @override
  void dispose() {
    _alertsScrollController.dispose();
    super.dispose();
  }

  Future<void> _showAiVideo(String videoUrl) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AiDetectionVideoDialog(videoUrl: videoUrl),
    );
  }

  Future<void> _confirmAndCallPolice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Call Police',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text('Call 999?', style: GoogleFonts.inter()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: GoogleFonts.outfit()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Confirm', style: GoogleFonts.outfit()),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final uri = Uri(scheme: 'tel', path: '01123228455');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open phone dialer for 999.')),
      );
    }
  }

  Future<void> _clearAllAlerts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear All Notifications?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will remove all current motion alert notifications.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear All', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final collection = FirebaseFirestore.instance.collection(
        kAlertsCollectionName,
      );
      final snapshots = await collection.get();
      for (final doc in snapshots.docs) {
        final uid = doc.data()['userId'] as String?;
        if (uid == null || uid.isEmpty || uid == currentUid) {
          await doc.reference.delete();
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear notifications: $e')),
        );
      }
    }
  }

  Future<void> _deleteAlert(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection(kAlertsCollectionName)
          .doc(docId)
          .delete();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _simulateTapoMotionAlert() async {
    final securityService = SecurityEventService();
    final now = DateTime.now();
    final formattedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    await securityService.createMotionAlertAndLog(
      cameraLabel: 'Front Camera',
      message: '"Front Camera": Motion was detected at $formattedTime.',
      sourceIp: '192.168.0.11',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test Front Camera Motion Alert generated.'),
      ),
    );
  }

  String _displayNameFromUser(User? user) {
    final fullName = user?.displayName;
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.contains('@') ? email.split('@').first : email;
    }

    return 'User';
  }

  Future<void> _handleSignOut(
    BuildContext context,
    AuthService authService,
  ) async {
    await authService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate().toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (timestamp is DateTime) {
      final dt = timestamp.toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return timestamp?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = AuthService();
    final surface = context.secondarySurface;
    final borderColor = context.canvasBorder;
    final accent = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final muted = context.mutedText;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              StreamBuilder<UserInfo?>(
                stream: authService.currentUser?.uid != null
                    ? authService.getUserInfoStreamByUid(
                        authService.currentUser!.uid,
                      )
                    : Stream<UserInfo?>.value(null),
                builder: (context, snapshot) {
                  final currentUser = authService.currentUser;
                  final headerName = snapshot.data?.fullName.isNotEmpty == true
                      ? snapshot.data!.fullName
                      : _displayNameFromUser(currentUser);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundImage: AssetImage('assets/avatar.png'),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            headerName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: accent,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: borderColor),
                            ),
                            child: Icon(
                              Icons.notifications,
                              color: accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                _handleSignOut(context, authService),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Security Alerts',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'REAL-TIME SURVEILLANCE MONITORING',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: muted,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              const SizedBox(height: 32),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection(kAlertsCollectionName)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final currentUid = authService.currentUser?.uid;
                  final rawDocs = snapshot.data?.docs ?? [];
                  final docs = rawDocs.where((doc) {
                    final uid = doc.data()['userId'] as String?;
                    return uid == null || uid.isEmpty || uid == currentUid;
                  }).toList();

                  if (docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 36,
                      ),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 56,
                            color: muted.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No motion detected. Your system is running smoothly.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: muted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _simulateTapoMotionAlert,
                            icon: const Icon(Icons.videocam_outlined, size: 18),
                            label: Text(
                              'Simulate Tapo Motion Alert',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: BorderSide(color: accent.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final latestDoc = docs.first;
                  final latest = latestDoc.data();
                  final alertType =
                      latest['type'] as String? ??
                      latest['alerts'] as String? ??
                      'Motion Alert';
                  final alertMessage =
                      latest['message'] as String? ??
                      'Motion detected at camera';
                  final alertLocation =
                      latest['location'] as String? ?? 'Tapo Camera';
                  final alertStatus = latest['status'] as String? ?? 'ACTIVE';
                  final alertTime = _formatTimestamp(latest['timestamp']);

                  QueryDocumentSnapshot<Map<String, dynamic>>? latestAiDoc;
                  for (final doc in docs) {
                    final data = doc.data();
                    final img = data['imageUrl'] as String?;
                    final cls = data['detectedClass'] as String?;
                    if (img != null &&
                        img.isNotEmpty &&
                        cls != null &&
                        cls.isNotEmpty) {
                      latestAiDoc = doc;
                      break;
                    }
                  }

                  final aiSnapshotData = latestAiDoc?.data();
                  final aiImageUrl = aiSnapshotData?['imageUrl'] as String?;
                  final aiLocation =
                      aiSnapshotData?['location'] as String? ?? alertLocation;
                  final aiTime = latestAiDoc != null
                      ? _formatTimestamp(aiSnapshotData?['timestamp'])
                      : alertTime;
                  final hasAiSnapshot =
                      aiImageUrl != null && aiImageUrl.isNotEmpty;

                  if (_receivedInitialAlerts &&
                      alertStatus.toUpperCase() == 'LIVE' &&
                      _lastShownAlertId != latestDoc.id) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _lastShownAlertId = latestDoc.id;
                      showDialog<void>(
                        context: context,
                        barrierDismissible: true,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: surface,
                            title: Text(
                              alertType,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              alertMessage,
                              style: GoogleFonts.inter(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Dismiss',
                                  style: GoogleFonts.outfit(color: accent),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    });
                  }

                  _receivedInitialAlerts = true;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (alertStatus.toUpperCase() == 'LIVE')
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFF6B6B).withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.wifi_tethering,
                                color: Color(0xFFFF6B6B),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'LIVE ALERT: $alertMessage',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFFF6B6B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: const Color(
                              0xFFD61F1F,
                            ).withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFD61F1F,
                              ).withValues(alpha: 0.05),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasAiSnapshot) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        aiImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Colors.black54),
                                      ),
                                      Positioned(
                                        top: 12,
                                        left: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: const Color(0xFFFF6B6B), borderRadius: BorderRadius.circular(12)),
                                          child: Text('AI SNAPSHOT', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 12,
                                        right: 12,
                                        child: Text('$aiLocation • $aiTime', style: GoogleFonts.inter(color: Colors.white, fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFFF6B6B),
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  alertType,
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFF6B6B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              alertLocation,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              alertMessage,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white54,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (widget.onOpenCamera != null) {
                                        widget.onOpenCamera!();
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const CameraScreen(),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    child: Text(
                                      'VIEW\nCAMERA',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0C100E),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _confirmAndCallPolice,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: surface,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    child: Text(
                                      'CALL POLICE',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'LIVE NOTIFICATIONS (${docs.length})',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: muted,
                              letterSpacing: 1.5,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _clearAllAlerts,
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            label: Text(
                              'Clear All',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: Scrollbar(
                          controller: _alertsScrollController,
                          thumbVisibility: docs.length > 3,
                          child: ListView.builder(
                            controller: _alertsScrollController,
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final alertDoc = docs[index];
                              final data = alertDoc.data();
                              final docId = alertDoc.id;
                              final type =
                                  data['type'] as String? ??
                                  data['alerts'] as String? ??
                                  'Motion Alert';
                              final location =
                                  data['location'] as String? ?? 'Tapo Camera';
                              final message =
                                  data['message'] as String? ??
                                  'Motion detected';
                              final time = _formatTimestamp(data['timestamp']);
                              final status =
                                  data['status'] as String? ?? 'LIVE';
                              final itemImageUrl = data['imageUrl'] as String?;
                              final itemVideoUrl = data['videoUrl'] as String?;

                              return _buildEventCard(
                                context,
                                type,
                                location,
                                time,
                                status,
                                message,
                                itemImageUrl,
                                videoUrl: itemVideoUrl,
                                labelColor: const Color(0xFFFF6B6B),
                                onDelete: () => _deleteAlert(docId),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    String title,
    String subtitle,
    String time,
    String tag,
    String note,
    String? imagePath, {
    String? videoUrl,
    Color? labelColor,
    VoidCallback? onDelete,
  }) {
    final theme = Theme.of(context);
    final surface = context.secondarySurface;
    final accent = theme.colorScheme.primary;
    final muted = context.mutedText;
    final panel = context.tertiarySurface;
    final noteColor = labelColor ?? context.mutedText;

    return InkWell(
      onTap: videoUrl == null ? null : () => _showAiVideo(videoUrl),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF1D221F),
              borderRadius: BorderRadius.circular(16),
                image: imagePath != null
                  ? DecorationImage(
                image: NetworkImage(imagePath),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imagePath == null
                ? Icon(Icons.videocam_outlined, color: accent, size: 28)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.inter(fontSize: 10, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag.replaceAll('\n', ' '),
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note.replaceAll('\n', ' '),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: noteColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white30, size: 18),
                onPressed: onDelete,
              )
            else
              Icon(Icons.chevron_right, color: muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AiDetectionVideoDialog extends StatefulWidget {
  const _AiDetectionVideoDialog({required this.videoUrl});

  final String videoUrl;

  @override
  State<_AiDetectionVideoDialog> createState() => _AiDetectionVideoDialogState();
}

class _AiDetectionVideoDialogState extends State<_AiDetectionVideoDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initialization = _controller.initialize().then((_) {
      _controller.play();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI Detection Recording'),
      content: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !_controller.value.isInitialized) {
            return const Text('The recording could not be loaded.');
          }
          return AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
