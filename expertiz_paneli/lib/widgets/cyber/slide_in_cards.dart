import 'package:flutter/material.dart';
import '../../core/constants/yerimebak_colors.dart';
import 'info_card.dart';

/// Slide-In Cards Widget for "Neden YerimeBak?" questions
class SlideInCards extends StatefulWidget {
  const SlideInCards({super.key});

  @override
  State<SlideInCards> createState() => _SlideInCardsState();
}

class _SlideInCardsState extends State<SlideInCards>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late List<Animation<Offset>> _slideAnimations;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create staggered animations for each card
    _slideAnimations = List.generate(
      3,
      (index) => Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval(
          index * 0.15,
          0.5 + (index * 0.2),
          curve: Curves.easeOutBack,
        ),
      )),
    );

    // Start animations after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _slideController.forward();
      }
    });

    // Auto-scroll every 5 seconds
    _startAutoScroll();
  }

  void _startAutoScroll() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _currentPage = (_currentPage + 1) % 3;
        });
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        return true;
      }
      return false;
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Title
        const Text(
          'Neden YerimeBak?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        // Cards Container
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: 3,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _slideAnimations[index],
                builder: (context, child) {
                  return SlideTransition(
                    position: _slideAnimations[index],
                    child: child,
                  );
                },
                child: _buildCard(index),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Page Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: _currentPage == index
                    ? const LinearGradient(
                        colors: [
                          YerimeBakColors.cyberNeonTurquoise,
                          YerimeBakColors.cyberNeonPurple,
                        ],
                      )
                    : null,
                color: _currentPage == index
                    ? null
                    : YerimeBakColors.cyberNeonTurquoise
                        .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
                boxShadow: _currentPage == index
                    ? [
                        BoxShadow(
                          color: YerimeBakColors.cyberNeonTurquoise
                              .withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCard(int index) {
    switch (index) {
      case 0:
        return const InfoCard(
          icon: Icons.psychology,
          title: 'Yapay Zeka Destekli',
          description: 'Gelişmiş AI motoru ile araç değerlemesi',
          iconColor: YerimeBakColors.cyberNeonTurquoise,
        );
      case 1:
        return const InfoCard(
          icon: Icons.speed,
          title: 'Anlık Takip',
          description: 'Personel ilerlemesini canlı izle',
          iconColor: YerimeBakColors.cyberNeonPurple,
        );
      case 2:
        return const InfoCard(
          icon: Icons.security,
          title: 'Güvenli & Hızlı',
          description: '256-bit şifreleme ile veri güvenliği',
          iconColor: YerimeBakColors.cyberNeonMagenta,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
