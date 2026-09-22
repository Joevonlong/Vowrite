/* Progressive enhancements shared by all public website routes. */
(() => {
  'use strict';
  const language = () => document.documentElement.lang.startsWith('zh') ? 'zh' : document.documentElement.lang.startsWith('de') ? 'de' : 'en';
  const copy = key => i18n[language()][key] || i18n.en[key];
  document.querySelectorAll('pre, .download-note').forEach(block => {
    const code = block.querySelector('code');
    if (!code) return;
    const button = document.createElement('button');
    button.type = 'button'; button.className = 'site-copy'; button.dataset.i18n = 'site.copy'; button.textContent = copy('site.copy');
    const feedback = document.createElement('span'); feedback.className = 'site-copy-feedback'; feedback.setAttribute('role', 'status');
    block.append(button, feedback);
    button.addEventListener('click', async () => {
      try { await navigator.clipboard.writeText(code.textContent); feedback.textContent = copy('site.copied'); }
      catch {
        feedback.textContent = copy('site.copyFailed');
        const selection = window.getSelection(), range = document.createRange(); range.selectNodeContents(code); selection.removeAllRanges(); selection.addRange(range);
        code.tabIndex = -1; code.focus({preventScroll: true});
      }
    });
  });
  // Content remains visible when JS, IntersectionObserver or animation is unavailable.
  document.querySelectorAll('.fade-in').forEach(el => el.classList.add('visible'));
  const titles = {
    en: {index:'Vowrite — AI voice input for Mac',why:'Why Vowrite — Your voice, clearly expressed',apps:'Vowrite — macOS and iOS installation',translate:'Vowrite — Voice translation',pricing:'Vowrite — Usage and provider costs'},
    zh: {index:'Vowrite — Mac AI 语音输入',why:'为什么选择 Vowrite',apps:'Vowrite — macOS 与 iOS 安装指南',translate:'Vowrite — 语音翻译',pricing:'Vowrite — 用量与服务商费用'},
    de: {index:'Vowrite — KI-Spracheingabe für Mac',why:'Warum Vowrite',apps:'Vowrite — Installation für macOS und iOS',translate:'Vowrite — Sprachübersetzung',pricing:'Vowrite — Nutzung und Anbieterkosten'}
  };
  function localize() {
    const name = location.pathname.split('/').pop().replace(/\.html$/, '') || 'index';
    if (titles[language()][name]) document.title = titles[language()][name];
    document.querySelectorAll('.site-copy').forEach(el => el.textContent = copy('site.copy'));
  }
  document.addEventListener('vowrite-language-change', localize); localize();
})();
