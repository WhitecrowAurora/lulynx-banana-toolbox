import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_i18n.dart';
import '../models/api_config.dart';
import '../models/chat_models.dart';
import '../models/generation_queue_task.dart';
import '../providers/providers.dart';
import '../widgets/queue_panel.dart';
import '../widgets/chat_message_card.dart';
import '../widgets/home_balance_card.dart';
import '../widgets/home_composer_panel.dart';
import '../widgets/home_generating_hint.dart';
import '../widgets/home_message_image.dart';
import '../widgets/home_messages_pane.dart';
import '../widgets/home_session_drawer.dart';
import '../widgets/reference_images_panel.dart';
import 'gallery_picker_screen.dart';
import 'history_generations_screen.dart';
import 'settings_screen.dart';

Uint8List _preprocessReferenceBytesInIsolate(Map<String, Object> payload) {
  final rawBytes = payload['bytes'];
  if (rawBytes is! Uint8List || rawBytes.isEmpty) {
    return Uint8List(0);
  }
  final original = rawBytes;
  final maxDimension = (payload['maxDimension'] as int?) ?? 0;
  final format =
      (payload['format'] as String?) ?? ApiConfig.referenceFormatKeep;
  final quality = ((payload['quality'] as int?) ?? 90).clamp(40, 100);

  final decoded = img.decodeImage(original);
  if (decoded == null) {
    return Uint8List(0);
  }

  var working = decoded;
  var resized = false;
  if (maxDimension > 0 &&
      (working.width > maxDimension || working.height > maxDimension)) {
    resized = true;
    if (working.width >= working.height) {
      working = img.copyResize(working, width: maxDimension);
    } else {
      working = img.copyResize(working, height: maxDimension);
    }
  }

  if (!resized && format == ApiConfig.referenceFormatKeep) {
    return original;
  }

  switch (format) {
    case ApiConfig.referenceFormatPng:
      return Uint8List.fromList(img.encodePng(working));
    case ApiConfig.referenceFormatWebp:
      return Uint8List.fromList(img.encodeJpg(working, quality: quality));
    case ApiConfig.referenceFormatKeep:
      final mime = _sniffImageMimeTypeBytesForPick(original);
      if (mime == 'image/png') {
        return Uint8List.fromList(img.encodePng(working));
      }
      return Uint8List.fromList(img.encodeJpg(working, quality: quality));
    case ApiConfig.referenceFormatJpeg:
    default:
      return Uint8List.fromList(img.encodeJpg(working, quality: quality));
  }
}

Uint8List _shrinkOversizeReferenceInIsolate(Map<String, Object> payload) {
  final rawBytes = payload['bytes'];
  if (rawBytes is! Uint8List || rawBytes.isEmpty) {
    return Uint8List(0);
  }
  final input = rawBytes;
  final maxSingleBytes =
      (payload['maxSingleBytes'] as int?) ?? 20 * 1024 * 1024;
  if (input.length <= maxSingleBytes) return input;

  final decoded = img.decodeImage(input);
  if (decoded == null) {
    return input;
  }

  var working = decoded;
  var quality = 88;
  Uint8List best = input;
  for (var i = 0; i < 7; i++) {
    final encoded = Uint8List.fromList(
      img.encodeJpg(working, quality: quality.clamp(45, 95)),
    );
    if (encoded.length < best.length) {
      best = encoded;
    }
    if (encoded.length <= maxSingleBytes) {
      return encoded;
    }

    final canShrinkSize = working.width > 1024 || working.height > 1024;
    if (canShrinkSize) {
      final nextWidth =
          (working.width * 0.82).round().clamp(512, working.width);
      final nextHeight =
          (working.height * 0.82).round().clamp(512, working.height);
      working = img.copyResize(
        working,
        width: nextWidth,
        height: nextHeight,
        interpolation: img.Interpolation.average,
      );
    }
    quality = (quality - 8).clamp(45, 95);
  }
  return best;
}

