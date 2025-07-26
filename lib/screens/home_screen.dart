import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'register_screen.dart';
import 'nfc_attendance_screen.dart';
import 'students_screen.dart';
import 'attendance_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int currentIndex = 0;

  // Animation Controllers
  AnimationController? _navigationController;
  AnimationController? _glowController;
  AnimationController? _pulseController;

  // Animations
  Animation<double>? _navigationAnimation;
  Animation<double>? _glowAnimation;
  Animation<double>? _pulseAnimation;

  final screens = const [
    RegisterScreen(),
    NFCAttendanceScreen(),
    StudentsScreen(),
    AttendanceHistoryScreen(),
  ];

  final List<NavigationItem> navigationItems = [
    NavigationItem(
      icon: Icons.person_add_outlined,
      activeIcon: Icons.person_add,
      label: 'REGISTER',
      techLabel: 'REG_MODULE',
      color: Color(0xFF00BFA6),
    ),
    NavigationItem(
      icon: Icons.nfc_outlined,
      activeIcon: Icons.nfc,
      label: 'SCAN',
      techLabel: 'NFC_SCANNER',
      color: Color(0xFF00E5FF),
    ),
    NavigationItem(
      icon: Icons.group_outlined,
      activeIcon: Icons.group,
      label: 'STUDENTS',
      techLabel: 'ENTITIES_DB',
      color: Color(0xFF1DE9B6),
    ),
    NavigationItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      label: 'HISTORY',
      techLabel: 'LOG_ACCESS',
      color: Color(0xFFFF6E40),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Navigation transition animation
    _navigationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _navigationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _navigationController!, curve: Curves.elasticOut),
    );

    // Glow animation for active tab
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
    );

    // Pulse animation for active icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    _navigationController!.forward();
  }

  @override
  void dispose() {
    _navigationController?.dispose();
    _glowController?.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index != currentIndex) {
      HapticFeedback.mediumImpact();

      setState(() {
        currentIndex = index;
      });

      // Reset and restart navigation animation
      _navigationController?.reset();
      _navigationController?.forward();
    }
  }

  Widget _buildNavigationItem(NavigationItem item, int index) {
    final isActive = currentIndex == index;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _glowAnimation ?? const AlwaysStoppedAnimation(0.5),
        _pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
      ]),
      builder: (context, _) {
        return GestureDetector(
          onTap: () => _onTabTapped(index),
          child: Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Container
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient:
                        isActive
                            ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                item.color.withOpacity(0.3),
                                item.color.withOpacity(0.1),
                              ],
                            )
                            : null,
                    border: Border.all(
                      color:
                          isActive
                              ? item.color.withOpacity(
                                0.5 + 0.3 * (_glowAnimation?.value ?? 0.5),
                              )
                              : Colors.transparent,
                      width: isActive ? 2 : 0,
                    ),
                    boxShadow:
                        isActive
                            ? [
                              BoxShadow(
                                color: item.color.withOpacity(
                                  0.3 * (_glowAnimation?.value ?? 0.5),
                                ),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ]
                            : null,
                  ),
                  child: Center(
                    child: Transform.scale(
                      scale: isActive ? (_pulseAnimation?.value ?? 1.0) : 1.0,
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors:
                                isActive
                                    ? [item.color, item.color.withOpacity(0.7)]
                                    : [
                                      Colors.grey,
                                      Colors.grey.withOpacity(0.7),
                                    ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds);
                        },
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 1),

                // Label
                Text(
                  item.label,
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? item.color : Colors.grey,
                  ),
                ),

                // Tech Label (only for active item)
                if (isActive) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.techLabel,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 8,
                      fontWeight: FontWeight.w400,
                      color: item.color.withOpacity(0.7),
                    ),
                  ),
                ],

                // Active Indicator
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isActive ? 20 : 0,
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    gradient:
                        isActive
                            ? LinearGradient(
                              colors: [
                                item.color.withOpacity(0.8),
                                item.color,
                                item.color.withOpacity(0.8),
                              ],
                            )
                            : null,
                    boxShadow:
                        isActive
                            ? [
                              BoxShadow(
                                color: item.color.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ]
                            : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    return AnimatedBuilder(
      animation: _navigationAnimation ?? const AlwaysStoppedAnimation(1.0),
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, 100 * (1 - (_navigationAnimation?.value ?? 1.0))),
          child: Container(
            height: 60,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A2A3E), Color(0xFF1E1E2C)],
              ),
              border: Border.all(
                color: const Color(0xFF00BFA6).withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: const Color(0xFF00BFA6).withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withOpacity(0.1), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children:
                      navigationItems
                          .asMap()
                          .entries
                          .map(
                            (entry) =>
                                _buildNavigationItem(entry.value, entry.key),
                          )
                          .toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScreenTransition() {
    return AnimatedBuilder(
      animation: _navigationAnimation ?? const AlwaysStoppedAnimation(1.0),
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Container(
            key: ValueKey(currentIndex),
            child: screens[currentIndex],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A0F), Color(0xFF1E1E2C), Color(0xFF2A2A3E)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: _buildScreenTransition(),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String techLabel;
  final Color color;

  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.techLabel,
    required this.color,
  });
}
