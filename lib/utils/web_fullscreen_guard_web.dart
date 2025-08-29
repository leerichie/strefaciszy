import 'package:web/web.dart' as web;
import 'dart:js_interop';

web.EventListener? _keyListenerDoc;
web.EventListener? _keyListenerWin;
web.EventListener? _fsListenerDoc;
web.EventListener? _fsListenerWin;

void initFullscreenGuard() {
  // If already in fullscreen, exit.
  try {
    if (web.document.fullscreenElement != null) {
      web.document.exitFullscreen();
    }
  } catch (_) {}

  // Block F11/F12 and common DevTools shortcuts (Ctrl+Shift+I/J/C, ⌘+⌥+I/J/C).
  final keyBlocker = ((web.Event e) {
    if (e is web.KeyboardEvent) {
      final key = (e.key ?? '').toLowerCase();
      final code = e.keyCode;
      final ctrl = e.ctrlKey ?? false;
      final shift = e.shiftKey ?? false;
      final meta = e.metaKey ?? false; // Cmd on macOS
      final alt = e.altKey ?? false;

      bool block = false;

      // F11 (fullscreen) / F12 (DevTools)
      if (key == 'f11' || code == 122 || key == 'f12' || code == 123) {
        block = true;
      }

      // DevTools shortcuts
      if ((ctrl && shift && (key == 'i' || key == 'j' || key == 'c')) ||
          (meta && alt && (key == 'i' || key == 'j' || key == 'c'))) {
        block = true;
      }

      if (block) {
        e.preventDefault();
        // Stop ALL handlers (capture + bubble)
        e.stopImmediatePropagation();
        e.stopPropagation();
      }
    }
  }).toJS;

  // Capture phase so we intercept before anything else.
  _keyListenerDoc = keyBlocker;
  web.document.addEventListener('keydown', _keyListenerDoc!, true.toJS);

  _keyListenerWin = keyBlocker;
  web.window.addEventListener('keydown', _keyListenerWin!, true.toJS);

  // If something forces fullscreen anyway, immediately exit.
  final fsHandler = ((web.Event _) {
    try {
      if (web.document.fullscreenElement != null) {
        web.document.exitFullscreen();
      }
    } catch (_) {}
  }).toJS;

  _fsListenerDoc = fsHandler;
  web.document.addEventListener('fullscreenchange', _fsListenerDoc!);

  _fsListenerWin = fsHandler;
  web.window.addEventListener('fullscreenchange', _fsListenerWin!);
}

void disposeFullscreenGuard() {
  if (_keyListenerDoc != null) {
    web.document.removeEventListener('keydown', _keyListenerDoc!, true.toJS);
    _keyListenerDoc = null;
  }
  if (_keyListenerWin != null) {
    web.window.removeEventListener('keydown', _keyListenerWin!, true.toJS);
    _keyListenerWin = null;
  }
  if (_fsListenerDoc != null) {
    web.document.removeEventListener('fullscreenchange', _fsListenerDoc!);
    _fsListenerDoc = null;
  }
  if (_fsListenerWin != null) {
    web.window.removeEventListener('fullscreenchange', _fsListenerWin!);
    _fsListenerWin = null;
  }
}
