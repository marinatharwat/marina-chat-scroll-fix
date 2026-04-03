# Chat Auto-Scroll Challenge — Solution

## Deployed URL
https://marinatharwat.github.io/marina-chat-scroll-fix/
---

## UX Issues Identified & Fixed

### Issue 1: No Auto-Scroll During Streaming
**Problem:** When the AI response streams in token by token, the list stayed
static and did not follow the new content. The user had to manually scroll
down to read the latest tokens.

**Fix:** Implemented `ChatAutoScrollController` which starts a periodic timer
(every 80ms) when streaming begins, and also calls `onContentChanged()` on
every incoming chunk. Each call schedules a `addPostFrameCallback` so the
scroll happens after the new content is laid out.

---

### Issue 2: Auto-Scroll Did Not Stop on Manual Scroll
**Problem:** Even when the user scrolled up to read previous messages, the
list kept jumping back to the bottom on every new token, making it impossible
to read earlier content during streaming.

**Fix:** Added a `ScrollDirection` listener inside `_onScrollChanged()`. When
the user drags upward (`ScrollDirection.forward`), auto-scroll is immediately
disabled and the timer is stopped. A `_isProgrammaticScroll` flag prevents
our own scroll animations from being mistaken for user input, avoiding an
infinite loop.

---

### Issue 3: Auto-Scroll Did Not Resume After Returning to Bottom
**Problem:** Once the user scrolled away, auto-scroll never re-engaged — even
after the user scrolled back to the bottom — leaving them stuck without live
updates.

**Fix:** Inside `_onScrollChanged()`, after every scroll event we check
`_isNearBottom()` (within 64px of `maxScrollExtent`). If the user has
returned to the bottom zone, auto-scroll is re-enabled and the timer
restarts automatically.

---

### Issue 4: Jumpy / Glitchy Scrolling
**Problem:** Programmatic scroll calls were triggering the user-scroll
detector, causing the auto-scroll to rapidly enable and disable itself,
producing a visible jitter effect.

**Fix:** Introduced `_isProgrammaticScroll` boolean flag. It is set to `true`
before every `animateTo()` call and reset to `false` in the `.then()` 
callback. Any scroll notification received while this flag is true is
completely ignored.

---

### Issue 5: No Final Scroll After Stream Completes
**Problem:** The last few tokens sometimes appeared below the visible area
because the periodic timer was stopped before the final layout pass completed.

**Fix:** `onStreamingEnded()` calls `_scrollToBottom()` one final time after
stopping the timer, ensuring the view always lands at the very last token.

---

### Issue 6: Auto-Scroll Not Re-Enabled for New Messages
**Problem:** If the user scrolled away during one response, auto-scroll stayed
disabled for all future messages in the same session.

**Fix:** `onStreamingStarted()` unconditionally sets `_autoScrollEnabled = true`
at the beginning of every new stream, so each new message always starts
with auto-scroll active regardless of what happened in the previous one.

---

## Architecture

The solution is separated into a single focused class:

**`ChatAutoScrollController`** — handles all scroll logic:
- Listens to `ScrollController` events
- Manages `_autoScrollEnabled` state
- Runs a periodic timer during streaming
- Exposes a clean public API: `onStreamingStarted()`, `onContentChanged()`,
  `onStreamingEnded()`, `dispose()`

`GeminiChatScreen` only calls these four methods at the right moments —
zero scroll logic lives in the UI layer.

---

## Screen Recording

> Add your screen recording link or GIF here showing:
> 1. Auto-scroll engaging during streaming
> 2. Scroll-away pausing auto-scroll
> 3. Return to bottom resuming auto-scroll
