import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme_helpers.dart';
import 'welcome_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // Switches state
  bool _humanDetection = true;
  bool _faceRecognition = true;
  bool _petFiltering = false;

  // Navigation state
  int _currentPage = 0; // 0: Dashboard, 1: Camera, 2: Statistics, 3: Shield
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            if (_currentPage == 0)
              _buildDashboard()
            else if (_currentPage == 1)
              _buildCameraPage()
            else if (_currentPage == 2)
              _buildStatisticsPage()
            else
              _buildShieldPage(),

            // Semi-transparent backdrop when settings is open
            if (_showSettings)
              GestureDetector(
                onTap: () => setState(() => _showSettings = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),

            // Settings sidebar
            if (_showSettings)
              _buildSettingsOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      extendBody: true,
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: 32),
          _buildTitle(),
          const SizedBox(height: 32),
          _buildManageUsersCard(),
          const SizedBox(height: 24),
          _buildAiDetectionCard(),
          const SizedBox(height: 24),
          _buildManageDevicesCard(),
          const SizedBox(height: 24),
          _buildSystemLogsCard(),
          const SizedBox(height: 100), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildCameraPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: 32),
          Text(
            'Camera Stream',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE MONITORING',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Coming soon...',
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatisticsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: 32),
          _buildStatisticsHeader(),
          const SizedBox(height: 32),
          _buildStatisticsCards(),
          const SizedBox(height: 24),
          _buildActivityTrendsCard(),
          const SizedBox(height: 24),
          _buildRegionalDistributionCard(),
          const SizedBox(height: 24),
          _buildSecuritySegmentsCard(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildShieldPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: 32),
          Text(
            'Security Center',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SECURITY OVERVIEW',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Coming soon...',
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatisticsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'User Statistics',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4EEF9B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Last 7 Days',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0C100E),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.tertiarySurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Download Report',
            style: GoogleFonts.inter(
              color: const Color(0xFF4EEF9B),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    return Column(
      children: [
        _buildStatCard(
          title: 'TOTAL USERS',
          value: '1,248,302',
          change: '↑12%',
          changeColor: const Color(0xFF4EEF9B),
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          title: 'ACTIVE NOW',
          value: '84,291',
          change: '● LIVE',
          changeColor: const Color(0xFF4EEF9B),
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          title: 'INACTIVE',
          value: '14,802',
          change: '↓4%',
          changeColor: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String change,
    required Color changeColor,
  }) {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                change,
                style: GoogleFonts.inter(
                  color: changeColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTrendsCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Activity Trends',
            style: GoogleFonts.outfit(
              color: const Color(0xFF4EEF9B),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparing real-time active sessions vs inactive accounts',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: context.appBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBarChart('MON', 0.6),
                  _buildBarChart('TUE', 0.4),
                  _buildBarChart('WED', 0.8),
                  _buildBarChart('THU', 0.7),
                  _buildBarChart('FRI', 0.5),
                  _buildBarChart('SAT', 0.3),
                  _buildBarChart('SUN', 0.6),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF4EEF9B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ACTIVE',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(width: 24),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'INACTIVE',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(String day, double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 12,
          height: height * 80,
          decoration: BoxDecoration(
            color: const Color(0xFF4EEF9B),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildRegionalDistributionCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Regional Distribution',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF4EEF9B),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'VIEW MAP',
                style: GoogleFonts.inter(
                  color: const Color(0xFF4EEF9B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildRegionItem('North America', 62),
          const SizedBox(height: 16),
          _buildRegionItem('European Union', 31),
          const SizedBox(height: 16),
          _buildRegionItem('Asia Pacific', 18),
        ],
      ),
    );
  }

  Widget _buildRegionItem(String region, int percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4EEF9B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.public,
                      size: 12, color: Color(0xFF0C100E)),
                ),
                const SizedBox(width: 12),
                Text(
                  region,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '$percentage%',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF4EEF9B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySegmentsCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Security Segments',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF4EEF9B),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.appBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'AI SORTED',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF4EEF9B),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSegmentItem('Enterprise Nodes', 'High Traffic Volume', '824'),
          const SizedBox(height: 16),
          _buildSegmentItem('Guardian Proxies', 'Residential/SOHO', '5,102'),
          const SizedBox(height: 16),
          _buildSegmentItem('Sentinel Guests', 'Public Verification', '12,488'),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(String title, String subtitle, String count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Text(
            count,
            style: GoogleFonts.outfit(
              color: const Color(0xFF4EEF9B),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOverlay() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 380,
      child: Container(
        decoration: BoxDecoration(
          color: context.tertiarySurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Settings Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: context.tertiarySurface,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white10,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settings',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF4EEF9B),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_forward,
                            color: Color(0xFF4EEF9B), size: 20),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () {
                          setState(() => _showSettings = false);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Settings Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.appBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage(
                              'https://i.pravatar.cc/150?img=47',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Elena Vance',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Administrator',
                                style: GoogleFonts.inter(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Manage Account Section
                    _buildSettingGroup(
                      'MANAGE ACCOUNT',
                      [
                        _buildSimpleSettingItem('Change Name', Icons.check_circle_outline),
                        _buildSimpleSettingItem('Change Password', Icons.check_circle_outline),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // App Settings Section
                    Text(
                      'APP SETTINGS',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDarkModeToggle(),
                    const SizedBox(height: 200),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleSettingItem(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4EEF9B), size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
        ],
      ),
    );
  }

  Widget _buildDarkModeToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.dark_mode, color: const Color(0xFF4EEF9B), size: 20),
              const SizedBox(width: 12),
              Text(
                'Dark Mode',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Switch(
            value: true,
            onChanged: (val) {},
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF4EEF9B),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingGroup(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          items.length,
          (index) => Column(
            children: [
              items[index],
              if (index < items.length - 1) const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(
            'https://i.pravatar.cc/150?img=47',
          ), // Placeholder for Elena
        ),
        const SizedBox(width: 12),
        Text(
          'Elena Vance',
          style: GoogleFonts.outfit(
            color: const Color(0xFF00E676),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.notifications, color: Color(0xFF00E676)),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Color(0xFF00E676)),
          onPressed: () {
            setState(() => _showSettings = true);
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin Panel',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF00E676),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SHSMA ECOSYSTEM ONLINE',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: context.mutedText.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            color: const Color(0xFF4EEF9B),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildManageUsersCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Manage Users',
            trailing: Row(
              children: [
                const Icon(Icons.person_add, color: Colors.white54, size: 16),
                const SizedBox(width: 4),
                Text(
                  'ADD MEMBER',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildUserRow(
            name: 'Elena Vance',
            role: 'Administrator',
            status: 'ACTIVE',
            avatarUrl: 'https://i.pravatar.cc/150?img=47',
            statusColor: const Color(0xFF00E676),
          ),
          const SizedBox(height: 16),
          _buildUserRow(
            name: 'Marcus Chen',
            role: 'Family Member',
            status: 'LIMITED',
            avatarUrl: 'https://i.pravatar.cc/150?img=11',
            statusColor: Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow({
    required String name,
    required String role,
    required String status,
    required String avatarUrl,
    required Color statusColor,
  }) {
    final borderColor = context.isDarkMode ? Colors.white10 : const Color(0xFFE3E8EF);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  role,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: context.tertiarySurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiDetectionCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('AI Detection'),
          const SizedBox(height: 24),
          _buildSwitchRow(
            title: 'Human Detection',
            subtitle: 'Neural motion filtering',
            value: _humanDetection,
            onChanged: (val) => setState(() => _humanDetection = val),
          ),
          const SizedBox(height: 20),
          _buildSwitchRow(
            title: 'Face Recognition',
            subtitle: 'Identify known profiles',
            value: _faceRecognition,
            onChanged: (val) => setState(() => _faceRecognition = val),
          ),
          const SizedBox(height: 20),
          _buildSwitchRow(
            title: 'Pet Filtering',
            subtitle: 'Ignore animal activity',
            value: _petFiltering,
            onChanged: (val) => setState(() => _petFiltering = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF00E676),
          activeTrackColor: const Color(0xFF00E676).withValues(alpha: 0.3),
          inactiveThumbColor: Colors.grey,
          inactiveTrackColor: Colors.white10,
        ),
      ],
    );
  }

  Widget _buildManageDevicesCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Manage Devices',
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.tertiarySurface,
                shape: BoxShape.circle,
                border: Border.all(color: context.mutedText.withValues(alpha: 0.10)),
              ),
              child: const Icon(Icons.sync, color: Color(0xFF4EEF9B), size: 18),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '12 ACTIVE NODES',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildDeviceItem(
                icon: Icons.videocam,
                name: 'Front Cam',
                status: 'ONLINE',
                statusColor: const Color(0xFF00E676),
                isOnline: true,
              ),
              _buildDeviceItem(
                icon: Icons.cell_tower,
                name: 'Main Entry',
                status: 'SECURED',
                statusColor: const Color(0xFF00E676),
                isOnline: true,
              ),
              _buildDeviceItem(
                icon: Icons.battery_alert,
                name: 'Garage Sen',
                status: 'LOW BATT',
                statusColor: Colors.redAccent,
                isOnline: false, // Or just red color indicator
              ),
              _buildDeviceItem(
                icon: Icons.lock_open,
                name: 'Smart Lock',
                status: 'OPEN',
                statusColor: Colors.white54,
                isOnline: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem({
    required IconData icon,
    required String name,
    required String status,
    required Color statusColor,
    required bool isOnline,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF00E676), size: 28),
          const Spacer(),
          Text(
            name,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (isOnline)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                status,
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemLogsCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'System Logs',
            trailing: Text(
              'EXPORT',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildLogItem(
            '14:02',
            'INFO',
            '[Human Detected] Front Door Cam',
            const Color(0xFF00E676),
          ),
          const SizedBox(height: 12),
          _buildLogItem(
            '13:45',
            'INFO',
            '[Lock Engaged] Main Entry',
            const Color(0xFF00E676),
          ),
          const SizedBox(height: 12),
          _buildLogItem(
            '13:12',
            'WARN',
            '[Low Battery] Garage Sensor',
            Colors.orangeAccent,
          ),
          const SizedBox(height: 12),
          _buildLogItem(
            '12:58',
            'INFO',
            '[Auth] Elena Vance logged in',
            const Color(0xFF00E676),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: context.tertiarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                'VIEW FULL HISTORY',
                style: GoogleFonts.inter(
                  color: const Color(0xFF4EEF9B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(
    String time,
    String level,
    String message,
    Color levelColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: levelColor.withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white30,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            level,
            style: GoogleFonts.jetBrainsMono(
              color: levelColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.space_dashboard_rounded,
              color: _currentPage == 0
                  ? const Color(0xFF4EEF9B)
                  : Colors.white54,
            ),
            onPressed: () => setState(() => _currentPage = 0),
          ),
          IconButton(
            icon: Icon(
              Icons.videocam_rounded,
              color: _currentPage == 1
                  ? const Color(0xFF4EEF9B)
                  : Colors.white54,
            ),
            onPressed: () => setState(() => _currentPage = 1),
          ),
          IconButton(
            icon: Icon(
              Icons.insert_chart_rounded,
              color: _currentPage == 2
                  ? const Color(0xFF4EEF9B)
                  : Colors.white54,
            ),
            onPressed: () => setState(() => _currentPage = 2),
          ),
          GestureDetector(
            onTap: () => setState(() => _currentPage = 3),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _currentPage == 3
                    ? const Color(0xFF4EEF9B)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: _currentPage == 3
                    ? null
                    : Border.all(
                        color: Colors.white54,
                        width: 2,
                      ),
              ),
              child: Icon(
                Icons.shield,
                color: _currentPage == 3
                    ? const Color(0xFF0C100E)
                    : Colors.white54,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
