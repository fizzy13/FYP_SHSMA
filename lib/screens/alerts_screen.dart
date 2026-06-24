import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth_service.dart';
import '../models/user_model.dart';
import '../services/security_event_service.dart';
import '../theme_helpers.dart';
import 'camera_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String? _lastShownAlertId;

  Future<void> _confirmAndCallPolice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Call Police',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Call 999?',
            style: GoogleFonts.inter(),
          ),
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

    final uri = Uri(scheme: 'tel', path: '999');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open phone dialer for 999.')),
      );
    }
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
    final panel = context.tertiarySurface;
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
                    ? authService.getUserInfoStreamByUid(authService.currentUser!.uid)
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor),
                        ),
                        child: Icon(Icons.notifications, color: accent, size: 20),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Text('Security Alerts', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: onSurface)),
              const SizedBox(height: 8),
              Text('REAL-TIME SURVEILLANCE MONITORING', style: GoogleFonts.inter(fontSize: 11, color: muted, letterSpacing: 1.5)),
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

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: const Color(0xFFD61F1F).withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No alerts yet', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface)),
                              const SizedBox(height: 8),
                              Text('Your system is running smoothly. No new security alerts found.', style: GoogleFonts.inter(fontSize: 12, color: muted, height: 1.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    );
                  }

                  final latestDoc = docs.first;
                  final latest = latestDoc.data();
                  final alertType = latest['type'] as String? ?? latest['alerts'] as String? ?? 'SECURITY';
                  final alertMessage = latest['message'] as String? ?? 'New alert received';
                  final alertLocation = latest['location'] as String? ?? 'Unknown location';
                  final alertStatus = latest['status'] as String? ?? 'ACTIVE';
                  final alertTime = _formatTimestamp(latest['timestamp']);

                  if (alertStatus.toUpperCase() == 'LIVE' && _lastShownAlertId != latestDoc.id) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _lastShownAlertId = latestDoc.id;
                      showDialog<void>(
                        context: context,
                        barrierDismissible: true,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: surface,
                            title: Text('Motion Detected', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            content: Text(alertMessage, style: GoogleFonts.inter()),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text('Dismiss', style: GoogleFonts.outfit(color: accent)),
                              ),
                            ],
                          );
                        },
                      );
                    });
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (alertStatus.toUpperCase() == 'LIVE')
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.wifi_tethering, color: Color(0xFFFF6B6B), size: 18),
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
                          border: Border.all(color: const Color(0xFFD61F1F).withValues(alpha: 0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFD61F1F).withValues(alpha: 0.05), blurRadius: 40, spreadRadius: 5),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFFFF6B6B), borderRadius: BorderRadius.circular(12)),
                                      child: Text('LIVE FEED', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Text('$alertLocation • $alertTime', style: GoogleFonts.inter(color: Colors.white, fontSize: 10)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B6B), size: 24),
                                const SizedBox(width: 8),
                                Text(alertType, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFFF6B6B))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(alertLocation, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                            const SizedBox(height: 12),
                            Text(alertMessage, style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, height: 1.5)),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const CameraScreen()),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accent,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    ),
                                    child: Text('VIEW\nCAMERA', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF0C100E), fontSize: 11)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _confirmAndCallPolice,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: surface,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    ),
                                    child: Text('CALL POLICE', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      ...docs.take(3).map((alert) {
                        final data = alert.data();
                        return _buildEventCard(
                          context,
                          data['type'] as String? ?? 'Alert',
                          data['location'] as String? ?? 'Unknown location',
                          _formatTimestamp(data['timestamp']),
                          data['status'] as String? ?? 'SYSTEM',
                          data['message'] as String? ?? '',
                          null,
                          labelColor: const Color(0xFFFF6B6B),
                        );
                      }),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('RECENT EVENTS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted, letterSpacing: 2.0)),
                  Text('TODAY, OCT 24', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: accent, letterSpacing: 1.0)),
                ],
              ),
              const SizedBox(height: 16),
              
              _buildEventCard(context, 'Vehicle\nDetected', 'Driveway Main\nEntrance', '14:22 PM', 'AI\nRECOGNITION', 'Normal\nActivity', 'assets/vehicle_event.png'),
              _buildEventCard(context, 'Animal Spotted', 'Front Porch Camera', '11:05 AM', 'PIR SENSOR', 'Ignored Alert', null),
              _buildEventCard(context, 'Package\nDelivered', 'Side Entrance', '09:40 AM', 'AI LABEL', 'Delivery Confirmed', null, labelColor: const Color(0xFF4EEF9B)),
              
              const SizedBox(height: 32),
              Text('YESTERDAY', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted, letterSpacing: 2.0)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.wifi_off, color: Colors.white30, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Connection Lost', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
                              Text('23:15 PM', style: GoogleFonts.inter(fontSize: 10, color: Colors.white30)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Garage Wi-Fi Node', style: GoogleFonts.inter(fontSize: 12, color: muted)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFD61F1F).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                                child: Text('SYSTEM LOG', style: GoogleFonts.inter(color: const Color(0xFFD61F1F), fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Text('AUTO-RESOLVED', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFD61F1F))),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, String title, String subtitle, String time, String tag, String note, String? imagePath, {Color? labelColor}) {
    final theme = Theme.of(context);
    final surface = context.secondarySurface;
    final borderColor = context.canvasBorder;
    final accent = theme.colorScheme.primary;
    final muted = context.mutedText;
    final panel = context.tertiarySurface;
    final noteColor = labelColor ?? context.mutedText;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
           Container(
             width: 80,
             height: 80,
             decoration: BoxDecoration(
               color: const Color(0xFF1D221F),
               borderRadius: BorderRadius.circular(16),
               image: imagePath != null ? DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover) : null,
             ),
             child: imagePath == null ? Icon(Icons.image_outlined, color: borderColor) : null,
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
                     Expanded(child: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white))),
                     Text(time, style: GoogleFonts.inter(fontSize: 10, color: muted)),
                   ],
                 ),
                 const SizedBox(height: 4),
                 Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: muted)),
                 const SizedBox(height: 12),
                 Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                       decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12)),
                       child: Text(tag.replaceAll('\n', ' '), style: GoogleFonts.inter(color: accent, fontSize: 9, fontWeight: FontWeight.bold)),
                     ),
                     const SizedBox(width: 8),
                     Expanded(child: Text(note.replaceAll('\n', ' '), style: GoogleFonts.inter(fontSize: 10, color: noteColor), overflow: TextOverflow.ellipsis)),
                   ],
                 ),
               ],
             ),
           ),
           const SizedBox(width: 8),
           Icon(Icons.chevron_right, color: muted, size: 20),
        ],
      ),
    );
  }
}
