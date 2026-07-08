import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';

// Asset paths. Filenames keep Yatri's original spelling ("buttom") to match
// the copied assets exactly; only the code identifier is corrected.
const String _onboardingTopBg = 'assets/images/onboarding_top_bg.png';
const String _onboardingBottomBg = 'assets/images/onboarding_buttom_bg.png';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Bottom background image pinned at bottom, faded into white
          Positioned(
            left: 0,
            right: 0,
            bottom: -50,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.6),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.15, 0.35],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                _onboardingBottomBg,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),

          // Main content
          FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Column(
                children: [
                  Expanded(flex: 5, child: _buildTopSection()),
                  Expanded(flex: 3, child: _buildBottomSection()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Top: hero image + YatraGo branding + tagline
  Widget _buildTopSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.65, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: Image.asset(
              _onboardingTopBg,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),

        // Branding overlay
        Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(
                'YatraGo',
                style: GoogleFonts.poppins(
                  fontSize: 62,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  height: 1.0,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Travel Together',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D2D2D),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Share the Journey',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF777777),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              _buildDecorativeDivider(),
            ],
          ),
        ),
      ],
    );
  }

  // Bottom: tagline copy + single Get Started CTA → login
  Widget _buildBottomSection() {
    return Container(
      alignment: Alignment.topCenter,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          Transform.translate(
            offset: const Offset(0, -20),
            child: Column(
              children: [
                Text(
                  'Intercity rides, shared',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Book a seat or offer one across Nepal.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Get Started — red gradient CTA
          GestureDetector(
            onTap: () => context.go(RouteNames.login),
            child: Container(
              width: double.infinity,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Get Started',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 2.5,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 40,
          height: 2.5,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
