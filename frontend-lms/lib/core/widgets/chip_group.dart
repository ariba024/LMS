import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class ArrestoChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const ArrestoChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? ArrestoColors.ink : ArrestoColors.bg2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? ArrestoColors.ink : ArrestoColors.lineStrong,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : ArrestoColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class ChipGroup extends StatefulWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  const ChipGroup({
    super.key,
    required this.options,
    this.selected,
    required this.onChanged,
  });

  @override
  State<ChipGroup> createState() => _ChipGroupState();
}

class _ChipGroupState extends State<ChipGroup> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected ?? widget.options.first;
  }

  @override
  void didUpdateWidget(ChipGroup old) {
    super.didUpdateWidget(old);
    if (widget.selected != null && widget.selected != _selected) {
      _selected = widget.selected!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.options.map((o) {
        return ArrestoChip(
          label: o,
          active: o == _selected,
          onTap: () {
            setState(() => _selected = o);
            widget.onChanged(o);
          },
        );
      }).toList(),
    );
  }
}
