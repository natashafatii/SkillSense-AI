import 'package:flutter/material.dart';

/// The shared typography used for primary page headings.
TextStyle pageHeadingStyle(BuildContext context) => TextStyle(
  fontFamily: 'Roboto',
  color: Theme.of(context).colorScheme.onSurface,
  fontSize: 28,
  fontWeight: FontWeight.w700,
  height: 1.25,
  letterSpacing: -.65,
);
