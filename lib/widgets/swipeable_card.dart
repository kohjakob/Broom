import 'package:flutter/material.dart';

class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipedAway;
  final bool enabled;
  final ValueChanged<double>? onDragProgress;

  const SwipeableCard({
    super.key,
    required this.child,
    required this.onSwipedAway,
    this.enabled = true,
    this.onDragProgress,
  });

  @override
  State<SwipeableCard> createState() => SwipeableCardState();
}

class SwipeableCardState extends State<SwipeableCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<Offset>? _animation;
  Offset _offset = Offset.zero;
  bool _isDragging = false;
  bool _isFlying = false;

  static const double _swipeThreshold = 100.0;
  static const double _velocityThreshold = 800.0;
  static const double _maxRotation = 0.3; // radians

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _clearAnimation();
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationUpdate() {
    setState(() => _offset = _animation!.value);
    _reportProgress();
  }

  void _clearAnimation() {
    _animation?.removeListener(_onAnimationUpdate);
    _animation = null;
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.enabled || _isFlying) return;
    _controller.stop();
    _isDragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isFlying) return;
    setState(() {
      _offset += details.delta;
    });
    _reportProgress();
  }

  void _reportProgress() {
    if (widget.onDragProgress == null) return;
    final progress = (_offset.distance / _swipeThreshold).clamp(0.0, 1.0);
    widget.onDragProgress!(progress);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging || _isFlying) return;
    _isDragging = false;

    final velocity = details.velocity.pixelsPerSecond;
    final distance = _offset.distance;
    final speed = velocity.distance;

    if (distance > _swipeThreshold || speed > _velocityThreshold) {
      _flyAway(velocity);
    } else {
      _snapBack();
    }
  }

  void _flyAway(Offset velocity) {
    _isFlying = true;

    // Determine fly direction from current offset + velocity
    Offset direction;
    if (velocity.distance > _velocityThreshold) {
      direction = Offset(velocity.dx, velocity.dy);
    } else {
      direction = _offset;
    }

    // Normalize and scale to fly off screen
    final normalized = direction / direction.distance;
    final target = normalized * 800;

    _clearAnimation();
    _animation = Tween<Offset>(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _animation!.addListener(_onAnimationUpdate);

    _controller.duration = const Duration(milliseconds: 300);
    _controller.forward(from: 0).then((_) {
      widget.onSwipedAway();
    });
  }

  void _snapBack() {
    _clearAnimation();
    _animation = Tween<Offset>(
      begin: _offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _animation!.addListener(_onAnimationUpdate);

    _controller.duration = const Duration(milliseconds: 600);
    _controller.forward(from: 0);
  }

  /// Reset position for new card
  void reset() {
    _clearAnimation();
    _controller.stop();
    setState(() {
      _offset = Offset.zero;
      _isDragging = false;
      _isFlying = false;
    });
  }

  double get _rotation {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth == 0) return 0;
    return (_offset.dx / screenWidth) * _maxRotation;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _offset,
        child: Transform.rotate(
          angle: _rotation,
          child: widget.child,
        ),
      ),
    );
  }
}
