import 'package:flutter/material.dart';

/// Root navigator for overlay-based infrastructure (e.g. offscreen video
/// poster capture during pick). Wired on [GoRouter.navigatorKey] in
/// `router.dart`.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