String _sniffImageMimeTypeBytesForPick(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _promptController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _messageItemKeys = <int, GlobalKey>{};
  static const MethodChannel _mediaScannerChannel =
      MethodChannel('com.nanobanana/media_scanner');
  static const MethodChannel _imageChooserChannel =
      MethodChannel('com.nanobanana/image_chooser');

  int? _lastSessionId;
  bool _sessionRestoreDone = false;
  bool _homeBalanceAutoLoaded = false;
  bool _queuePanelExpanded = false;
  bool _queuePanelPeeking = false;
  bool _followLatest = true;
  bool _showJumpToLatest = false;
  int? _draggingReferenceIndex;
  int _lastRenderedMessageCount = 0;
  int? _lastRenderedSessionId;
  Timer? _queuePeekTimer;
  Timer? _draftSaveTimer;
  Timer? _scrollSettleTimer;
  Timer? _scrollLateSettleTimer;
  Timer? _searchDebounceTimer;
  Timer? _highlightPulseTimer;
  double? _lastScrollPixels;
  bool _isRestoringDraft = false;
  bool _draftRestored = false;
  bool _isSearchMode = false;
  bool _isSearchBusy = false;
  bool _highlightPulseOn = false;
  bool _suppressAutoJumpOnce = false;
  String _searchQuery = '';
  List<MessageSearchHit> _searchHits = const [];
  int _activeSearchHitIndex = 0;
  int? _pendingScrollMessageId;
  int? _highlightedMessageId;

  static const String _composerDraftDirName = 'composer_draft';
  static const String _composerDraftManifestName = 'draft_v1.json';
  static const String _composerDraftRefsDirName = 'refs';

  String _tr(String zh, {Map<String, Object?> args = const {}}) =>
      context.tr(zh, args: args);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _promptController.addListener(_onPromptChanged);
    _scrollController.addListener(_handleListScroll);
    _restoreLastSession();
    unawaited(_restoreComposerDraftIfNeeded());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleJumpToLatest(force: true);
    });
  }

  @override
  void dispose() {
    _queuePeekTimer?.cancel();
    _draftSaveTimer?.cancel();
    _scrollSettleTimer?.cancel();
    _scrollLateSettleTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _highlightPulseTimer?.cancel();
    _promptController.removeListener(_onPromptChanged);
    _scrollController.removeListener(_handleListScroll);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_persistComposerDraftNow());
    _promptController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleJumpToLatest(force: true);
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistComposerDraftNow());
    }
  }

  Future<void> _restoreLastSession() async {
    final storage = ref.read(storageServiceProvider);
    final savedSessionId = await storage.loadLastSessionId();
    if (!mounted) return;
    setState(() {
      _lastSessionId = savedSessionId;
      _sessionRestoreDone = true;
    });
    if (savedSessionId != null) {
      ref.read(currentSessionIdProvider.notifier).state = savedSessionId;
    }
  }

  Future<void> _setCurrentSession(int? sessionId) async {
    ref.read(currentSessionIdProvider.notifier).state = sessionId;
    _lastSessionId = sessionId;
    await ref.read(storageServiceProvider).saveLastSessionId(sessionId);
  }

  String _sessionTitleById(int? sessionId) {
    final session = ref.read(sessionsProvider).cast<ChatSession?>().firstWhere(
      (item) => item?.id == sessionId,
      orElse: () => null,
    );
    final title = session?.title.trim() ?? '';
    if (title.isEmpty) {
      return _tr('新对话');
    }
    return title;
  }

  void _showSessionSwitchedNotice(int? sessionId) {
    if (!mounted || sessionId == null) return;
    _showConfiguredSnackBar(
      _tr('已切换到对话 {title}', args: {'title': _sessionTitleById(sessionId)}),
    );
  }

  Future<void> _jumpToMessageInSession({
    required int sessionId,
    required int messageId,
    String? promptToFill,
    bool showSwitchNotice = false,
  }) async {
    final changedSession = ref.read(currentSessionIdProvider) != sessionId;
    _suppressAutoJumpOnce = true;
    await _setCurrentSession(sessionId);
    ref.read(messagesProvider.notifier).refresh();
    if (promptToFill != null) {
      _promptController.text = promptToFill;
      _promptController.selection = TextSelection.collapsed(
        offset: _promptController.text.length,
      );
      _schedulePersistComposerDraft();
    }
    if (!mounted) return;
    setState(() {
      _followLatest = false;
      _showJumpToLatest = true;
      _pendingScrollMessageId = messageId;
      _highlightedMessageId = messageId;
      _highlightPulseOn = true;
    });
    _scheduleEnsureVisibleForPendingTarget();
    if (showSwitchNotice && changedSession) {
      _showSessionSwitchedNotice(sessionId);
    }
  }

  Future<void> _openHistoryGenerations() async {
    final action = await Navigator.push<HistoryGenerationAction>(
      context,
      MaterialPageRoute(
        builder: (_) => const HistoryGenerationsScreen(),
      ),
    );
    if (!mounted || action == null) return;

    switch (action.type) {
      case HistoryGenerationActionType.openOriginal:
        await _jumpToMessageInSession(
          sessionId: action.item.sessionId,
          messageId: action.item.messageId,
          promptToFill: action.item.prompt,
          showSwitchNotice: true,
        );
        return;
      case HistoryGenerationActionType.generateAgain:
        await _generateAgainFromHistory(action.item);
        return;
    }
  }

  Future<void> _generateAgainFromHistory(HistoryGenerationItem item) async {
    final changedSession = ref.read(currentSessionIdProvider) != item.sessionId;
    await _setCurrentSession(item.sessionId);
    _followLatest = true;
    _showJumpToLatest = false;
    _clearReferenceImages();
    ref.read(generationProvider.notifier).clearResult();
    _promptController.text = item.prompt;
    _promptController.selection = TextSelection.collapsed(
      offset: _promptController.text.length,
    );
    _schedulePersistComposerDraft();
    _scheduleJumpToLatest(force: true);
    if (changedSession) {
      _showSessionSwitchedNotice(item.sessionId);
    }
    await _generate();
  }

  String _resolveCurrentSessionTitle(
    List<ChatSession> sessions,
    int? currentSessionId,
  ) {
    final session = sessions.cast<ChatSession?>().firstWhere(
      (item) => item?.id == currentSessionId,
      orElse: () => null,
    );
    final title = session?.title.trim() ?? '';
    if (title.isEmpty) {
      return "Lulynx's Banana Toolbox";
    }
    return title;
  }

  GlobalKey _messageItemKey(int? messageId) {
    if (messageId == null) return GlobalKey();
    return _messageItemKeys.putIfAbsent(messageId, GlobalKey.new);
  }

  void _openSearch() {
    setState(() {
      _isSearchMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _closeSearch() {
    _searchDebounceTimer?.cancel();
    _highlightPulseTimer?.cancel();
    setState(() {
      _isSearchMode = false;
      _isSearchBusy = false;
      _searchQuery = '';
      _searchHits = const [];
      _activeSearchHitIndex = 0;
      _pendingScrollMessageId = null;
      _highlightedMessageId = null;
      _highlightPulseOn = false;
    });
    _searchController.clear();
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      unawaited(_runSearch(value));
    });
  }

  Future<void> _runSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchQuery = '';
        _searchHits = const [];
        _activeSearchHitIndex = 0;
        _pendingScrollMessageId = null;
        _highlightedMessageId = null;
        _highlightPulseOn = false;
        _isSearchBusy = false;
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _isSearchBusy = true;
    });

    try {
      final hits = await ref.read(chatDatabaseProvider).searchMessages(query);
      if (!mounted) return;
      setState(() {
        _searchHits = hits;
        _activeSearchHitIndex = 0;
        _isSearchBusy = false;
      });
      if (hits.isEmpty) {
        setState(() {
          _pendingScrollMessageId = null;
          _highlightedMessageId = null;
          _highlightPulseOn = false;
        });
        return;
      }
      await _activateSearchHit(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchHits = const [];
        _activeSearchHitIndex = 0;
        _pendingScrollMessageId = null;
        _highlightedMessageId = null;
        _highlightPulseOn = false;
        _isSearchBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('搜索失败，请重试'))),
      );
    }
  }

  Future<void> _activateSearchHit(int index) async {
    if (_searchHits.isEmpty) return;
    final clamped = index.clamp(0, _searchHits.length - 1);
    final hit = _searchHits[clamped];
    setState(() {
      _activeSearchHitIndex = clamped;
      _pendingScrollMessageId = hit.messageId;
      _highlightedMessageId = hit.messageId;
      _highlightPulseOn = true;
      _followLatest = false;
      _showJumpToLatest = true;
    });
    if (ref.read(currentSessionIdProvider) != hit.sessionId) {
      _suppressAutoJumpOnce = true;
      await _setCurrentSession(hit.sessionId);
      ref.read(messagesProvider.notifier).refresh();
      _showSessionSwitchedNotice(hit.sessionId);
    } else {
      _scheduleEnsureVisibleForPendingTarget();
    }
  }

  Future<void> _navigateSearchHit(int delta) async {
    if (_searchHits.isEmpty) return;
    final next = (_activeSearchHitIndex + delta).clamp(0, _searchHits.length - 1);
    if (next == _activeSearchHitIndex) return;
    await _activateSearchHit(next);
  }

  void _scheduleEnsureVisibleForPendingTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final targetId = _pendingScrollMessageId;
      if (targetId == null) return;
      final messages = ref.read(messagesProvider);
      final index = messages.indexWhere((m) => m.id == targetId);
      if (index == -1) return;

      final key = _messageItemKeys[targetId];
      if (key?.currentContext == null) {
        if (_scrollController.hasClients) {
          final estimated = (index * 260.0).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.jumpTo(estimated);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scheduleEnsureVisibleForPendingTarget();
            }
          });
        }
        return;
      }

      await Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.18,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
      if (!mounted) return;
      setState(() {
        _pendingScrollMessageId = null;
      });
      _triggerHighlightPulse(targetId);
    });
  }

  void _triggerHighlightPulse(int messageId) {
    _highlightPulseTimer?.cancel();
    var ticks = 0;
    setState(() {
      _highlightedMessageId = messageId;
      _highlightPulseOn = true;
    });
    _highlightPulseTimer = Timer.periodic(const Duration(milliseconds: 320), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      ticks += 1;
      if (ticks >= 5) {
        timer.cancel();
        setState(() {
          _highlightPulseOn = false;
          _highlightedMessageId = null;
        });
        return;
      }
      setState(() {
        _highlightPulseOn = !_highlightPulseOn;
      });
    });
  }
  Widget _buildPromptText(String prompt, {required bool highlightMatches}) {
    final query = _searchQuery.trim();
    final baseStyle = Theme.of(context).textTheme.bodyLarge;
    if (!highlightMatches || query.isEmpty) {
      return Text(prompt, style: baseStyle);
    }
    final lowerPrompt = prompt.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lowerPrompt.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: prompt.substring(start), style: baseStyle));
        break;
      }
      if (index > start) {
        spans.add(
          TextSpan(text: prompt.substring(start, index), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: prompt.substring(index, index + query.length),
          style: baseStyle?.copyWith(
            backgroundColor: const Color(0xFFFFEB3B),
            fontWeight: FontWeight.w700,
            color: baseStyle.color,
          ),
        ),
      );
      start = index + query.length;
    }
    return Text.rich(TextSpan(children: spans, style: baseStyle));
  }

  Widget? _buildSearchNavigator() {
    if (!_isSearchMode || _searchQuery.isEmpty) return null;
    final total = _searchHits.length;
    final current = total == 0 ? 0 : _activeSearchHitIndex + 1;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: _tr('上一个命中'),
              onPressed: total > 1 && current > 1 ? () => _navigateSearchHit(-1) : null,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$current/$total',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const Divider(height: 12),
            IconButton(
              tooltip: _tr('下一个命中'),
              onPressed: total > 1 && current < total ? () => _navigateSearchHit(1) : null,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
          ],
        ),
      ),
    );
  }

  void _tryAutoLoadHomeBalance(ApiConfig config) {
    if (!config.showBalanceOnHome) {
      _homeBalanceAutoLoaded = false;
      return;
    }
    if (_homeBalanceAutoLoaded) return;

    final state = ref.read(balanceProvider);
    if (state.isLoading || state.balance != null) {
      _homeBalanceAutoLoaded = true;
      return;
    }

    _homeBalanceAutoLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(balanceProvider.notifier).refresh();
    });
  }

  void _logImageDebug({
    required String message,
    Map<String, dynamic>? extra,
  }) {
    unawaited(
      ref.read(appLogServiceProvider).append(
            level: 'info',
            message: message,
            extra: extra,
          ),
    );
  }

  void _onPromptChanged() {
    if (_isRestoringDraft) return;
    _schedulePersistComposerDraft();
  }

  double _distanceToLatestPx() {
    if (!_scrollController.hasClients) return 0;
    final position = _scrollController.position;
    final distance = position.maxScrollExtent - position.pixels;
    return distance < 0 ? 0 : distance;
  }

  void _handleListScroll() {
    if (!_scrollController.hasClients) return;
    final currentPixels = _scrollController.position.pixels;
    final previousPixels = _lastScrollPixels;
    _lastScrollPixels = currentPixels;
    final scrollDirection = _scrollController.position.userScrollDirection;

    final movedUp =
        previousPixels != null && currentPixels < previousPixels - 1;
    if (movedUp || scrollDirection == ScrollDirection.forward) {
      _scrollSettleTimer?.cancel();
      _scrollLateSettleTimer?.cancel();
      if (_followLatest || !_showJumpToLatest) {
        setState(() {
          _followLatest = false;
          _showJumpToLatest = true;
        });
      }
      return;
    }

    final nearLatest = _distanceToLatestPx() <= 72;
    if (nearLatest == _followLatest && _showJumpToLatest == !nearLatest) {
      return;
    }
    setState(() {
      _followLatest = nearLatest;
      _showJumpToLatest = !nearLatest;
    });
  }

  void _jumpToLatest({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }
    _scrollController.jumpTo(target);
  }

  void _scheduleJumpToLatest({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (!_followLatest && !force) return;
      _jumpToLatest(animated: !force);

      _scrollSettleTimer?.cancel();
      _scrollSettleTimer = Timer(const Duration(milliseconds: 320), () {
        if (!mounted || !_scrollController.hasClients) return;
        if (!_followLatest && !force) return;
        _jumpToLatest(animated: false);
      });

      _scrollLateSettleTimer?.cancel();
      if (force) {
        _scrollLateSettleTimer = Timer(const Duration(milliseconds: 720), () {
          if (!mounted || !_scrollController.hasClients) return;
          if (!_followLatest && !force) return;
          _jumpToLatest(animated: false);
        });
      }
    });
  }

  Future<Uint8List> _maybePreprocessPickedReference(
    Uint8List original, {
    required String source,
  }) async {
    final config = ref.read(apiConfigProvider);
    if (!config.referencePreprocessOnPick) return original;

    try {
      final processed = await compute<Map<String, Object>, Uint8List>(
        _preprocessReferenceBytesInIsolate,
        <String, Object>{
          'bytes': original,
          'maxDimension': config.referenceMaxDimension,
          'quality': config.referenceQuality,
          'format': config.referenceNormalizeFormat,
        },
      );
      if (processed.isEmpty) {
        _logImageDebug(
          message: 'pick preprocess decode failed',
          extra: {'source': source, 'bytes': original.length},
        );
        return original;
      }
      _logImageDebug(
        message: 'pick preprocess applied',
        extra: {
          'source': source,
          'beforeBytes': original.length,
          'afterBytes': processed.length,
          'maxDimension': config.referenceMaxDimension,
          'format': config.referenceNormalizeFormat,
          'quality': config.referenceQuality,
        },
      );
      return processed;
    } catch (e) {
      _logImageDebug(
        message: 'pick preprocess failed',
        extra: {'source': source, 'error': '$e'},
      );
      return original;
    }
  }

  Future<Uint8List> _shrinkOversizeReferenceIfNeeded(Uint8List input) async {
    final config = ref.read(apiConfigProvider);
    final maxSingleMb = config.referenceMaxSingleImageMb.clamp(20, 60);
    final maxSingleBytes = maxSingleMb * 1024 * 1024;
    if (input.length <= maxSingleBytes) return input;

    try {
      final best = await compute<Map<String, Object>, Uint8List>(
        _shrinkOversizeReferenceInIsolate,
        <String, Object>{
          'bytes': input,
          'maxSingleBytes': maxSingleBytes,
        },
      );
      if (best.isNotEmpty && best.length < input.length) {
        _logImageDebug(
          message: 'oversize reference auto shrink result',
          extra: {
            'beforeBytes': input.length,
            'afterBytes': best.length,
            'maxSingleMb': maxSingleMb,
          },
        );
      }
      return best.isEmpty ? input : best;
    } catch (e) {
      _logImageDebug(
        message: 'oversize reference auto shrink exception',
        extra: {'error': '$e'},
      );
      return input;
    }
  }

  Future<Directory> _composerDraftDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(base.path, _composerDraftDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _composerDraftManifestFile() async {
    final dir = await _composerDraftDir();
    return File(path.join(dir.path, _composerDraftManifestName));
  }

  Future<Directory> _composerDraftRefsDir() async {
    final dir = await _composerDraftDir();
    final refsDir = Directory(path.join(dir.path, _composerDraftRefsDirName));
    if (!await refsDir.exists()) {
      await refsDir.create(recursive: true);
    }
    return refsDir;
  }

  void _schedulePersistComposerDraft() {
    if (_isRestoringDraft) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_persistComposerDraftNow()),
    );
  }

  Future<void> _persistComposerDraftNow() async {
    if (!mounted) return;
    if (_isRestoringDraft) return;
    try {
      final prompt = _promptController.text;
      final refs = ref.read(generationProvider).referenceImages;
      final isEmpty = prompt.trim().isEmpty && refs.isEmpty;
      if (isEmpty) {
        await _clearComposerDraftStorage();
        return;
      }

      final refsDir = await _composerDraftRefsDir();
      if (await refsDir.exists()) {
        await for (final entity in refsDir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }

      final files = <String>[];
      for (var i = 0; i < refs.length; i++) {
        final fileName = 'ref_$i.bin';
        final file = File(path.join(refsDir.path, fileName));
        await file.writeAsBytes(refs[i], flush: true);
        files.add(fileName);
      }

      final manifest = <String, dynamic>{
        'prompt': prompt,
        'files': files,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      final manifestFile = await _composerDraftManifestFile();
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);
    } catch (e) {
      _logImageDebug(
        message: 'composer draft save failed',
        extra: {'error': '$e'},
      );
    }
  }

  Future<void> _clearComposerDraftStorage() async {
    try {
      final manifestFile = await _composerDraftManifestFile();
      if (await manifestFile.exists()) {
        await manifestFile.delete();
      }
      final refsDir = await _composerDraftRefsDir();
      if (await refsDir.exists()) {
        await refsDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> _restoreComposerDraftIfNeeded() async {
    if (_draftRestored) return;
    _draftRestored = true;
    try {
      final manifestFile = await _composerDraftManifestFile();
      if (!await manifestFile.exists()) return;

      final raw = await manifestFile.readAsString();
      if (raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final prompt = (decoded['prompt']?.toString() ?? '');
      final filesRaw = decoded['files'];
      final files = <String>[];
      if (filesRaw is List) {
        for (final item in filesRaw) {
          final text = item?.toString() ?? '';
          if (text.isNotEmpty) files.add(text);
        }
      }

      final generationState = ref.read(generationProvider);
      final shouldRestorePrompt =
          _promptController.text.trim().isEmpty && prompt.trim().isNotEmpty;
      final shouldRestoreRefs =
          generationState.referenceImages.isEmpty && files.isNotEmpty;

      if (!shouldRestorePrompt && !shouldRestoreRefs) return;

      _isRestoringDraft = true;
      if (shouldRestorePrompt) {
        _promptController.text = prompt;
      }

      if (shouldRestoreRefs) {
        final refsDir = await _composerDraftRefsDir();
        final notifier = ref.read(generationProvider.notifier);
        for (final fileName in files) {
          final file = File(path.join(refsDir.path, fileName));
          if (!await file.exists()) continue;
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) continue;
          notifier.addReferenceImage(
            bytes,
            source: 'draft_restore',
            extra: {'file': fileName},
          );
        }
      }
      _isRestoringDraft = false;
    } catch (e) {
      _isRestoringDraft = false;
      _logImageDebug(
        message: 'composer draft restore failed',
        extra: {'error': '$e'},
      );
    }
  }

  Future<void> _pickImage() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(_tr('内置相册')),
              onTap: () => Navigator.pop(context, 'builtin'),
            ),
            ListTile(
              leading: const Icon(Icons.perm_media),
              title: Text(_tr('系统相册')),
              onTap: () => Navigator.pop(context, 'system'),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(_tr('文件选择')),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.apps),
              title: Text(_tr('其他应用')),
              onTap: () => Navigator.pop(context, 'other'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    _logImageDebug(
      message: 'pick image source selected',
      extra: {'source': choice},
    );

    Uint8List? bytes;
    String readMode = '';
    String? pickedPath;
    var systemPickerCancelled = false;
    if (choice == 'builtin') {
      bytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryPickerScreen(sourceTag: choice),
        ),
      );
      readMode = 'gallery_route';
    } else if (choice == 'system') {
      if (Platform.isAndroid) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: false,
        );
        _logImageDebug(
          message: 'file picker returned',
          extra: {
            'source': choice,
            'hasResult': result != null,
            'fileCount': result?.files.length ?? 0,
          },
        );
        if (result == null || result.files.isEmpty) {
          systemPickerCancelled = true;
        }
        if (result != null && result.files.isNotEmpty) {
          final f = result.files.first;
          _logImageDebug(
            message: 'file picker first item',
            extra: {
              'name': f.name,
              'path': f.path,
              'size': f.size,
              'hasBytes': f.bytes != null,
              'bytesLength': f.bytes?.length ?? 0,
            },
          );
          if (f.path != null) {
            pickedPath = f.path;
            try {
              bytes = await File(f.path!).readAsBytes();
              readMode = 'file_path';
            } catch (e) {
              _logImageDebug(
                message: 'file path read failed',
                extra: {'path': f.path, 'error': '$e'},
              );
            }
          } else if (f.bytes != null) {
            bytes = f.bytes;
            readMode = 'file_bytes';
          }
        }
        try {
          final cleared = await FilePicker.platform.clearTemporaryFiles();
          _logImageDebug(
            message: 'file picker temp cleared',
            extra: {'cleared': cleared},
          );
        } catch (e) {
          _logImageDebug(
            message: 'file picker temp clear failed',
            extra: {'error': '$e'},
          );
        }
        if (systemPickerCancelled) {
          _logImageDebug(
            message: 'system picker cancelled by user',
            extra: {'source': choice},
          );
          return;
        }
      }

      // Fallback for Android failure and primary path for non-Android platforms.
      if (bytes == null && !systemPickerCancelled) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        _logImageDebug(
          message: 'image_picker returned',
          extra: {
            'source': choice,
            'hasResult': picked != null,
            'path': picked?.path,
          },
        );
        if (picked != null) {
          pickedPath = picked.path;
          bytes = await picked.readAsBytes();
          readMode = 'image_picker_gallery';
        }
      }
    } else if (choice == 'other') {
      if (Platform.isAndroid) {
        dynamic chooserResult;
        try {
          chooserResult = await _imageChooserChannel.invokeMethod<dynamic>(
            'pickImageWithChooser',
            <String, dynamic>{'title': _tr('选择应用上传图片')},
          );
        } on PlatformException catch (e) {
          _logImageDebug(
            message: 'image chooser failed',
            extra: {'source': choice, 'code': e.code, 'message': e.message},
          );
        }
        _logImageDebug(
          message: 'image chooser returned',
          extra: {
            'source': choice,
            'hasResult': chooserResult != null,
            'resultType': chooserResult?.runtimeType.toString(),
          },
        );
        if (chooserResult is Map) {
          final resultMap = Map<dynamic, dynamic>.from(chooserResult);
          final rawBytes = resultMap['bytes'];
          final pickedUri = resultMap['uri']?.toString();
          if (rawBytes is Uint8List) {
            bytes = rawBytes;
            readMode = 'android_intent_chooser';
            pickedPath = pickedUri;
          } else if (rawBytes is List) {
            try {
              bytes = Uint8List.fromList(rawBytes.cast<int>());
              readMode = 'android_intent_chooser';
              pickedPath = pickedUri;
            } catch (e) {
              _logImageDebug(
                message: 'image chooser cast bytes failed',
                extra: {'source': choice, 'error': '$e'},
              );
            }
          }
        }
      }

      if (bytes == null) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        _logImageDebug(
          message: 'image_picker returned',
          extra: {
            'source': choice,
            'hasResult': picked != null,
            'path': picked?.path,
          },
        );
        if (picked != null) {
          pickedPath = picked.path;
          bytes = await picked.readAsBytes();
          readMode = 'image_picker_gallery';
        }
      }
    } else {
      if (Platform.isAndroid || Platform.isIOS) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        _logImageDebug(
          message: 'image_picker returned',
          extra: {
            'source': choice,
            'hasResult': picked != null,
            'path': picked?.path,
          },
        );
        if (picked != null) {
          pickedPath = picked.path;
          bytes = await picked.readAsBytes();
          readMode = 'image_picker_gallery';
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: false,
        );
        _logImageDebug(
          message: 'file picker returned',
          extra: {
            'hasResult': result != null,
            'fileCount': result?.files.length ?? 0,
          },
        );
        if (result != null && result.files.isNotEmpty) {
          final f = result.files.first;
          _logImageDebug(
            message: 'file picker first item',
            extra: {
              'name': f.name,
              'path': f.path,
              'size': f.size,
              'hasBytes': f.bytes != null,
              'bytesLength': f.bytes?.length ?? 0,
            },
          );
          if (f.path != null) {
            pickedPath = f.path;
            try {
              bytes = await File(f.path!).readAsBytes();
              readMode = 'file_path';
            } catch (e) {
              _logImageDebug(
                message: 'file path read failed',
                extra: {'path': f.path, 'error': '$e'},
              );
            }
          } else if (f.bytes != null) {
            bytes = f.bytes;
            readMode = 'file_bytes';
          }
        }
        try {
          final cleared = await FilePicker.platform.clearTemporaryFiles();
          _logImageDebug(
            message: 'file picker temp cleared',
            extra: {'cleared': cleared},
          );
        } catch (e) {
          _logImageDebug(
            message: 'file picker temp clear failed',
            extra: {'error': '$e'},
          );
        }
      }
    }
    if (bytes != null) {
      final preparedBytes = await _maybePreprocessPickedReference(
        bytes,
        source: choice,
      );
      var finalBytes = preparedBytes;
      var error = ref.read(generationProvider.notifier).addReferenceImage(
        finalBytes,
        source: choice,
        extra: {
          'readMode': readMode,
          'originalBytes': bytes.length,
          'finalBytes': finalBytes.length,
          if (pickedPath != null) 'pickedPath': pickedPath,
        },
      );

      final config = ref.read(apiConfigProvider);
      final maxSingleBytes =
          config.referenceMaxSingleImageMb.clamp(20, 60) * 1024 * 1024;
      final isSingleLimitError =
          error != null && finalBytes.length > maxSingleBytes;
      if (isSingleLimitError) {
        final shrunk = await _shrinkOversizeReferenceIfNeeded(finalBytes);
        if (shrunk.length < finalBytes.length) {
          final retryError =
              ref.read(generationProvider.notifier).addReferenceImage(
            shrunk,
            source: '${choice}_oversize_auto',
            extra: {
              'readMode': readMode,
              'originalBytes': bytes.length,
              'beforeRetryBytes': finalBytes.length,
              'afterRetryBytes': shrunk.length,
              if (pickedPath != null) 'pickedPath': pickedPath,
            },
          );
          if (retryError == null) {
            if (!mounted) return;
            _schedulePersistComposerDraft();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_tr('图片过大，已自动压缩后添加'))),
            );
            return;
          }
          error = retryError;
        }
      }

      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      } else {
        _schedulePersistComposerDraft();
      }
    } else {
      _logImageDebug(
        message: 'pick image produced null bytes',
        extra: {
          'source': choice,
          'readMode': readMode,
          if (pickedPath != null) 'pickedPath': pickedPath,
        },
      );
    }
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('请输入提示词'))),
      );
      return;
    }

    final config = ref.read(apiConfigProvider);
    if (!config.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('请先配置 API')),
          action: SnackBarAction(
            label: _tr('设置'),
            onPressed: _openSettings,
          ),
        ),
      );
      return;
    }

    final queued = await ref.read(generationProvider.notifier).generate(prompt);
    if (!queued) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('任务加入队列失败，请重试'))),
      );
      return;
    }

    _triggerQueuePeek();
    _promptController.clear();
    _schedulePersistComposerDraft();
  }

  Future<void> _newSession() async {
    final session = await ref.read(sessionsProvider.notifier).createSession();
    await _setCurrentSession(session.id);
    _showSessionSwitchedNotice(session.id);
    _followLatest = true;
    _showJumpToLatest = false;
    _clearReferenceImages();
    ref.read(generationProvider.notifier).clearResult();
    _schedulePersistComposerDraft();
    _scheduleJumpToLatest(force: true);
  }

  void _clearReferenceImages() {
    ref.read(generationProvider.notifier).clearReferenceImages();
    _schedulePersistComposerDraft();
  }

  void _removeReferenceImage(int index) {
    ref.read(generationProvider.notifier).removeReferenceImage(index);
    _schedulePersistComposerDraft();
  }

  void _reorderReferenceImages(int oldIndex, int newIndex) {
    ref.read(generationProvider.notifier).reorderReferenceImages(
          oldIndex,
          newIndex,
        );
    _schedulePersistComposerDraft();
  }

  String _referenceImageUiKey(Uint8List bytes) {
    final take = bytes.length < 8 ? bytes.length : 8;
    final head =
        bytes.take(take).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${bytes.length}:$head';
  }

  Future<void> _copyText(
    String text, {
    String success = '',
  }) async {
    final successText = success.isEmpty ? _tr('已复制') : success;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    if (Platform.isAndroid) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(successText)));
  }

  void _showConfiguredSnackBar(String message) {
    if (!mounted) return;
    final config = ref.read(apiConfigProvider);
    final media = MediaQuery.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final isTop = config.snackBarPosition == ApiConfig.snackBarPositionTop;

    final topMargin = media.padding.top + kToolbarHeight + 12;
    final minBottomMargin = media.padding.bottom + 12;
    double bottomMargin;
    if (isTop) {
      bottomMargin = media.size.height - topMargin - 56;
      if (bottomMargin < minBottomMargin) {
        bottomMargin = minBottomMargin;
      }
    } else {
      bottomMargin = media.viewInsets.bottom + media.padding.bottom + 96;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin:
            EdgeInsets.fromLTRB(12, isTop ? topMargin : 0, 12, bottomMargin),
      ),
    );
  }

  Future<Uint8List?> _resolveMessageImageBytes(ChatMessage message) async {
    if (message.imageBytes != null && message.imageBytes!.isNotEmpty) {
      return message.imageBytes!;
    }

    final imageUrl = message.imageUrl;
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;

    if (imageUrl.startsWith('http')) {
      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(imageUrl));
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          client.close(force: true);
          return null;
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response) {
          builder.add(chunk);
        }
        client.close(force: true);
        return builder.takeBytes();
      } catch (_) {
        return null;
      }
    }

    try {
      final file = File(imageUrl);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveMessageImage(ChatMessage message) async {
    final bytes = await _resolveMessageImageBytes(message);
    if (!mounted) return;

    if (bytes == null || bytes.isEmpty) {
      _showConfiguredSnackBar(_tr('未找到可保存的图片数据'));
      return;
    }

    try {
      final mimeType = _sniffImageMimeType(bytes);
      final ext = _mimeToExt(mimeType);
      final fileName =
          'NanoBanana_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final savedPath = await _mediaScannerChannel.invokeMethod<String>(
        'saveToGallery',
        <String, dynamic>{
          'bytes': bytes,
          'fileName': fileName,
          'mimeType': mimeType,
        },
      );
      if (!mounted) return;
      _showConfiguredSnackBar(
        (savedPath == null || savedPath.isEmpty)
            ? _tr('已保存到相册')
            : '${_tr('已保存到相册')}: $savedPath',
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showConfiguredSnackBar(
        _tr('保存失败: {error}', args: {'error': e.message ?? e.code}),
      );
    } catch (e) {
      if (!mounted) return;
      _showConfiguredSnackBar(_tr('保存失败: {error}', args: {'error': '$e'}));
    }
  }

  String _sniffImageMimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'image/gif';
    }
    return 'image/png';
  }

  String _mimeToExt(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/png':
      default:
        return 'png';
    }
  }

  Future<void> _retry(ChatMessage message) async {
    final queued =
        await ref.read(generationProvider.notifier).retryMessage(message);
    if (!mounted) return;
    if (queued) {
      _triggerQueuePeek();
    }
    _showConfiguredSnackBar(
      queued ? _tr('已加入重试队列') : _tr('重试加入队列失败，请重试'),
    );
  }

  Future<void> _pickModel() async {
    final config = ref.read(apiConfigProvider);
    final notifier = ref.read(apiConfigProvider.notifier);
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(_tr('选择模型'))),
            for (final m in ApiConfig.availableModels)
              ListTile(
                title: Text(m['name'] ?? m['id'] ?? ''),
                subtitle: Text(m['id'] ?? ''),
                trailing:
                    m['id'] == config.model ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, m['id']),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null || selected == config.model) return;
    notifier.setModel(selected);
  }

  Future<void> _pickAspect() async {
    final config = ref.read(apiConfigProvider);
    final notifier = ref.read(apiConfigProvider.notifier);
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(_tr('选择比例'))),
            for (final ratio in ApiConfig.availableAspectRatios)
              ListTile(
                title: Text(
                  ratio == ApiConfig.autoAspectRatio
                      ? _tr('自动比例（模型决定）')
                      : ratio,
                ),
                trailing: ratio == config.aspectRatio
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, ratio),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null || selected == config.aspectRatio) return;
    notifier.setAspectRatio(selected);
  }

  Future<void> _pickImageSize() async {
    final config = ref.read(apiConfigProvider);
    if (!config.supportsImageSize) return;
    final notifier = ref.read(apiConfigProvider.notifier);
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(_tr('选择分辨率'))),
            for (final size in ApiConfig.availableImageSizes)
              ListTile(
                title: Text(size),
                trailing:
                    size == config.imageSize ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, size),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null || selected == config.imageSize) return;
    notifier.setImageSize(selected);
  }

  Future<void> _editQueuedPrompt(GenerationQueueTask task) async {
    if (task.status != QueueTaskStatus.pending) return;
    final controller = TextEditingController(text: task.prompt);
    final newPrompt = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('编辑队列提示词')),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: _tr('输入新的提示词'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_tr('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(_tr('保存')),
          ),
        ],
      ),
    );
    if (newPrompt == null || newPrompt.isEmpty) return;
    ref.read(generationProvider.notifier).updateQueuedTaskPrompt(
          task.id,
          newPrompt,
        );
  }

  Future<void> _duplicateQueuedTask(GenerationQueueTask task) async {
    final queued =
        await ref.read(generationProvider.notifier).duplicateQueuedTask(task.id);
    if (!mounted) return;
    if (queued) {
      _triggerQueuePeek();
    }
    _showConfiguredSnackBar(
      queued ? _tr('已复制任务到队列') : _tr('复制任务失败，请重试'),
    );
  }

  Future<void> _reuseMessageReferences(ChatMessage message) async {
    if (message.referenceImagePaths.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('这条记录没有参考图'))),
      );
      return;
    }

    var added = 0;
    for (final path in message.referenceImagePaths) {
      final ok = await ref
          .read(generationProvider.notifier)
          .useHistoryImageAsReference(path);
      if (ok) {
        added += 1;
      }
    }
    if (!mounted) return;
    if (added > 0) {
      _schedulePersistComposerDraft();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('已加入 {count} 张参考图', args: {'count': added})),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('复用失败：参考图文件可能已丢失'))),
    );
  }

  Future<void> _reuseGeneratedImage(ChatMessage message) async {
    final bytes = await _resolveMessageImageBytes(message);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('无法读取可复用的图片数据'))),
      );
      return;
    }

    final preparedBytes = await _maybePreprocessPickedReference(
      bytes,
      source: 'reuse_generated',
    );
    if (!mounted) return;
    final error = ref.read(generationProvider.notifier).addReferenceImage(
      preparedBytes,
      source: 'reuse_generated',
      extra: {
        if ((message.imageUrl ?? '').isNotEmpty) 'from': message.imageUrl,
        'originalBytes': bytes.length,
        'finalBytes': preparedBytes.length,
      },
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    _schedulePersistComposerDraft();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('已将生成图加入参考图'))),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (!mounted) return;

    // Guard against accidental session loss after returning from settings.
    await ref.read(sessionsProvider.notifier).loadSessions();
    final sessions = ref.read(sessionsProvider);
    final currentSessionId = ref.read(currentSessionIdProvider);

    if (currentSessionId == null) {
      final savedSessionId =
          await ref.read(storageServiceProvider).loadLastSessionId();
      int? targetSessionId;
      if (savedSessionId != null &&
          sessions.any((s) => s.id == savedSessionId)) {
        targetSessionId = savedSessionId;
      } else if (sessions.isNotEmpty) {
        targetSessionId = sessions.first.id;
      }
      if (targetSessionId != null) {
        await _setCurrentSession(targetSessionId);
      }
    } else {
      ref.read(messagesProvider.notifier).refresh();
    }

    ref.invalidate(usageStatsProvider);
    _scheduleJumpToLatest(force: true);
  }

  String _formatDuration(int? ms) {
    if (ms == null || ms <= 0) return _tr('未知');
    if (ms < 1000) return '${ms}ms';
    final seconds = ms / 1000;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minute = ms ~/ 60000;
    final second = (ms % 60000) / 1000;
    return '${minute}m ${second.toStringAsFixed(1)}s';
  }

  String _formatDateTime(DateTime dateTime) {
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${dateTime.year}-${p2(dateTime.month)}-${p2(dateTime.day)} '
        '${p2(dateTime.hour)}:${p2(dateTime.minute)}:${p2(dateTime.second)}';
  }

  String _queueStatusText(QueueTaskStatus status) {
    switch (status) {
      case QueueTaskStatus.pending:
        return _tr('等待中');
      case QueueTaskStatus.running:
        return _tr('执行中');
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return _tr('刚刚');
    if (diff.inMinutes < 60) {
      return _tr('{count} 分钟前', args: {'count': diff.inMinutes});
    }
    if (diff.inHours < 24) {
      return _tr('{count} 小时前', args: {'count': diff.inHours});
    }
    if (diff.inDays < 7) {
      return _tr('{count} 天前', args: {'count': diff.inDays});
    }
    return '${dateTime.month}/${dateTime.day} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _renameSession(ChatSession session) async {
    final sessionId = session.id;
    if (sessionId == null) return;

    final controller = TextEditingController(text: session.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('重命名')),
        content: TextField(
          controller: controller,
          maxLength: 40,
          decoration: InputDecoration(
            hintText: _tr('输入新名称'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_tr('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(_tr('保存')),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.isEmpty || newTitle == session.title) {
      return;
    }

    await ref
        .read(sessionsProvider.notifier)
        .renameSession(sessionId, newTitle);
  }

  Future<void> _deleteSession(ChatSession session) async {
    final sessionId = session.id;
    if (sessionId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('删除会话')),
        content: Text(_tr('删除后不可恢复，确认删除该会话吗？')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('删除')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deletingCurrent = ref.read(currentSessionIdProvider) == sessionId;
    await ref.read(sessionsProvider.notifier).deleteSession(sessionId);

    if (!deletingCurrent) return;
    final remain = ref.read(sessionsProvider);
    if (remain.isEmpty) {
      await _newSession();
      return;
    }

    await _setCurrentSession(remain.first.id);
    ref.read(messagesProvider.notifier).refresh();
  }

  Widget _buildChatMessageCard(ChatMessage msg) {
    final canSaveImage =
        msg.isSuccess && (msg.imageUrl?.trim().isNotEmpty ?? false);
    final canReuseGenerated =
        msg.isSuccess &&
        ((msg.imageUrl?.trim().isNotEmpty ?? false) ||
            (msg.imageBytes?.isNotEmpty ?? false));
    final hasErrorText =
        !msg.isSuccess && (msg.errorMessage ?? '').trim().isNotEmpty;
    final messageId = msg.id;
    final isSearchTarget = messageId != null && _highlightedMessageId == messageId;
    final isActiveSearchHit = isSearchTarget && _highlightPulseOn;

    return KeyedSubtree(
      key: _messageItemKey(messageId),
      child: ChatMessageCard(
        prompt: msg.prompt,
        promptWidget: _buildPromptText(
          msg.prompt,
          highlightMatches: isSearchTarget,
        ),
        isHighlighted: isActiveSearchHit,
        statusText: msg.isSuccess ? _tr('成功') : _tr('失败'),
        timeText: '${_tr('时间')}: ${_formatDateTime(msg.createdAt)}',
        durationText: '${_tr('耗时')}: ${_formatDuration(msg.generationDurationMs)}',
        copyPromptLabel: _tr('复制提示词'),
        retryLabel: _tr('重试'),
        saveImageLabel: canSaveImage ? _tr('保存图片') : null,
        reuseReferencesLabel:
            msg.referenceImagePaths.isNotEmpty ? _tr('复用参考图') : null,
        reuseGeneratedImageLabel:
            canReuseGenerated ? _tr('复用生成图') : null,
        copyErrorLabel: hasErrorText ? _tr('复制错误') : null,
        onCopyPrompt: () => _copyText(
          msg.prompt,
          success: _tr('提示词已复制'),
        ),
        onRetry: () => _retry(msg),
        onSaveImage: canSaveImage ? () => _saveMessageImage(msg) : null,
        onReuseReferences: msg.referenceImagePaths.isNotEmpty
            ? () => _reuseMessageReferences(msg)
            : null,
        onReuseGeneratedImage:
            canReuseGenerated ? () => _reuseGeneratedImage(msg) : null,
        onCopyError: hasErrorText
            ? () => _copyText(
                  msg.errorMessage!,
                  success: _tr('错误信息已复制'),
                )
            : null,
        imageWidget: canReuseGenerated ? _buildMessageImage(msg) : null,
        errorText: msg.isSuccess ? null : (msg.errorMessage ?? _tr('生成失败')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(apiConfigProvider);
    final sessions = ref.watch(sessionsProvider);
    final currentSessionId = ref.watch(currentSessionIdProvider);
    final messages = ref.watch(messagesProvider);
    final generationState = ref.watch(generationProvider);
    final balanceState = ref.watch(balanceProvider);
    final currentSessionTitle = _resolveCurrentSessionTitle(
      sessions,
      currentSessionId,
    );

    _tryAutoLoadHomeBalance(config);
    if (_pendingScrollMessageId != null) {
      _scheduleEnsureVisibleForPendingTarget();
    }
    if (_lastRenderedSessionId != currentSessionId) {
      _lastRenderedSessionId = currentSessionId;
      _lastRenderedMessageCount = messages.length;
      if (_suppressAutoJumpOnce) {
        _suppressAutoJumpOnce = false;
        _followLatest = false;
        _showJumpToLatest = true;
      } else {
        _followLatest = true;
        _showJumpToLatest = false;
        _scheduleJumpToLatest(force: true);
      }
    } else if (messages.length != _lastRenderedMessageCount) {
      final grew = messages.length > _lastRenderedMessageCount;
      _lastRenderedMessageCount = messages.length;
      if (grew) {
        _scheduleJumpToLatest();
      }
    }

    if (_sessionRestoreDone &&
        currentSessionId == null &&
        sessions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final id = sessions.any((s) => s.id == _lastSessionId)
            ? _lastSessionId
            : sessions.first.id;
        if (id != null && ref.read(currentSessionIdProvider) == null) {
          _setCurrentSession(id);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearchMode
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _tr('搜索提示词...'),
                  border: InputBorder.none,
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: _tr('清空'),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (value) => unawaited(_runSearch(value)),
              )
            : Text(currentSessionTitle),
        centerTitle: !_isSearchMode,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(_isSearchMode ? Icons.arrow_back : Icons.menu),
            onPressed: _isSearchMode
                ? _closeSearch
                : () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: _isSearchMode
            ? [
                if (_isSearchBusy)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: _tr('搜索'),
                  onPressed: _openSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.add_comment),
                  tooltip: _tr('新对话'),
                  onPressed: _newSession,
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _openSettings,
                ),
              ],
      ),
      drawer: _buildSessionDrawer(),
      body: Column(
        children: [
          Expanded(
            child: HomeMessagesPane(
              scrollController: _scrollController,
              messagesCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return _buildChatMessageCard(msg);
              },
              showJumpToLatest: !_isSearchMode && _showJumpToLatest,
              jumpToLatestTooltip: _tr('跳转到最新消息'),
              onScrollNotification: (notification) {
                if (notification.direction == ScrollDirection.forward) {
                  _scrollSettleTimer?.cancel();
                  _scrollLateSettleTimer?.cancel();
                  if (_followLatest || !_showJumpToLatest) {
                    setState(() {
                      _followLatest = false;
                      _showJumpToLatest = true;
                    });
                  }
                }
                return false;
              },
              onJumpToLatest: () {
                setState(() {
                  _followLatest = true;
                  _showJumpToLatest = false;
                });
                _scheduleJumpToLatest(force: true);
              },
              searchNavigator: _buildSearchNavigator(),
            ),
          ),
          _buildComposerPanel(config, generationState, balanceState),
        ],
      ),
    );
  }

  Widget _buildComposerPanel(
    ApiConfig config,
    GenerationState generationState,
    BalanceState balanceState,
  ) {
    return HomeComposerPanel(
      showBalanceOnHome: config.showBalanceOnHome,
      balanceCard: _buildHomeBalanceCard(balanceState),
      queuePanel: _buildQueuePanel(generationState),
      hasQueue: generationState.queue.isNotEmpty,
      showGeneratingHint:
          generationState.isLoading && generationState.queue.isEmpty,
      generatingHint: _buildGeneratingHint(),
      hasReferenceImages: generationState.referenceImages.isNotEmpty,
      referenceImagesPanel: _buildReferenceImagesPanel(generationState, config),
      modelLabel: config.model.isEmpty ? _tr('未选择模型') : config.model,
      aspectRatioLabel: config.aspectRatio == ApiConfig.autoAspectRatio
          ? _tr('自动比例')
          : config.aspectRatio,
      imageSizeLabel: config.supportsImageSize ? config.imageSize : null,
      onPickModel: _pickModel,
      onPickAspect: _pickAspect,
      onPickImageSize: config.supportsImageSize ? _pickImageSize : null,
      onPickImage: _pickImage,
      promptController: _promptController,
      promptHintText: _tr('输入提示词...'),
      onSubmitted: (_) => _generate(),
      isLoading: generationState.isLoading,
      onSend: _generate,
      onStop: () => ref.read(generationProvider.notifier).cancelCurrentTask(),
    );
  }

  Widget _buildMessageImage(ChatMessage msg) {
    return HomeMessageImage(
      imageUrl: msg.imageUrl,
      imageBytes: msg.imageBytes,
    );
  }

  Widget _buildHomeBalanceCard(BalanceState balanceState) {
    String text;
    if (balanceState.isLoading && balanceState.balance == null) {
      text = _tr('余额查询中...');
    } else if (balanceState.balance != null) {
      text = _tr('余额:     本次总计扣费:     本次扣费: ');
    } else if ((balanceState.error ?? '').trim().isNotEmpty) {
      text = _tr('余额查询失败');
    } else {
      text = _tr('点击刷新获取余额');
    }

    return HomeBalanceCard(
      text: text,
      isLoading: balanceState.isLoading,
      refreshTooltip: _tr('刷新余额'),
      onRefresh: () => ref.read(balanceProvider.notifier).refresh(),
    );
  }

  double _referencePreviewExtent(ApiConfig config) {
    switch (config.referencePreviewSize) {
      case ApiConfig.referencePreviewSizeSmall:
        return 56;
      case ApiConfig.referencePreviewSizeLarge:
        return 88;
      case ApiConfig.referencePreviewSizeMedium:
      default:
        return 72;
    }
  }

  Widget _buildReferenceImagesPanel(
    GenerationState generationState,
    ApiConfig config,
  ) {
    return ReferenceImagesPanel(
      referenceImages: generationState.referenceImages,
      previewExtent: _referencePreviewExtent(config),
      draggingReferenceIndex: _draggingReferenceIndex,
      tr: _tr,
      imageUiKeyBuilder: _referenceImageUiKey,
      onReorder: _reorderReferenceImages,
      onReorderStart: (index) {
        if (!mounted) return;
        setState(() {
          _draggingReferenceIndex = index;
        });
      },
      onReorderEnd: (_) {
        if (!mounted || _draggingReferenceIndex == null) return;
        setState(() {
          _draggingReferenceIndex = null;
        });
      },
      onRemoveReference: _removeReferenceImage,
      onClearReferences: _clearReferenceImages,
    );
  }

  Widget _buildGeneratingHint() {
    return HomeGeneratingHint(
      text: _tr('正在生成中，可继续提交任务进入队列'),
    );
  }

  Widget _buildQueuePanel(GenerationState generationState) {
    final notifier = ref.read(generationProvider.notifier);
    return QueuePanel(
      queue: generationState.queue,
      isLoading: generationState.isLoading,
      isExpanded: _queuePanelExpanded,
      isPeeking: _queuePanelPeeking,
      tr: _tr,
      queueStatusText: _queueStatusText,
      onToggleExpanded: () {
        _queuePeekTimer?.cancel();
        setState(() {
          _queuePanelPeeking = false;
          _queuePanelExpanded = !_queuePanelExpanded;
        });
      },
      onClearQueue: () => notifier.clearQueue(cancelCurrent: false),
      onCancelTask: (task) => notifier.cancelQueuedTask(task.id),
      onMoveToFront: (task) => notifier.moveQueuedTaskToFront(task.id),
      onMoveUp: (task) => notifier.moveQueuedTaskUp(task.id),
      onMoveDown: (task) => notifier.moveQueuedTaskDown(task.id),
      onDuplicateTask: _duplicateQueuedTask,
      onEditPrompt: _editQueuedPrompt,
    );
  }

  Widget _buildSessionDrawer() {
    final sessions = ref.watch(sessionsProvider);
    final currentSessionId = ref.watch(currentSessionIdProvider);
    return HomeSessionDrawer(
      sessions: sessions,
      currentSessionId: currentSessionId,
      historyTitle: _tr('对话历史'),
      newSessionTooltip: _tr('新建对话'),
      renameLabel: _tr('重命名'),
      deleteLabel: _tr('删除'),
      historyGenerationsLabel: _tr('历史生成'),
      formatRelativeTime: _formatRelativeTime,
      onCreateSession: _newSession,
      onRenameSession: _renameSession,
      onDeleteSession: _deleteSession,
      onOpenHistoryGenerations: _openHistoryGenerations,
      onSelectSession: (session) async {
        final changedSession = ref.read(currentSessionIdProvider) != session.id;
        await _setCurrentSession(session.id);
        _followLatest = true;
        _showJumpToLatest = false;
        _clearReferenceImages();
        ref.read(generationProvider.notifier).clearResult();
        _scheduleJumpToLatest(force: true);
        if (changedSession) {
          _showSessionSwitchedNotice(session.id);
        }
      },
    );
  }

  void _triggerQueuePeek() {
    if (_queuePanelExpanded) return;

    _queuePeekTimer?.cancel();
    setState(() {
      _queuePanelPeeking = true;
    });

    _queuePeekTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _queuePanelPeeking = false;
      });
    });
  }
}


