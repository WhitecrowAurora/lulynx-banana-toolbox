import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/haptic_service.dart';

class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({
    super.key,
    required this.imageBytes,
    this.heroTag,
    this.onShare,
    this.onSave,
    this.shareLabel = '分享',
    this.saveLabel = '保存',
    this.closeLabel = '关闭',
  });

  final Uint8List imageBytes;
  final String? heroTag;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final String shareLabel;
  final String saveLabel;
  final String closeLabel;

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _uiAnimation;

  bool _showUI = true;
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _previousOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _uiAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
    super.dispose();
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
    HapticService.light();
  }

  void _resetZoom() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
    HapticService.light();
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = GestureDetector(
      onTap: _toggleUI,
      onDoubleTap: () {
        if (_scale > 1.0) {
          _resetZoom();
        } else {
          setState(() {
            _scale = 2.0;
          });
        }
        HapticService.medium();
      },
      onScaleStart: (details) {
        _previousScale = _scale;
        _previousOffset = _offset;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_previousScale * details.scale).clamp(1.0, 5.0);
          if (_scale > 1.0) {
            _offset = _previousOffset + details.focalPointDelta / _scale;
          } else {
            _offset = Offset.zero;
          }
        });
      },
      onScaleEnd: (details) {
        if (_scale < 1.1) {
          _resetZoom();
        }
      },
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        panEnabled: _scale > 1.0,
        boundaryMargin: const EdgeInsets.all(20),
        child: Image.memory(
          widget.imageBytes,
          fit: BoxFit.contain,
        ),
      ),
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Center(child: imageWidget),
            ),
          ),

          AnimatedBuilder(
            animation: _uiAnimation,
            builder: (context, child) {
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showUI ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_showUI,
                  child: child,
                ),
              );
            },
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        onPressed: () {
                          HapticService.light();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.close),
                        color: Colors.white,
                      ),
                      actions: [
                        if (widget.onShare != null)
                          IconButton(
                            onPressed: () {
                              HapticService.medium();
                              widget.onShare!();
                            },
                            icon: const Icon(Icons.share),
                            color: Colors.white,
                            tooltip: widget.shareLabel,
                          ),
                        if (widget.onSave != null)
                          IconButton(
                            onPressed: () {
                              HapticService.medium();
                              widget.onSave!();
                            },
                            icon: const Icon(Icons.download),
                            color: Colors.white,
                            tooltip: widget.saveLabel,
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (widget.onShare != null)
                            _ActionButton(
                              icon: Icons.share,
                              label: widget.shareLabel,
                              onPressed: widget.onShare!,
                            ),
                          if (widget.onSave != null)
                            _ActionButton(
                              icon: Icons.download,
                              label: widget.saveLabel,
                              onPressed: widget.onSave!,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
