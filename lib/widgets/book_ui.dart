import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BookUI extends StatefulWidget {
  final String title;
  final List<Widget> pages;
  final VoidCallback? onClose;

  const BookUI({
    super.key,
    required this.title,
    required this.pages,
    this.onClose,
  });

  @override
  State<BookUI> createState() => _BookUIState();
}

class _BookUIState extends State<BookUI> {
  int _leftPageIndex = 0;

  void _nextPage() {
    if (_leftPageIndex + 2 < widget.pages.length) {
      setState(() => _leftPageIndex += 2);
    }
  }

  void _previousPage() {
    if (_leftPageIndex - 2 >= 0) {
      setState(() => _leftPageIndex -= 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10); // Darker brown for readability
    return Material(
      color: Colors.black.withOpacity(0.8), // Darker dimming for overlay feel
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: const Color(0xFFF4E4BC), // Parchment color
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
            border: Border.all(
              color: const Color(0xFF5D4037),
              width: 10,
            ),
          ),
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF5D4037), width: 3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.cinzel(
                        fontSize: 32, // Larger
                        fontWeight: FontWeight.w900, // Extra Bold
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: textColor, size: 32),
                      onPressed: widget.onClose ?? () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ── Pages ───────────────────────────────────────────
              Expanded(
                child: Row(
                  children: [
                    // Left Page
                    Expanded(
                      child: _BookPage(
                        content: _leftPageIndex < widget.pages.length
                            ? widget.pages[_leftPageIndex]
                            : const SizedBox(),
                        pageNumber: _leftPageIndex + 1,
                        textColor: textColor,
                      ),
                    ),

                    // Spine
                    Container(
                      width: 6,
                      color: const Color(0xFF5D4037).withOpacity(0.4),
                    ),

                    // Right Page
                    Expanded(
                      child: _BookPage(
                        content: _leftPageIndex + 1 < widget.pages.length
                            ? widget.pages[_leftPageIndex + 1]
                            : const SizedBox(),
                        pageNumber: _leftPageIndex + 2,
                        textColor: textColor,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Footer / Navigation ─────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF5D4037), width: 3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_leftPageIndex > 0)
                      _BookNavButton(
                        label: 'Return',
                        icon: Icons.auto_stories,
                        onPressed: _previousPage,
                        textColor: textColor,
                      )
                    else
                      const SizedBox(width: 140),
                    
                    Text(
                      'Page ${_leftPageIndex + 1}-${_leftPageIndex + 2}',
                      style: GoogleFonts.almendra(
                        fontSize: 20, // Larger
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),

                    if (_leftPageIndex + 2 < widget.pages.length)
                      _BookNavButton(
                        label: 'Flip',
                        icon: Icons.auto_stories,
                        onPressed: _nextPage,
                        iconRight: true,
                        textColor: textColor,
                      )
                    else
                      const SizedBox(width: 140),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookPage extends StatelessWidget {
  final Widget content;
  final int pageNumber;
  final Color textColor;

  const _BookPage({
    required this.content,
    required this.pageNumber,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          content,
          Positioned(
            bottom: 0,
            right: 0,
            child: Text(
              '$pageNumber',
              style: GoogleFonts.almendra(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool iconRight;
  final Color textColor;

  const _BookNavButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.textColor,
    this.iconRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: textColor, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: textColor.withOpacity(0.05),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!iconRight) Icon(icon, size: 20, color: textColor),
            if (!iconRight) const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.cinzel(
                fontSize: 18, // Larger
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            if (iconRight) const SizedBox(width: 10),
            if (iconRight) Icon(icon, size: 20, color: textColor),
          ],
        ),
      ),
    );
  }
}
