import 'package:flutter/material.dart';

import 'auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {

    final PageController _pageController = PageController();
  int _currentPage = 0;

  void _openSignIn(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  void _openSignUp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(initialSignUp: true),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ------------------------------------------------------------
          // BACKGROUND IMAGE
          // ------------------------------------------------------------
          Positioned.fill(
            child: Image.asset(
              'assets/images/hercircle_landing.png',
              fit: BoxFit.cover,
            ),
          ),

          // Soft overlay to make the text easier to read.
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x22F8D9EA),
                    Color(0x00F8D9EA),
                    Color(0x55F8D9EA),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ------------------------------------------------------
                // TOP BRANDING
                // ------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _openSignIn(context),
                            icon: const Icon(
                              Icons.chevron_right,
                              size: 24,
                            ),
                            label: const Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            iconAlignment: IconAlignment.end,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF4B185F),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      const Icon(
                        Icons.spa_outlined,
                        size: 58,
                        color: Color(0xFF8E3FA8),
                      ),

                      const SizedBox(height: 2),

                      const Text(
                        'HerCircle',
                        style: TextStyle(
                          color: Color(0xFF32104E),
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'S U P P O R T   S H A R E   E M P O W E R',
                        style: TextStyle(
                          color: Color(0xFF94527E),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.8,
                        ),
                      ),

                      const SizedBox(height: 22),

                      const Text(
                        'Women Community\nSupport',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF32104E),
                          fontSize: 30,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'A safe space to share, learn and support\n'
                        'each other — because you’re not alone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF685678),
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ------------------------------------------------------
                // BOTTOM WHITE/PINK PANEL
                // ------------------------------------------------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDF5F9),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(42),
                      topRight: Radius.circular(42),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Feature section
SizedBox(
  height: 127,
  child: PageView(
    controller: _pageController,
    onPageChanged: (page) {
      setState(() {
        _currentPage = page;
      });
    },
    children: const [
      Row(
        children: [
          Expanded(
            child: _FeatureItem(
              icon: Icons.chat_bubble_outline,
              title: 'Share\nAnonymously',
              description:
                  'Express yourself freely while keeping your identity private.',
            ),
          ),
          Expanded(
            child: _FeatureItem(
              icon: Icons.menu_book_outlined,
              title: 'Browse by\nCategory',
              description:
                  'Explore discussions on topics that matter to you.',
            ),
          ),
        ],
      ),

      Row(
        children: [
          Expanded(
            child: _FeatureItem(
              icon: Icons.groups_outlined,
              title: 'Be Part of\na Community',
              description:
                  'Connect with women and join meaningful conversations.',
            ),
          ),
          Expanded(
            child: _FeatureItem(
              icon: Icons.shield_outlined,
              title: 'Stay Safe &\nProtected',
              description:
                  'Report harmful content, moderators keep the community respectful.',
            ),
          ),
        ],
      ),
    ],
  ),
),

                      const SizedBox(height: 24),

                      // Page indicator
                      Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    _Dot(active: _currentPage == 0),
    _Dot(active: _currentPage == 1),
  ],
),

                      const SizedBox(height: 22),

                      // Get Started
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => _openSignUp(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9A4BA8),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward, size: 25),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Existing account
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => _openSignIn(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6E238E),
                            side: const BorderSide(
                              color: Color(0xFFE2B5D8),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'I already have an account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ----------------------------------------------------------------------
// FEATURE ITEM
// ----------------------------------------------------------------------

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: Color(0xFFF9E5F1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Color(0xFF762A83),
            size: 29,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF32104E),
            fontSize: 14,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF806B88),
            fontSize: 10,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}


// ----------------------------------------------------------------------
// PAGE DOT
// ----------------------------------------------------------------------

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 18 : 9,
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF9A4BA8)
            : const Color(0xFFE4C4DF),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}