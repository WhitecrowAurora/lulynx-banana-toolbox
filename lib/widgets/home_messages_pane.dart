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
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surfaceContainerHighest.withOpacity(0.3),
                colorScheme.surface,
              ],
            ),
          ),
          child: NotificationListener<UserScrollNotification>(
            onNotification: onScrollNotification,
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: messagesCount,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: itemBuilder(context, index),
                );
              },
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            offset: showJumpToLatest ? Offset.zero : const Offset(0, 0.4),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              opacity: showJumpToLatest ? 1 : 0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                scale: showJumpToLatest ? 1 : 0.8,
                child: IgnorePointer(
                  ignoring: !showJumpToLatest,
                  child: Material(
                    elevation: 6,
                    shadowColor: colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    child: FloatingActionButton.small(
                      heroTag: 'jump_latest_fab',
                      elevation: 0,
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      onPressed: onJumpToLatest,
                      tooltip: jumpToLatestTooltip,
                      child: const Icon(Icons.arrow_downward),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (searchNavigator != null)
          Positioned(right: 20, bottom: 20, child: searchNavigator!),
      ],
    );
  }
}
