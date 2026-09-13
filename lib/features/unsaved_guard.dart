import 'package:flutter/material.dart';

/// Protects draft routes while allowing successful Save/Apply to leave normally.
class UnsavedGuard extends StatefulWidget {
  final Widget child;
  final bool Function() dirty;
  final bool czech;
  const UnsavedGuard({
    super.key,
    required this.child,
    required this.dirty,
    required this.czech,
  });
  @override
  State<UnsavedGuard> createState() => _UnsavedGuardState();
}

class _UnsavedGuardState extends State<UnsavedGuard> {
  bool leaving = false, prompting = false;
  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: leaving,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || prompting) return;
      if (!widget.dirty()) {
        setState(() => leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.pop(context, result);
        });
        return;
      }
      prompting = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(
            widget.czech
                ? 'Zahodit neuložené změny?'
                : 'Discard unsaved changes?',
          ),
          content: Text(
            widget.czech
                ? 'Zpět se můžeš vrátit do editoru a práci uložit.'
                : 'Return to the editor to save your work.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(widget.czech ? 'Zpět do editoru' : 'Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(widget.czech ? 'Zahodit' : 'Discard'),
            ),
          ],
        ),
      );
      prompting = false;
      if (discard == true && context.mounted) {
        setState(() => leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.pop(context, result);
        });
      }
    },
    child: widget.child,
  );
}
