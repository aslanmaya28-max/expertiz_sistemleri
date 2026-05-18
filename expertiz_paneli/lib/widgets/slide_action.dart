// Custom SlideAction Widget for Safety Seal
// Alternative to flutter_slide_action package
// Provides slide-to-confirm functionality with full control

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SlideAction extends StatefulWidget {
  final String text;
  final TextStyle? textStyle;
  final Color outerColor;
  final Color innerColor;
  final double height;
  final Icon? sliderButtonIcon;
  final Future<void> Function() onSubmit;
  final bool submitted;
  final bool disabled;

  const SlideAction({
    super.key,
    required this.text,
    this.textStyle,
    required this.outerColor,
    required this.innerColor,
    this.height = 60,
    this.sliderButtonIcon,
    required this.onSubmit,
    this.submitted = false,
    this.disabled = false,
  });

  @override
  State<SlideAction> createState() => _SlideActionState();
}

class _SlideActionState extends State<SlideAction> with SingleTickerProviderStateMixin {
  double _dragPosition = 0;
  bool _isDragging = false;
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || widget.disabled) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit();
      HapticFeedback.heavyImpact();
      
      if (mounted) {
        setState(() {
          _dragPosition = 0;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _shakeAnimationController();
      }
    }
  }

  void _shakeAnimationController() async {
    await _animationController.forward();
    await _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = widget.height - 12;
    final maxDrag = MediaQuery.of(context).size.width - buttonSize - 40;

    return Semantics(
      label: 'Mühürleme işlemi',
      hint: 'Onaylamak için sağa kaydırın',
      value: _dragPosition > 0 ? 'Kaydırılıyor' : 'Başlangıç',
      increasedValue: 'Onayla',
      decreasedValue: 'Başlangıç',
      enabled: !widget.disabled && !_isSubmitting,
      slider: true,
      onIncrease: _dragPosition < maxDrag * 0.9 ? () => _handleSlideForward(maxDrag) : null,
      onDecrease: _dragPosition > 0 ? () => setState(() => _dragPosition = 0) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onPanUpdate: widget.disabled || _isSubmitting
              ? null
              : (details) {
                  final newPosition = (details.localPosition.dx - 20).clamp(0.0, maxDrag);
                  if (newPosition != _dragPosition) {
                    setState(() => _dragPosition = newPosition);
                  }

                  if (_dragPosition >= maxDrag * 0.9) {
                    _handleSubmit();
                  }
                },
          onPanEnd: widget.disabled || _isSubmitting
              ? null
              : (_) {
                  if (_dragPosition < maxDrag * 0.9) {
                    setState(() => _dragPosition = 0);
                  }
                },
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value * (_isDragging ? 1 : 0), 0),
                child: Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: widget.disabled
                        ? widget.outerColor.withValues(alpha: 0.3)
                        : widget.outerColor,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                    border: Border.all(
                      color: widget.disabled
                          ? Colors.white24
                          : widget.innerColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Center Text (const optimization)
                      Center(
                        child: Opacity(
                          opacity: 1 - (_dragPosition / maxDrag),
                          child: Text(
                            widget.text,
                            style: widget.textStyle ??
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      // Slider Button with RepaintBoundary for GPU isolation
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                        left: _dragPosition,
                        top: 6,
                        child: RepaintBoundary(
                          child: GestureDetector(
                            onPanStart: widget.disabled || _isSubmitting
                                ? null
                                : (_) => setState(() => _isDragging = true),
                            onPanEnd: widget.disabled || _isSubmitting
                                ? null
                                : (_) => setState(() => _isDragging = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: buttonSize,
                              height: buttonSize,
                              decoration: BoxDecoration(
                                color: widget.disabled
                                    ? Colors.white24
                                    : widget.innerColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.innerColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: _isSubmitting
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    )
                                  : widget.sliderButtonIcon ?? const Icon(Icons.chevron_right, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleSlideForward(double maxDrag) {
    final step = maxDrag / 10;
    setState(() => _dragPosition = (_dragPosition + step).clamp(0.0, maxDrag * 0.9));
  }
}
