import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens the focus session for a task.
///
/// [justFive] commits to five minutes and then asks whether to keep going.
/// [panic] marks a start from the overwhelm button.
void openFocus(
  BuildContext context,
  String taskId, {
  required int minutes,
  bool justFive = false,
  bool panic = false,
}) {
  final q = {
    'min': '$minutes',
    if (justFive) 'five': '1',
    if (panic) 'panic': '1',
  };
  context.push(Uri(path: '/focus/$taskId', queryParameters: q).toString());
}
