// Vowrite i18n — shared translations for all pages
// Supports: en (default), zh, de

const i18n = {
  zh: {
    // Nav
    'nav.features': '功能',
    'nav.how': '工作原理',
    'nav.why': '为什么选 Vowrite',
    'nav.download': '下载',

    // Hero
    'hero.badge': '开源 · 免费 · macOS 14+',
    'hero.title': '说一次，完美呈现。',
    'hero.sub': 'Mac 上的 AI 语音输入。自然说话，即刻获得干净文字。',
    'hero.dl': '下载 Mac 版',
    'hero.github': '在 GitHub 查看',

    // Flow
    'flow.speak': '说话',
    'flow.clean': '润色',
    'flow.done': '完成',

    // Features
    'feat.title': '你的输入管家',
    'feat.sub': '你来说，Vowrite 搞定一切。',
    'feat.clean.t': '智能润色',
    'feat.clean.d': '去掉口头禅，修正语法，添加标点。你的想法，完美传达。',
    'feat.works.t': '随处可用',
    'feat.works.d': '文字直接出现在光标处——任何应用、任何文本框。能打字的地方，就能用 Vowrite。',
    'feat.choice.t': '自选 AI 服务',
    'feat.choice.d': '使用你自己的 API 密钥，从 6 家服务商中选择，或接入自定义端点。无订阅，不锁定。',
    'feat.fast.t': '极速响应',
    'feat.fast.d': '说完话，约 2 秒内就出现润色好的文字。比打字还快。',

    // How it works
    'how.title': '三步完成，只需两秒。',
    'how.sub': '从想法到精致文字，瞬间完成。',
    'how.s1.t': '说话',
    'how.s1.d': '按下',
    'how.s1.d2': '开始说话。说多少都行。',
    'how.s2.t': '润色',
    'how.s2.d': 'AI 转录并润色。口头禅消失，标点自动出现。',
    'how.s3.t': '完成',
    'how.s3.d': '干净文字插入到光标处。无需粘贴，无需切换应用。继续工作。',

    // Providers
    'prov.title': '你的 AI，你做主',
    'prov.sub': '使用你自己的 API 密钥。内置六家服务商，也可自定义。',
    'prov.rec': '推荐',
    'prov.fast': '超快',
    'prov.budget': '经济实惠',
    'prov.multi': '多模型',
    'prov.oss': '开源模型',
    'prov.custom': '自定义',
    'prov.customd': '任何 OpenAI 兼容端点',
    'prov.yours': '你的服务器',

    // Comparison
    'cmp.title': '为什么选择 Vowrite',
    'cmp.sub': '看看对比就知道了。',
    'cmp.mac': 'macOS 听写',
    'cmp.r1': 'AI 文本润色',
    'cmp.r2': '多 AI 服务商',
    'cmp.r3': '中英混合输入',
    'cmp.r4': '开源',
    'cmp.r5': '自带 API 密钥免费用',
    'cmp.r6': '自带 API 密钥',
    'cmp.r7': '听写历史',
    'cmp.r8': '自定义快捷键',
    'cmp.r9': '隐私（仅本地存储）',
    'cmp.limited': '有限',
    'cmp.apple': '✓（仅 Apple）',
    'cmp.fixed': '固定',

    // FAQ
    'faq.title': '常见问题',
    'faq.q1': 'Vowrite 如何把语音变成干净文字？',
    'faq.a1': 'Vowrite 使用 AI 语音识别转录你的声音，然后用 AI 语言模型去掉口头禅、修正语法、添加标点。结果是润色好的文字直接插入到光标处——约 2 秒搞定。',
    'faq.q2': 'Vowrite 免费吗？',
    'faq.a2': '是的。Vowrite 是开源免费的。你使用来自 OpenAI、Groq 或 DeepSeek 等服务商的 API 密钥，只需支付实际的 API 用量——通常每次听写只花几分钱。',
    'faq.q3': '它能在 Mac 上的任何应用中使用吗？',
    'faq.a3': '能。Vowrite 在任何应用的光标处插入文字——Safari、VS Code、Discord、Pages、Notion、微信等等。能打字的地方，就能用 Vowrite。',
    'faq.q4': '可以中英文混合说吗？',
    'faq.a4': '当然可以。Vowrite 自然处理中英混合输入。无需切换语言——像平时一样说话就行。',
    'faq.q5': '支持哪些 AI 服务商？',
    'faq.a5': 'Vowrite 支持 OpenAI、Groq、DeepSeek、OpenRouter、Together AI 以及任何 OpenAI 兼容的自定义端点。使用你自己的 API 密钥——无订阅，不锁定。',
    'faq.q6': '我的数据安全吗？',
    'faq.a6': '你的听写历史仅存储在本地 Mac 上。音频只发送给你选择的 AI 服务商进行转录——Vowrite 本身不会存储或传输你的数据到任何服务器。',

    // Providers (new)
    'prov.allone': '一站式',
    'prov.ollamad': '本地模型 · 完全离线',
    'prov.local': '100% 本地',

    // Coming soon
    'soon.title': '即将推出',
    'soon.s1t': '语音搜索',
    'soon.s1d': '用语音提问，无需离开当前应用即可获得答案。',
    'soon.s2t': '自动更新',
    'soon.s2d': '通过 Sparkle 无缝更新，始终保持最新版本。',

    // Download
    'dl.title': '准备好告别打字了吗？',
    'dl.btn': '下载 Mac 版',
    'dl.r1': '🔑 API 密钥（OpenAI 或其他）',
    'dl.r2': '🎤 麦克风权限',
    'dl.r3': '♿ 辅助功能（可选）',
    'dl.build': '或从源码构建：',
    'dl.src': '在 GitHub 查看源码',

    // Why page
    'why.hero': '为什么选择 Vowrite',
    'why.q.h': '你为什么不用最快的方式输入？',
    'why.q.b': '每天你有无数想法要传达：邮件、消息、笔记、文档。但你选择了最慢的方式——一个字一个字地敲。',
    'why.t.h': '你真正需要的，只是把想法送出去。',
    'why.t.b1': '输入方式应该跟得上你的大脑，而不是拖慢它。当你脑子里已经有了完整的一段话，为什么还要花一分钟把它敲出来？',
    'why.t.b2': '你的嘴比你的手指快得多。一个想法从产生到说出口，几乎没有延迟。说话是人类最自然、最高效的输出方式——但过去的语音输入太粗糙：识别不准、满屏废话、格式混乱。',
    'why.s.h': '不是语音不好用，是工具不够好。',
    'why.s.h2': '现在，工具跟上了。',
    'why.s.demo': '你说「嗯那个就是明天下午三点开个会讨论一下」，屏幕上出现的是：',
    'why.s.result': '明天下午三点开会。',
    'why.s.note': '不是记录你说了什么，而是还原你想说什么。干净、准确、一步到位。',
    'why.v.t': '我们的愿景',
    'why.v.b': '我们相信输入应该是无感的。你不应该思考"如何"输入——你只需思考、说话，你的想法就会完全按你的意思到达。Vowrite 是你的大脑和屏幕之间的桥梁。',
    'why.a.t': '我们的野心',
    'why.a.b': '今天，Vowrite 是一个智能语音键盘。明天，它将成为你的输入层——根据任何语境调整你的文字，连接任何工作流，在各种意义上说你的语言。语音只是开始。',
    'why.g.t': '我们的目标',
    'why.g.b': '让每个人的输入都毫不费力。无需学习。无需配置头疼。只需说话，你的想法就会到达——干净、精确、独属于你。',
    'why.c.h': '最好的输入方式，就是最自然的那种。',
    'why.c.dl': '下载 Mac 版',
  },
  de: {
    // Nav
    'nav.features': 'Funktionen',
    'nav.how': 'So funktioniert\'s',
    'nav.why': 'Warum Vowrite',
    'nav.download': 'Download',

    // Hero
    'hero.badge': 'Open Source \u00b7 Kostenlos \u00b7 macOS 14+',
    'hero.title': 'Einmal sagen. Perfekt gemeint.',
    'hero.sub': 'KI-gest\u00fctzte Spracheingabe f\u00fcr Mac. Nat\u00fcrlich sprechen, sofort sauberen Text erhalten.',
    'hero.dl': 'F\u00fcr Mac laden',
    'hero.github': 'Auf GitHub ansehen',

    // Flow
    'flow.speak': 'Sprechen',
    'flow.clean': 'Bereinigen',
    'flow.done': 'Fertig',

    // Features
    'feat.title': 'Dein Eingabe-Butler',
    'feat.sub': 'Du sprichst. Vowrite erledigt den Rest.',
    'feat.clean.t': 'Intelligente Bereinigung',
    'feat.clean.d': 'F\u00fcllw\u00f6rter weg, Grammatik korrigiert, Satzzeichen erg\u00e4nzt. Deine Ideen, perfekt \u00fcbermittelt.',
    'feat.works.t': 'Funktioniert \u00fcberall',
    'feat.works.d': 'Text erscheint direkt an deinem Cursor \u2014 jede App, jedes Textfeld. Wo du tippen kannst, funktioniert Vowrite.',
    'feat.choice.t': 'Deine KI, deine Wahl',
    'feat.choice.d': 'Bring deinen eigenen API-Schl\u00fcssel. W\u00e4hle aus 6 Anbietern oder nutze deinen eigenen. Kein Abo, kein Lock-in.',
    'feat.fast.t': 'Blitzschnell',
    'feat.fast.d': 'Sprich, und in ca. 2 Sekunden erscheint polierter Text. Schneller als Tippen.',

    // How it works
    'how.title': 'Drei Schritte. Zwei Sekunden.',
    'how.sub': 'Vom Gedanken zum perfekten Text, sofort.',
    'how.s1.t': 'Sprechen',
    'how.s1.d': 'Dr\u00fccke',
    'how.s1.d2': 'und sprich. Sag so viel du willst.',
    'how.s2.t': 'Bereinigen',
    'how.s2.d': 'KI transkribiert und poliert. F\u00fcllw\u00f6rter verschwinden, Satzzeichen erscheinen.',
    'how.s3.t': 'Fertig',
    'how.s3.d': 'Sauberer Text am Cursor eingef\u00fcgt. Kein Einf\u00fcgen, kein App-Wechsel. Weiterarbeiten.',

    // Providers
    'prov.title': 'Deine KI, deine Regeln',
    'prov.sub': 'Bring deinen eigenen API-Schl\u00fcssel. Sechs Anbieter integriert, oder nutze deinen eigenen.',
    'prov.rec': 'Empfohlen',
    'prov.fast': 'Ultraschnell',
    'prov.budget': 'G\u00fcnstig',
    'prov.multi': 'Multi-Modell',
    'prov.oss': 'Open-Source-Modelle',
    'prov.custom': 'Benutzerdefiniert',
    'prov.customd': 'Jeder OpenAI-kompatible Endpunkt',
    'prov.yours': 'Dein Server',

    // Comparison
    'cmp.title': 'Warum Vowrite',
    'cmp.sub': 'Vergleiche selbst.',
    'cmp.mac': 'macOS Diktat',
    'cmp.r1': 'KI-Textbereinigung',
    'cmp.r2': 'Mehrere KI-Anbieter',
    'cmp.r3': 'Chinesisch + Englisch gemischt',
    'cmp.r4': 'Open Source',
    'cmp.r5': 'Kostenlos mit eigenem API-Schl\u00fcssel',
    'cmp.r6': 'Eigener API-Schl\u00fcssel',
    'cmp.r7': 'Diktatverlauf',
    'cmp.r8': 'Eigene Tastenkombination',
    'cmp.r9': 'Datenschutz (nur lokale Speicherung)',
    'cmp.limited': 'Begrenzt',
    'cmp.apple': '\u2713 (nur Apple)',
    'cmp.fixed': 'Fest',

    // FAQ
    'faq.title': 'H\u00e4ufig gestellte Fragen',
    'faq.q1': 'Wie verwandelt Vowrite meine Stimme in sauberen Text?',
    'faq.a1': 'Vowrite nutzt KI-Spracherkennung zum Transkribieren, dann entfernt ein KI-Sprachmodell F\u00fcllw\u00f6rter, korrigiert Grammatik und erg\u00e4nzt Satzzeichen. Das Ergebnis ist polierter Text direkt am Cursor \u2014 in ca. 2 Sekunden.',
    'faq.q2': 'Ist Vowrite kostenlos?',
    'faq.a2': 'Ja. Vowrite ist Open Source und kostenlos. Du bringst deinen eigenen API-Schl\u00fcssel von Anbietern wie OpenAI, Groq oder DeepSeek. Du zahlst nur f\u00fcr die tats\u00e4chliche API-Nutzung \u2014 typischerweise Bruchteile eines Cents pro Diktat.',
    'faq.q3': 'Funktioniert es in jeder App auf dem Mac?',
    'faq.a3': 'Ja. Vowrite f\u00fcgt Text am Cursor in jeder App ein \u2014 Safari, VS Code, Discord, Pages, Notion, WeChat und mehr. Wo du tippen kannst, funktioniert Vowrite.',
    'faq.q4': 'Kann ich Chinesisch und Englisch in einem Satz mischen?',
    'faq.a4': 'Absolut. Vowrite verarbeitet gemischtes Chinesisch und Englisch nat\u00fcrlich. Kein Sprachwechsel n\u00f6tig \u2014 sprich einfach wie gewohnt.',
    'faq.q5': 'Welche KI-Anbieter werden unterst\u00fctzt?',
    'faq.a5': 'Vowrite unterst\u00fctzt OpenAI, Groq, DeepSeek, OpenRouter, Together AI und jeden OpenAI-kompatiblen benutzerdefinierten Endpunkt. Bring deinen eigenen API-Schl\u00fcssel \u2014 kein Abo, kein Lock-in.',
    'faq.q6': 'Sind meine Daten privat?',
    'faq.a6': 'Dein Diktatverlauf wird lokal auf deinem Mac gespeichert. Audio wird nur zum Transkribieren an deinen gew\u00e4hlten KI-Anbieter gesendet \u2014 Vowrite selbst speichert oder \u00fcbertr\u00e4gt deine Daten niemals an einen Server.',

    // Providers (new)
    'prov.allone': 'All-in-One',
    'prov.ollamad': 'Lokale Modelle \u00b7 komplett offline',
    'prov.local': '100% Lokal',

    // Coming soon
    'soon.title': 'Demn\u00e4chst',
    'soon.s1t': 'Sprachgesteuerte Suche',
    'soon.s1d': 'Stelle Fragen per Sprache und erhalte sofort Antworten, ohne die App zu verlassen.',
    'soon.s2t': 'Auto-Update',
    'soon.s2d': 'Immer aktuell mit nahtlosen In-App-Updates \u00fcber Sparkle.',

    // Download
    'dl.title': 'Bereit, das Tippen sein zu lassen?',
    'dl.btn': 'F\u00fcr Mac laden',
    'dl.r1': '\ud83d\udd11 API-Schl\u00fcssel (OpenAI oder andere)',
    'dl.r2': '\ud83c\udf99\ufe0f Mikrofonberechtigung',
    'dl.r3': '\u267f Bedienungshilfen (optional)',
    'dl.build': 'Oder aus dem Quellcode bauen:',
    'dl.src': 'Quellcode auf GitHub ansehen',

    // Why page
    'why.hero': 'Warum Vowrite',
    'why.q.h': 'Warum nicht die schnellste Art der Eingabe nutzen?',
    'why.q.b': 'Jeden Tag hast du unz\u00e4hlige Ideen zu vermitteln: E-Mails, Nachrichten, Notizen, Dokumente. Aber du w\u00e4hlst den langsamsten Weg \u2014 Zeichen f\u00fcr Zeichen tippen.',
    'why.t.h': 'Alles was du wirklich brauchst, ist deine Ideen rauszubekommen.',
    'why.t.b1': 'Deine Eingabemethode sollte mit deinem Gehirn mithalten, nicht es bremsen. Wenn du bereits einen vollst\u00e4ndigen Gedanken hast, warum eine Minute damit verbringen, ihn einzutippen?',
    'why.t.b2': 'Dein Mund ist viel schneller als deine Finger. Vom Gedanken zum Sprechen gibt es fast keine Verz\u00f6gerung. Sprechen ist die nat\u00fcrlichste, effizienteste Form menschlicher Ausgabe \u2014 aber bisherige Spracheingabe war zu roh: ungenaue Erkennung, \u00fcberall F\u00fcllw\u00f6rter, chaotische Formatierung.',
    'why.s.h': 'Nicht die Spracheingabe war schlecht \u2014 die Werkzeuge waren nicht gut genug.',
    'why.s.h2': 'Jetzt haben die Werkzeuge aufgeholt.',
    'why.s.demo': 'Du sagst \'\u00e4hm also lass uns morgen um 15 Uhr ein Meeting machen um zu besprechen\' und auf dem Bildschirm erscheint:',
    'why.s.result': 'Meeting morgen um 15 Uhr.',
    'why.s.note': 'Es zeichnet nicht auf, was du gesagt hast \u2014 es erfasst, was du gemeint hast. Sauber, pr\u00e4zise, in einem Schritt erledigt.',
    'why.v.t': 'Unsere Vision',
    'why.v.b': 'Wir glauben, Eingabe sollte unsichtbar sein. Du solltest nicht dar\u00fcber nachdenken, wie du eingibst \u2014 du solltest einfach denken, sprechen, und deine Ideen kommen genau so an, wie du sie meinst. Vowrite ist die Br\u00fccke zwischen deinem Kopf und dem Bildschirm.',
    'why.a.t': 'Unser Anspruch',
    'why.a.b': 'Heute ist Vowrite eine intelligente Sprachtastatur. Morgen ist es deine Eingabeschicht \u2014 passt deine Worte an jeden Kontext an, verbindet sich mit jedem Workflow, spricht deine Sprache in jeder Hinsicht. Sprache ist nur der Anfang.',
    'why.g.t': 'Unser Ziel',
    'why.g.b': 'Eingabe f\u00fcr jeden m\u00fchelos machen. Keine Lernkurve. Keine Konfigurationsprobleme. Einfach sprechen, und deine Ideen kommen an \u2014 sauber, pr\u00e4zise und unverkennbar deine.',
    'why.c.h': 'Die beste Eingabe ist die nat\u00fcrlichste.',
    'why.c.dl': 'F\u00fcr Mac laden',
  }
};

