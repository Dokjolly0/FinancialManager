import 'package:flutter/material.dart';

import '../../../../core/formatting/color_hex.dart';
import '../../domain/models/category.dart';

/// The category's initial on its color (the theme's secondary container
/// when it has none), as shown in the picker and the Categories screen.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return CircleAvatar(
      backgroundColor: color == null
          ? Theme.of(context).colorScheme.secondaryContainer
          : colorFromHex(color),
      child: Text(category.name.isEmpty ? '?' : category.name[0].toUpperCase()),
    );
  }
}
