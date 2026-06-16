import 'package:flutter/material.dart';
import 'dart:async';

class InlineFeedbackWidget extends StatefulWidget {
  final String? message;
  final Color? color;
  final Duration duration;
  final VoidCallback? onCompleted;

  const InlineFeedbackWidget({
    super.key,
    this.message,
    this.color,
    this.duration = const Duration(seconds: 3),
    this.onCompleted,
  });

  @override
  State<InlineFeedbackWidget> createState() => _InlineFeedbackWidgetState();
}

class _InlineFeedbackWidgetState extends State<InlineFeedbackWidget> {
  String? _displayMessage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _handleMessageChange();
  }

  @override
  void didUpdateWidget(InlineFeedbackWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      _handleMessageChange();
    }
  }

  void _handleMessageChange() {
    _timer?.cancel();
    if (widget.message != null && widget.message!.isNotEmpty) {
      setState(() {
        _displayMessage = widget.message;
      });
      _timer = Timer(widget.duration, () {
        if (mounted) {
          setState(() {
            _displayMessage = null;
          });
          if (widget.onCompleted != null) {
            widget.onCompleted!();
          }
        }
      });
    } else {
      setState(() {
        _displayMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(-0.2, 0.0), // Vem da esquerda
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));

        // Para saída indo para a direita
        final outOffsetAnimation = Tween<Offset>(
          begin: const Offset(0.2, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInCubic,
        ));

        if (child.key == const ValueKey('empty')) {
          return SlideTransition(
            position: outOffsetAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        }

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _displayMessage == null
          ? const SizedBox(key: ValueKey('empty'))
          : Padding(
              key: ValueKey(_displayMessage),
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _displayMessage!,
                style: TextStyle(
                  color: widget.color ?? Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
    );
  }
}
