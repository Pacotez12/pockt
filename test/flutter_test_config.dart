import 'dart:async';
import 'package:pockt/features/home/ui/month_glow.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugDisableAuroraDrift = true;
  await testMain();
}
