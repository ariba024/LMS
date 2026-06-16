import 'package:flutter/material.dart';
import '../theme/typography.dart';

const _avatarColors = [
  Color(0xFFF5BE3F),
  Color(0xFFC2410C),
  Color(0xFF1F8A5B),
  Color(0xFF2563B8),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFF0891B2),
  Color(0xFF65A30D),
];

Color _colorForName(String name) {
  int hash = 0;
  for (final ch in name.codeUnits) {
    hash = (hash * 31 + ch) & 0xFFFFFF;
  }
  return _avatarColors[hash % _avatarColors.length];
}

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

class ArrestoAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? imageUrl;

  const ArrestoAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final bg = _colorForName(name);
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: bg.withOpacity(0.4)),
      ),
      alignment: Alignment.center,
      child: imageUrl != null
          ? ClipOval(
              child: Image.network(imageUrl!,
                  width: size, height: size, fit: BoxFit.cover))
          : Text(
              _initials(name),
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w700,
                color: bg,
              ),
            ),
    );
  }
}
