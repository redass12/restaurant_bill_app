import 'package:flutter/material.dart';

// Réutilise tes couleurs _seed / _accent (ou remplace par tes Color)
const _seed = Color(0xFF8B5E3C);
const _accent = Color(0xFFD86B4A);

class FancyBrandBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> actions;
  final double? height;
  const FancyBrandBar({super.key, this.actions = const [], this.height});

  @override
  Size get preferredSize => Size.fromHeight(height ?? 88);

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 600;
    final h = height ?? (isPhone ? 78.0 : 88.0);

    return Container(
      height: h + MediaQuery.of(context).padding.top,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_seed, _accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Bloc central marque (logo + nom)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // pastille logo
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        height: isPhone ? 34 : 40,  // <<< icône bien grande
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Waldschenke',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: isPhone ? 20 : 24,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions en pastille à droite (PDF, logout…)
            Positioned(
              right: 8,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: actions
                      .map((w) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: w,
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
