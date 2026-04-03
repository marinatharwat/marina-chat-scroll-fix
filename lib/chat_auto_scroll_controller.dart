import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Threshold (in pixels) from the bottom of the list.
/// If the user is within this distance, we consider them "at the bottom".
const double _kBottomThreshold = 64.0;

/// How often to attempt auto-scroll while streaming.
const Duration _kScrollInterval = Duration(milliseconds: 80);

class ChatAutoScrollController {
  final ScrollController scrollController;

  // Whether auto-scroll is currently active.
  bool _autoScrollEnabled = true;

  // True while we are programmatically moving the scroll position,
  // so we can ignore the resulting scroll notifications.
  bool _isProgrammaticScroll = false;

  // Fires periodic scroll updates during streaming.
  Timer? _scrollTimer;

  bool get autoScrollEnabled => _autoScrollEnabled;

  ChatAutoScrollController({required this.scrollController}) {
    scrollController.addListener(_onScrollChanged);
  }

  // ─── Public API ───────────────────────────────────────────────

  /// Call this when a new chunk arrives or a message is inserted.
  void onContentChanged() {
    if (_autoScrollEnabled) {
      _scheduleScroll();
    }
  }

  /// Call this when streaming starts.
  void onStreamingStarted() {
    // Always re-enable when a new stream begins.
    _autoScrollEnabled = true;
    _startScrollTimer();
  }

  /// Call this when streaming ends (complete, error, or stopped).
  void onStreamingEnded() {
    _stopScrollTimer();
    // One final scroll to ensure we land at the very bottom.
    if (_autoScrollEnabled) {
      _scrollToBottom();
    }
  }

  void dispose() {
    _stopScrollTimer();
    scrollController.removeListener(_onScrollChanged);
  }

  // ─── Private ──────────────────────────────────────────────────

  void _onScrollChanged() {
    // Ignore scroll events that we triggered ourselves.
    if (_isProgrammaticScroll) return;
    if (!scrollController.hasClients) return;

    final pos = scrollController.position;

    // The user dragged upward (or flung): disable auto-scroll.
    if (pos.userScrollDirection == ScrollDirection.forward) {
      if (_autoScrollEnabled) {
        _autoScrollEnabled = false;
        _stopScrollTimer();
      }
      return;
    }

    // The user scrolled (or flung) back toward the bottom.
    if (_isNearBottom()) {
      if (!_autoScrollEnabled) {
        _autoScrollEnabled = true;
        _startScrollTimer();
      }
    }
  }

  bool _isNearBottom() {
    if (!scrollController.hasClients) return false;
    final pos = scrollController.position;
    return (pos.maxScrollExtent - pos.pixels) <= _kBottomThreshold;
  }

  void _scheduleScroll() {
    // Use a post-frame callback so the new content has been laid out
    // before we try to scroll to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoScrollEnabled) {
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    if (!scrollController.hasClients) return;
    final pos = scrollController.position;
    if (pos.maxScrollExtent <= pos.pixels) return; // already at bottom

    _isProgrammaticScroll = true;
    scrollController
        .animateTo(
      pos.maxScrollExtent,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    )
        .then((_) => _isProgrammaticScroll = false);
  }

  void _startScrollTimer() {
    _stopScrollTimer();
    // Belt-and-suspenders: periodically scroll during streaming
    // in case chunk notifications arrive faster than frame callbacks.
    _scrollTimer = Timer.periodic(_kScrollInterval, (_) {
      if (_autoScrollEnabled && scrollController.hasClients) {
        _scheduleScroll();
      }
    });
  }

  void _stopScrollTimer() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }
}