// Store default English text on load
const enDefaults = {};
document.querySelectorAll('[data-i18n]').forEach(el => {
  enDefaults[el.getAttribute('data-i18n')] = el.textContent;
});

function setLang(lang) {
  localStorage.setItem('vowrite-lang', lang);
  document.documentElement.lang = lang === 'zh' ? 'zh-CN' : lang === 'de' ? 'de' : 'en';
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (lang === 'en') {
      el.textContent = enDefaults[key] || el.textContent;
    } else if (i18n[lang] && i18n[lang][key]) {
      el.textContent = i18n[lang][key];
    }
  });
  // Update dropdown
  const langNames = { en: 'EN', zh: '中文', de: 'DE' };
  document.querySelectorAll('.lang-current').forEach(el => el.textContent = langNames[lang] || 'EN');
  document.querySelectorAll('.lang-menu li').forEach(li => {
    li.classList.toggle('active', li.getAttribute('data-lang') === lang);
  });
  document.querySelectorAll('.lang-dropdown').forEach(d => d.classList.remove('open'));
}

// Dropdown toggle & selection
document.addEventListener('click', (e) => {
  const toggle = e.target.closest('.lang-toggle');
  if (toggle) {
    const dd = toggle.closest('.lang-dropdown');
    dd.classList.toggle('open');
    toggle.setAttribute('aria-expanded', dd.classList.contains('open'));
    e.stopPropagation();
    return;
  }
  const li = e.target.closest('.lang-menu li');
  if (li) {
    setLang(li.getAttribute('data-lang'));
    return;
  }
  document.querySelectorAll('.lang-dropdown').forEach(d => {
    d.classList.remove('open');
    d.querySelector('.lang-toggle')?.setAttribute('aria-expanded', 'false');
  });
});

// Scroll fade-in observer
const observer = new IntersectionObserver((entries) => {
  entries.forEach(e => {
    if (e.isIntersecting) {
      e.target.classList.add('visible');
      observer.unobserve(e.target);
    }
  });
}, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });
document.querySelectorAll('.fade-in').forEach(el => observer.observe(el));

// Load saved language preference
const savedLang = localStorage.getItem('vowrite-lang');
if (savedLang && savedLang !== 'en') { setLang(savedLang); }
