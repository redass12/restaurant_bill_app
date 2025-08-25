import 'package:flutter/material.dart';

// Ton thème
const _seed = Color(0xFF8B5E3C);
const _accent = Color(0xFFD86B4A);

class FancyBrandBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> actions;
  final double? height;
  // optionnel: permets de forcer une taille
  final double? logoSize;
  const FancyBrandBar({
    super.key,
    this.actions = const [],
    this.height,
    this.logoSize,
  });

  @override
  Size get preferredSize => Size.fromHeight(height ?? 88);

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 600;
    final h = height ?? (isPhone ? 82.0 : 92.0);

    // 👇 logo plus grand
    final double _logoSize = logoSize ?? (isPhone ? 44 : 58);

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // -------- LEFT: ONLY the logo (bigger)
              Tooltip(message: 'Waldschenke'),
              Container(
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
                // on réduit la padding pour laisser plus de place à l'image
                child: Container(
                  padding: EdgeInsets.all(isPhone ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: _logoSize,
                    height: _logoSize,
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // -------- RIGHT: Actions (PDF, logout…)
              if (actions.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions
                        .map((w) =>
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: w))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
