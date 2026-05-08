import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:farm_fintech/providers/game_state.dart';

class NotificationOverlay extends StatelessWidget {
  const NotificationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, child) {
        if (state.notifications.isEmpty) return const SizedBox.shrink();

        return Positioned(
          top: 40,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: state.notifications.map((item) => _NotificationTile(item: item)).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatefulWidget {
  final NotificationItem item;
  const _NotificationTile({required this.item});

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _offset = Tween<Offset>(begin: const Offset(1.5, 0), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    
    // Slide out after 3.5s (before it's removed at 4s)
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4E4BC), // Parchment
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.item.color, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.item.icon, color: widget.item.color, size: 20),
            const SizedBox(width: 12),
            Text(
              widget.item.message,
              style: GoogleFonts.cinzel(color: const Color(0xFF2D1B10), fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
