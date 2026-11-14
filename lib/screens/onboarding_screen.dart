import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart' show fadeRoute;

class _PageData {
  final IconData icon;
  final List<Color> colors;
  final String title;
  final String text;
  const _PageData(this.icon, this.colors, this.title, this.text);
}

const _pages = [
  _PageData(
    Icons.account_balance_wallet_rounded,
    [Color(0xFF8B6CFF), Color(0xFF5B3CF0)],
    'Track every taka',
    'Add income and expenses in seconds. Quick Add makes rickshaw, chai and lunch just one tap.',
  ),
  _PageData(
    Icons.track_changes_rounded,
    [Color(0xFF2BD17E), Color(0xFF12945A)],
    'Stay within budget',
    'Set a monthly budget and category limits. Always know how much you can safely spend today.',
  ),
  _PageData(
    Icons.pie_chart_rounded,
    [Color(0xFF4F9BFF), Color(0xFF1D4ED8)],
    'See where it goes',
    'Clear charts, smart insights and PDF reports help you save for what really matters.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  final Widget next;
  const OnboardingScreen({super.key, required this.next});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute(widget.next));
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
    } else {
      _pc.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final last = _page == _pages.length - 1;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF2A1F5C), const Color(0xFF0F0F17)]
                : [const Color(0xFFE6E0FF), const Color(0xFFF6F5FB)],
            stops: const [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: last ? 0 : 1,
                    child: TextButton(
                      onPressed: last ? null : _finish,
                      child: const Text('Skip'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final p = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 170,
                            width: 170,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(52),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: p.colors,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: p.colors.last.withValues(alpha: 0.4),
                                  blurRadius: 36,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: Icon(p.icon, size: 82, color: Colors.white),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            p.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            p.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: scheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: i == _page ? 26 : 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? scheme.primary
                          : scheme.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: FilledButton(
                  onPressed: _next,
                  child: Text(last ? 'Get Started' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
