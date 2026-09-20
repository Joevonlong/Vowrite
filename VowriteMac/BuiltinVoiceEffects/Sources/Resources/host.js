(() => {
  'use strict';
  const token = new URLSearchParams(location.search).get('token') || '';
  const canvas = document.getElementById('effect');
  let state = { id: 1, revision: 0, time: 0, phase: 'listening', level: 0.65, reducedMotion: false, theme: 'dark', shape: 'wide' };
  let receivedAt = performance.now();
  let animationFrame = 0;
  let frameCount = 0;
  let pendingAcknowledgement = false;
  let lastAnimationTime = 0;

  const bridge = message => {
    const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.builtinVoiceEffect;
    if (handler && typeof handler.postMessage === 'function') handler.postMessage(Object.assign({ token }, message));
  };

  function resize() {
    const scale = Math.min(2, Math.max(1, window.devicePixelRatio || 1));
    const width = Math.max(1, Math.round(canvas.clientWidth * scale));
    const height = Math.max(1, Math.round(canvas.clientHeight * scale));
    if (canvas.width !== width || canvas.height !== height) { canvas.width = width; canvas.height = height; }
  }

  function draw(now) {
    resize();
    canvas.dataset.shape = state.shape === 'compact' ? 'compact' : 'wide';
    const elapsed = state.reducedMotion ? 0 : Math.max(0, (now - receivedAt) / 1000);
    const drawTime = state.reducedMotion ? 0 : state.time + elapsed;
    window.VoiceAtlasArt.draw(canvas, state.id, drawTime, state.phase, state.theme, 0, state.level, 1, '');
    frameCount += 1;
    if (pendingAcknowledgement) {
      pendingAcknowledgement = false;
      bridge({ type: 'frame', id: state.id, revision: state.revision, frameCount, level: state.level, phase: state.phase });
    }
  }

  function tick(now) {
    animationFrame = 0;
    if (now - lastAnimationTime < 33) { animationFrame = requestAnimationFrame(tick); return; }
    lastAnimationTime = now;
    try { draw(now); }
    catch (error) { bridge({ type: 'error', message: String(error && error.message || error) }); return; }
    if (!state.reducedMotion && (state.phase === 'listening' || state.phase === 'processing')) {
      animationFrame = requestAnimationFrame(tick);
    }
  }

  function restart() {
    if (animationFrame) cancelAnimationFrame(animationFrame);
    animationFrame = 0;
    const now = performance.now();
    lastAnimationTime = now;
    try { draw(now); }
    catch (error) { bridge({ type: 'error', message: String(error && error.message || error) }); return false; }
    if (!state.reducedMotion && (state.phase === 'listening' || state.phase === 'processing')) {
      animationFrame = requestAnimationFrame(tick);
    }
    return true;
  }

  window.VowriteBuiltinEffects = Object.freeze({
    setState(next) {
      const id = Number(next && next.id);
      if (!Number.isInteger(id) || id < 1 || id > 80) throw new RangeError('Built-in effect id must be 1 through 80.');
      state = {
        id,
        revision: Number.isInteger(next.revision) ? next.revision : 0,
        time: Math.max(0, Number(next.time) || 0),
        phase: ['idle', 'listening', 'processing', 'done', 'error'].includes(next.phase) ? next.phase : 'idle',
        level: Math.max(0, Math.min(1, Number(next.level) || 0)),
        reducedMotion: Boolean(next.reducedMotion),
        theme: next.theme === 'light' ? 'light' : 'dark',
        shape: next.shape === 'compact' ? 'compact' : 'wide'
      };
      receivedAt = performance.now();
      pendingAcknowledgement = true;
      return restart();
    }
  });

  window.addEventListener('resize', restart);
  bridge({ type: 'ready' });
})();
