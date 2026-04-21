import 'package:flutter/material.dart';

import '../screens/subscription/home_pro_upgrade_screen.dart';

Future<void> openHomeProUpgrade(BuildContext context, {String? source}) {
  return HomeProUpgradeScreen.open(context, source: source);
}
