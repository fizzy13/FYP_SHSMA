import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_service.dart';
import '../models/user_model.dart';
import '../theme_helpers.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = AuthService();
    final isDark = theme.brightness == Brightness.dark;
    final bg = context.appBackground;
    final surface = context.secondarySurface;
    final borderColor = context.canvasBorder;
    final accent = theme.colorScheme.primary;
    final overlaySurface = isDark ? Colors.black45 : Colors.white.withAlpha(82);
    final imageErrorBg = isDark ? Colors.black54 : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: bg,
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
                  final headerName = snapshot.data?.fullName ??
                      currentUser?.displayName ??
                      (currentUser?.email?.split('@').first ?? 'Guest');

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
                        child: Icon(
                          Icons.notifications,
                          color: accent,
                          size: 20,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('devices').snapshots(),
                builder: (context, snapshot) {
                  final placeholderUrl = 'https://placehold.co/800x450?text=Camera+Stream';
                  String streamUrl = placeholderUrl;
                  String deviceLabel = 'CAM-01 • FRONT PORCH';

                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final firstDevice = snapshot.data!.docs.first.data();
                    streamUrl = firstDevice['stream_url'] as String? ?? placeholderUrl;
                    deviceLabel = firstDevice['device_name'] as String? ?? deviceLabel;
                  }

                  return Container(
                    height: 260,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.network(
                              streamUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: surface,
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(color: imageErrorBg);
                              },
                            ),
                          ),
                        ),
                        Container(
                          width: 140,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: accent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0C100E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PERSON DETECTED',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: const Color(0xFF0C100E),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 60,
                          left: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: overlaySurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD61F1F),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'LIVE • 4K',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: overlaySurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  deviceLabel,
                                  style: GoogleFonts.inter(
                                    color: context.mutedText,
                                    fontSize: 10,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          child: Column(
                            children: [
                              Text(
                                'Safe and Working',
                                style: GoogleFonts.inter(
                                  color: context.mutedText,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'CONFIDENCE:\n98.4%',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: overlaySurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.signal_cellular_4_bar,
                                  color: Color(0xFF4EEF9B),
                                  size: 12,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'STABLE',
                                  style: GoogleFonts.inter(
                                    color: accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF0C100E),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      Icons.volume_up,
                      color: isDark ? Colors.white54 : Colors.black54,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'CAPTURE      ',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 48),
                  Text(
                    'SOUND',
                    style: GoogleFonts.inter(
                      color: context.mutedText,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),
              Text(
                'NETWORK NODES',
                style: GoogleFonts.inter(
                  color: context.mutedText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('devices').snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final cards = docs.take(4).map((device) {
                    final data = device.data();
                    return _buildNodeCard(
                      context,
                      data['device_name'] as String? ?? 'DEVICE NODE',
                      null,
                      isActive: (data['status']?.toString().toLowerCase() == 'online'),
                    );
                  }).toList();

                  while (cards.length < 4) {
                    cards.add(_buildNodeCard(context, 'OFFLINE NODE', null));
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[1]),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeCard(
    BuildContext context,
    String title,
    String? imagePath, {
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = context.secondarySurface;
    final borderColor = context.canvasBorder;
    final accent = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? accent : borderColor,
          width: isActive ? 2 : 1,
        ),
        image: imagePath != null
            ? DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
                colorFilter: isActive
                    ? null
                    : ColorFilter.mode(
                        isDark ? Colors.black.withAlpha(128) : Colors.white.withAlpha(46),
                        BlendMode.darken,
                      ),
              )
            : null,
      ),
      child: Stack(
        children: [
          if (isActive)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0C100E),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isActive ? onSurface : context.mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.videocam,
                  color: isActive ? accent : context.mutedText,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
