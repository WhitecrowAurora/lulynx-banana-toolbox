import 'package:flutter/material.dart';

class HomeMessagesPane extends StatelessWidget {
  const HomeMessagesPane({
    super.key,
    required this.scrollController,
    required this.messagesCount,
    required this.itemBuilder,
    required this.showJumpToLatest,
    required this.jumpToLatestTooltip,
    required this.onScrollNotification,
    required this.onJumpToLatest,
    this.searchNavigator,
  });

  final ScrollController scrollController;
  final int messagesCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool showJumpToLatest;
  final String jumpToLatestTooltip;
  final NotificationListenerCallback<UserScrollNotification> onScrollNotification;
  final VoidCallback onJumpToLatest;
  final Widget? searchNavigator;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: onScrollNotification,
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: messagesCount,
            itemBuilder: itemBuilder,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            offset: showJumpToLatest ? Offset.zero : const Offset(0, 0.35),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              opacity: showJumpToLatest ? 1 : 0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                scale: showJumpToLatest ? 1 : 0.86,
                child: IgnorePointer(
                  ignoring: !showJumpToLatest,
                  child: FloatingActionButton.small(
                    heroTag: 'jump_latest_fab',
                    onPressed: onJumpToLatest,
                    tooltip: jumpToLatestTooltip,
                    child: const Icon(Icons.arrow_downward),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (searchNavigator != null)
          Positioned(right: 12, bottom: 12, child: searchNavigator!),
      ],
    );
  }
}
