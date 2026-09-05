import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolioColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: FolioColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FolioColors.border),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  size: 36,
                  color: FolioColors.accent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppConstants.appTitle,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: FolioColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppConstants.tagline,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: FolioColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
