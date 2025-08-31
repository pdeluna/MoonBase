import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/widgets/base_sidebar.dart';

class SwipableBaseSidebar extends ConsumerStatefulWidget {
  final Widget child;
  final double sidebarWidth;
  final double swipeThreshold;
  final Duration animationDuration;

  const SwipableBaseSidebar({
    super.key,
    required this.child,
    this.sidebarWidth = 280,
    this.swipeThreshold = 50,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  static SwipableBaseSidebarState? of(BuildContext context) {
    return context.findAncestorStateOfType<SwipableBaseSidebarState>();
  }

  @override
  ConsumerState<SwipableBaseSidebar> createState() => SwipableBaseSidebarState();
}

class SwipableBaseSidebarState extends ConsumerState<SwipableBaseSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isSidebarOpen = false;
  bool _isDragging = false;
  double _dragStartX = 0;
  double _currentDragX = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _openSidebar() {
    setState(() => _isSidebarOpen = true);
    _animationController.forward();
  }

  void _closeSidebar() {
    _animationController.reverse().then((_) {
      setState(() => _isSidebarOpen = false);
    });
  }

  void toggleSidebar() {
    if (_isSidebarOpen) {
      _closeSidebar();
    } else {
      _openSidebar();
    }
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStartX = details.globalPosition.dx;
      _currentDragX = details.globalPosition.dx;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      _currentDragX = details.globalPosition.dx;
    });

    // Calculate drag progress
    final dragDistance = _currentDragX - _dragStartX;
    final maxDragDistance = widget.sidebarWidth;
    
    if (_isSidebarOpen) {
      // Dragging to close
      if (dragDistance < 0) {
        final progress = 1.0 + (dragDistance / maxDragDistance);
        _animationController.value = progress.clamp(0.0, 1.0);
      }
    } else {
      // Dragging to open
      if (dragDistance > 0) {
        final progress = dragDistance / maxDragDistance;
        _animationController.value = progress.clamp(0.0, 1.0);
      }
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    setState(() => _isDragging = false);

    final dragDistance = _currentDragX - _dragStartX;
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (_isSidebarOpen) {
      // Sidebar is open, check if we should close it
      if (dragDistance < -widget.swipeThreshold || velocity < -500) {
        _closeSidebar();
      } else {
        _animationController.forward();
      }
    } else {
      // Sidebar is closed, check if we should open it
      if (dragDistance > widget.swipeThreshold || velocity > 500) {
        _openSidebar();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _showCreateBaseDialog() {
    _closeSidebar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create base functionality is available in the sidebar')),
    );
  }

  void _showJoinBaseDialog() {
    _closeSidebar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Join base functionality is available in the sidebar')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content (always stays in place)
        GestureDetector(
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: widget.child,
        ),

        // Overlay when sidebar is open
        if (_isSidebarOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeSidebar,
              child: Container(
                color: Colors.black.withValues(alpha: 0.3 * _animation.value),
              ),
            ),
          ),

        // Sidebar overlay
        if (_isSidebarOpen || _animation.value > 0)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(-widget.sidebarWidth * (1 - _animation.value), 0),
                  child: Container(
                    width: widget.sidebarWidth,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(2, 0),
                        ),
                      ],
                    ),
                    child: BaseSidebar(
                      onBaseSelected: _closeSidebar,
                      onCreateBase: _showCreateBaseDialog,
                      onJoinBase: _showJoinBaseDialog,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// Extension to add sidebar functionality to any widget
extension SwipableSidebarExtension on Widget {
  Widget withSwipableSidebar({
    double sidebarWidth = 280,
    double swipeThreshold = 50,
    Duration animationDuration = const Duration(milliseconds: 300),
  }) {
    return SwipableBaseSidebar(
      sidebarWidth: sidebarWidth,
      swipeThreshold: swipeThreshold,
      animationDuration: animationDuration,
      child: this,
    );
  }
}
