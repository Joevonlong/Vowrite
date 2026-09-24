/* Usage v4. Page-local examples only: no credentials, API calls or app-setting changes.
   Production corrections: recognition runs through a cloud provider (bundled Sherpa is
   unavailable); local models cover the refinement step only. */
(() => {
  'use strict';
  const page = document.querySelector('.usage-page');
  if (!page) return;
  const words = {
  "en": {
    "eyebrow": "USAGE, ON YOUR TERMS",
    "heroFree": "Free app.",
    "heroUsage": "Pay only for what you use.",
    "heroIntro": "Choose who turns your speech into text, and who refines it. Use cloud services, local models, or both.",
    "promiseSubscription": "No Vowrite subscription",
    "promiseChoice": "Switch providers independently",
    "promiseLocal": "Cloud or local refinement",
    "estimateLink": "Get Vowrite free",
    "providersLink": "Explore providers",
    "groqOption": "Groq · Whisper Turbo",
    "openaiOption": "OpenAI · Mini transcribe",
    "deepgramOption": "Deepgram · Nova-3",
    "off": "Off",
    "local": "Local",
    "cloud": "Cloud API",
    "providerEyebrow": "YOUR PROVIDERS",
    "providerTitle": "Two steps. Your choice.",
    "providerIntro": "Recognition and refinement are independent. Switch either provider, refine with a local model, or skip refinement.",
    "speechStep": "Speech to text",
    "speechStepDesc": "The recognition step.",
    "polishStep": "Text refinement",
    "polishStepDesc": "Optional: tidy or rephrase your words.",
    "speechProviderLabel": "Recognition provider",
    "polishProviderLabel": "Refinement provider",
    "polishOffOption": "Skip refinement",
    "tokenBilling": "Billed for text processed (tokens).",
    "comboLabel": "This combination",
    "setupLink": "macOS setup guide",
    "demoNote": "This example changes only this page. Configure your real providers in the app.",
    "billingEyebrow": "GET STARTED",
    "billingTitle": "From download to your first words.",
    "billingIntro": "Choose a starting setup. Change providers whenever your needs change.",
    "billing1Title": "Download the app",
    "billing1Body": "Get Vowrite and follow the installation steps for your platform.",
    "billing2Title": "Set up your providers",
    "billing2Body": "Add your API keys on the app’s API Keys page, or set up a supported local model for refinement. Refinement is optional.",
    "billing3Title": "Speak, then insert",
    "billing3Body": "Use your voice shortcut, speak, and insert the text into the app you are using.",
    "principleTitle": "What determines cloud costs?",
    "faqEyebrow": "GOOD TO KNOW",
    "faqTitle": "Clear costs. Clear choices.",
    "faq1": "Who am I paying?",
    "faq1Body": "Vowrite is free and open source. Cloud API charges go directly to your chosen providers. Their rates, minimum charges and credit terms apply.",
    "faq2": "Can I change providers later?",
    "faq2Body": "Yes. Choose a supported provider in the app and configure its API key or local model. Recognition and refinement can use different providers.",
    "faq3": "How are recognition and refinement billed?",
    "faq3Body": "Cloud recognition is billed for audio; refinement is billed for input and output text tokens. Exact rules depend on the provider. You can skip refinement.",
    "faq4": "When does local processing avoid cloud fees?",
    "faq4Body": "A locally processed step makes no cloud API call and incurs no cloud API fee. Local models currently cover text refinement (Ollama or MLX Server on Mac); speech recognition still uses a cloud provider. Local models need compatible hardware and setup; your device and electricity are separate costs.",
    "faq5": "What if I only use it occasionally?",
    "faq5Body": "Vowrite has no monthly subscription to maintain. Cloud charges follow your actual billable usage, subject to your provider’s minimums and terms.",
    "officialTitle": "See current provider rates.",
    "officialIntro": "Current terms always come from the provider.",
    "archiveSubtitle": "Preserved tables and examples; not current offers",
    "archiveScroll": "Tables scroll horizontally to keep every column available.",
    "legacyLinks": "Original reference links",
    "closeTitle": "Start with your voice.",
    "closeIntro": "Download Vowrite. Choose your providers. Make it yours.",
    "download": "Download Vowrite",
    "closeNote": "Free app · Cloud API usage billed separately",
    "footerChecked": "Historical pricing reference: July 2026 · Check providers for current rates",
    "polishLocal": "Ollama refines text locally; no cloud API fee for this step.",
    "polishNone": "No refinement call. Keep the recognized text.",
    "valueApp": "VOWRITE",
    "valueFree": "Free & open source",
    "valueNoAbo": "No Vowrite subscription to keep running.",
    "valueTitle": "Billed by usage",
    "valueBody": "Paid directly to the providers you choose.",
    "valueHint": "Local processing has no cloud API fee for that step.",
    "speechBillingCloud": "Audio usage billed by your provider.",
    "valueHeading": "A simple split: the app and your AI usage",
    "valueCloud": "CLOUD AI",
    "exampleLegend": "Try an example, then make it yours",
    "exampleDictation": "Dictation only",
    "exampleCloud": "Cloud writing",
    "exampleLocal": "Local refinement",
    "nojs": "Enable JavaScript to try provider combinations. The example and setup guide remain available below.",
    "principleBody": "Your usage and the model’s rates determine the bill. A different supported model can change the cost. Check its quality, availability and billing terms before switching.",
    "archiveEstimateTitle": "Archived monthly examples · July 2026",
    "archiveEstimateNote": "Old assumptions, not a forecast for your usage. Prices, model availability and free-tier claims below have not been reverified for today."
  },
  "zh": {
    "eyebrow": "用量与费用，由你掌握",
    "heroFree": "应用免费。",
    "heroUsage": "用多少，付多少。",
    "heroIntro": "谁来识别，谁来润色，由你选择。云端服务与本地模型，也能自由搭配。",
    "promiseSubscription": "无需订阅 Vowrite",
    "promiseChoice": "服务商独立切换",
    "promiseLocal": "润色可云端，也可本地",
    "estimateLink": "免费下载 Vowrite",
    "providersLink": "看看自由组合",
    "groqOption": "Groq · Whisper Turbo",
    "openaiOption": "OpenAI · Mini transcribe",
    "deepgramOption": "Deepgram · Nova-3",
    "off": "已关闭",
    "local": "本地运行",
    "cloud": "云端 API",
    "providerEyebrow": "服务商自由选",
    "providerTitle": "识别与润色，分别选。",
    "providerIntro": "两步互相独立。可以更换任一服务商、用本地模型润色，也可以关闭润色。",
    "speechStep": "语音识别",
    "speechStepDesc": "把说出的话变成文字。",
    "polishStep": "文字润色",
    "polishStepDesc": "可选步骤：整理或改写表达。",
    "speechProviderLabel": "识别服务商",
    "polishProviderLabel": "润色服务商",
    "polishOffOption": "关闭润色",
    "tokenBilling": "按处理的文本计费（Token）。",
    "comboLabel": "当前示例组合",
    "setupLink": "查看 macOS 配置步骤",
    "demoNote": "组合示意，仅影响本页；实际服务商请在应用内配置。",
    "billingEyebrow": "开始使用",
    "billingTitle": "下载之后，说出第一句话。",
    "billingIntro": "先用一套合适的组合开始，需求变化时再调整。",
    "billing1Title": "下载应用",
    "billing1Body": "获取 Vowrite，按对应平台的步骤完成安装。",
    "billing2Title": "配置服务商",
    "billing2Body": "在应用的「API Keys」页面添加 API Key，或为润色配置受支持的本地模型。润色可以先关闭。",
    "billing3Title": "说话并插入文字",
    "billing3Body": "使用语音快捷键开始输入，说完后将文字插入当前使用的应用。",
    "principleTitle": "云端费用由什么决定？",
    "faqEyebrow": "你可能还想了解",
    "faqTitle": "费用与选择，说清楚。",
    "faq1": "我到底在向谁付费？",
    "faq1Body": "Vowrite 免费且开源。云端 API 费用直接由所选服务商收取，适用其单价、最低计费和余额规则。",
    "faq2": "以后可以更换 Provider 吗？",
    "faq2Body": "可以。在应用内选择受支持的服务商，配置对应 API Key 或本地模型即可。识别与润色不必选同一家。",
    "faq3": "识别与润色分别怎么计费？",
    "faq3Body": "云端识别按音频计费，润色按输入与输出文本的 Token 计费，具体规则以服务商为准。不需要润色时，可以关闭。",
    "faq4": "本地处理哪些步骤不收云端费用？",
    "faq4Body": "在本地完成的步骤不调用云端 API，也不产生该步骤的云端费用。目前本地模型用于文字润色（Mac 上的 Ollama 或 MLX Server），语音识别仍需云端服务商。本地模型需要兼容的设备与配置，设备和用电成本另计。",
    "faq5": "只是偶尔用一下，也适合吗？",
    "faq5Body": "无需为 Vowrite 维持月度订阅。云端费用随实际计费用量产生，具体最低计费和其他规则以服务商为准。",
    "officialTitle": "查现价，直接看官方。",
    "officialIntro": "最新条款以服务商公布的信息为准。",
    "archiveSubtitle": "保留原始表格与示例，不代表当前报价",
    "archiveScroll": "表格可横向滚动，所有列均完整保留。",
    "legacyLinks": "原有参考链接",
    "closeTitle": "从第一句话开始。",
    "closeIntro": "下载 Vowrite，搭配适合自己的服务商。",
    "download": "下载 Vowrite",
    "closeNote": "应用免费 · 云端 API 用量另行结算",
    "footerChecked": "历史价格参考：2026 年 7 月 · 最新单价请查看服务商",
    "polishLocal": "Ollama 在本地润色，该步骤不产生云端 API 费用。",
    "polishNone": "不调用润色服务，保留识别结果。",
    "valueApp": "VOWRITE 应用",
    "valueFree": "免费且开源",
    "valueNoAbo": "无需维持 Vowrite 订阅。",
    "valueTitle": "按实际用量结算",
    "valueBody": "费用直接付给你选择的服务商。",
    "valueHint": "本地处理的步骤，不产生云端 API 费用。",
    "speechBillingCloud": "音频用量按服务商规则计费。",
    "valueHeading": "应用与 AI 用量，费用分开看",
    "valueCloud": "云端 AI",
    "exampleLegend": "试试示例组合，再按需调整",
    "exampleDictation": "直接听写",
    "exampleCloud": "云端润色",
    "exampleLocal": "本地润色",
    "nojs": "启用 JavaScript 即可切换示例组合。下方仍可查看默认组合与配置指南。",
    "principleBody": "实际用量与模型单价共同决定费用。更换受支持的模型，成本也可能随之变化；选择时一并考虑效果、可用性和服务商的计费规则。",
    "archiveEstimateTitle": "旧版月费示例 · 2026 年 7 月",
    "archiveEstimateNote": "以下使用旧版假设，不代表你的实际用量。价格、模型可用性及免费额度表述均未重新核实为当前信息。"
  },
  "de": {
    "eyebrow": "NUTZUNG, NACH DEINEN REGELN",
    "heroFree": "Kostenlose App.",
    "heroUsage": "Zahle nur, was du nutzt.",
    "heroIntro": "Wähle, wer deine Sprache erkennt und deinen Text bearbeitet. Nutze Cloud-Dienste, lokale Modelle oder beides.",
    "promiseSubscription": "Kein Vowrite-Abo",
    "promiseChoice": "Anbieter unabhängig wechseln",
    "promiseLocal": "Textbearbeitung in der Cloud oder lokal",
    "estimateLink": "Vowrite kostenlos laden",
    "providersLink": "Anbieter kombinieren",
    "groqOption": "Groq · Whisper Turbo",
    "openaiOption": "OpenAI · Mini transcribe",
    "deepgramOption": "Deepgram · Nova-3",
    "off": "Aus",
    "local": "Lokal",
    "cloud": "Cloud-API",
    "providerEyebrow": "DEINE ANBIETER",
    "providerTitle": "Zwei Schritte. Deine Wahl.",
    "providerIntro": "Erkennung und Textbearbeitung sind unabhängig. Wechsle einzelne Anbieter, bearbeite Text mit einem lokalen Modell oder verzichte auf Textbearbeitung.",
    "speechStep": "Spracherkennung",
    "speechStepDesc": "Gesprochenes wird zu Text.",
    "polishStep": "Textbearbeitung",
    "polishStepDesc": "Optional: Text ordnen oder umformulieren.",
    "speechProviderLabel": "Anbieter für Erkennung",
    "polishProviderLabel": "Anbieter für Textbearbeitung",
    "polishOffOption": "Ohne Textbearbeitung",
    "tokenBilling": "Abrechnung nach verarbeitetem Text (Tokens).",
    "comboLabel": "Diese Kombination",
    "setupLink": "macOS-Einrichtung",
    "demoNote": "Dieses Beispiel verändert nur diese Seite. Deine echten Anbieter richtest du in der App ein.",
    "billingEyebrow": "LOSLEGEN",
    "billingTitle": "Von der Installation zum ersten Satz.",
    "billingIntro": "Starte mit einer passenden Kombination. Ändere die Anbieter, wenn sich dein Bedarf ändert.",
    "billing1Title": "App herunterladen",
    "billing1Body": "Lade Vowrite und folge den Installationsschritten für deine Plattform.",
    "billing2Title": "Anbieter einrichten",
    "billing2Body": "Hinterlege API-Schlüssel auf der Seite „API Keys“ der App oder richte ein unterstütztes lokales Modell für die Textbearbeitung ein. Textbearbeitung ist optional.",
    "billing3Title": "Sprechen und einfügen",
    "billing3Body": "Starte mit deinem Sprach-Tastenkürzel, sprich und füge den Text in die gerade verwendete App ein.",
    "principleTitle": "Wovon hängen Cloud-Kosten ab?",
    "faqEyebrow": "GUT ZU WISSEN",
    "faqTitle": "Klare Kosten. Freie Wahl.",
    "faq1": "Wen bezahle ich?",
    "faq1Body": "Vowrite ist kostenlos und Open Source. Cloud-API-Gebühren bezahlst du direkt bei deinen Anbietern. Deren Preise, Mindestgebühren und Guthabenbedingungen gelten.",
    "faq2": "Kann ich später den Anbieter wechseln?",
    "faq2Body": "Ja. Wähle in der App einen unterstützten Anbieter und richte seinen API-Schlüssel oder ein lokales Modell ein. Erkennung und Textbearbeitung dürfen verschiedene Anbieter nutzen.",
    "faq3": "Wie werden Erkennung und Textbearbeitung berechnet?",
    "faq3Body": "Cloud-Erkennung wird nach Audio abgerechnet, Textbearbeitung nach Ein- und Ausgabe-Tokens. Die genauen Regeln legt der Anbieter fest. Textbearbeitung lässt sich ausschalten.",
    "faq4": "Wann entfallen Cloud-Gebühren bei lokaler Verarbeitung?",
    "faq4Body": "Ein lokaler Schritt ruft keine Cloud-API auf und verursacht dafür keine Gebühr. Lokale Modelle übernehmen derzeit die Textbearbeitung (Ollama oder MLX Server auf dem Mac); die Spracherkennung nutzt weiterhin einen Cloud-Anbieter. Lokale Modelle benötigen passende Hardware und Einrichtung; Gerät und Strom sind separate Kosten.",
    "faq5": "Und wenn ich die App nur gelegentlich nutze?",
    "faq5Body": "Für Vowrite musst du kein monatliches Abo halten. Cloud-Kosten richten sich nach deiner tatsächlich abrechenbaren Nutzung und den Mindestgebühren und Bedingungen des Anbieters.",
    "officialTitle": "Aktuelle Anbieterpreise nachlesen.",
    "officialIntro": "Aktuelle Bedingungen kommen vom Anbieter.",
    "archiveSubtitle": "Erhaltene Tabellen und Beispiele, keine aktuellen Angebote",
    "archiveScroll": "Tabellen lassen sich horizontal scrollen; alle Spalten bleiben erhalten.",
    "legacyLinks": "Ursprüngliche Referenzlinks",
    "closeTitle": "Beginne mit deiner Stimme.",
    "closeIntro": "Lade Vowrite. Wähle deine Anbieter. Finde deinen Ablauf.",
    "download": "Vowrite laden",
    "closeNote": "Kostenlose App · Cloud-API-Nutzung wird separat berechnet",
    "footerChecked": "Historische Preisreferenz: Juli 2026 · Aktuelle Preise beim Anbieter prüfen",
    "polishLocal": "Ollama bearbeitet Text lokal; für diesen Schritt fallen keine Cloud-API-Gebühren an.",
    "polishNone": "Kein Aufruf zur Textbearbeitung. Der erkannte Wortlaut bleibt.",
    "valueApp": "VOWRITE",
    "valueFree": "Kostenlos & Open Source",
    "valueNoAbo": "Kein laufendes Vowrite-Abonnement.",
    "valueTitle": "Nach Verbrauch",
    "valueBody": "Du bezahlst deine gewählten Anbieter direkt.",
    "valueHint": "Lokal verarbeitete Schritte verursachen keine Cloud-API-Gebühren.",
    "speechBillingCloud": "Audionutzung wird vom Anbieter berechnet.",
    "valueHeading": "App und KI-Nutzung: getrennte Kosten",
    "valueCloud": "CLOUD-KI",
    "exampleLegend": "Beispiel wählen und selbst anpassen",
    "exampleDictation": "Nur Diktat",
    "exampleCloud": "Mit Cloud-KI",
    "exampleLocal": "Lokal bearbeiten",
    "nojs": "Aktiviere JavaScript, um Anbieter zu kombinieren. Das Beispiel und die Einrichtungsanleitung bleiben unten verfügbar.",
    "principleBody": "Deine Nutzung und die Modellpreise bestimmen die Rechnung. Ein anderes unterstütztes Modell kann die Kosten verändern. Berücksichtige dabei Qualität, Verfügbarkeit und Abrechnungsbedingungen.",
    "archiveEstimateTitle": "Frühere Monatsbeispiele · Juli 2026",
    "archiveEstimateNote": "Alte Annahmen, keine Prognose für deine Nutzung. Preise, Modellverfügbarkeit und Angaben zu Gratis-Kontingenten wurden nicht erneut auf Aktualität geprüft."
  }
};
  Object.assign(words.en, {
    combination:(a,b)=>`${a} → ${b}`,
    directCombination:(a)=>`${a} · Dictation only`,
    polishCloud:(p)=>`${p} bills input and output tokens separately.`,
    comboSpeechCloud:(p)=>`${p} handles recognition in the cloud.`
  });
  Object.assign(words.zh, {
    combination:(a,b)=>`${a} → ${b}`,
    directCombination:(a)=>`${a} · 直接听写`,
    polishCloud:(p)=>`${p} 按输入和输出 Token 另行计费。`,
    comboSpeechCloud:(p)=>`${p} 在云端完成语音识别。`
  });
  Object.assign(words.de, {
    combination:(a,b)=>`${a} → ${b}`,
    directCombination:(a)=>`${a} · Nur Diktat`,
    polishCloud:(p)=>`${p} berechnet Ein- und Ausgabe-Tokens separat.`,
    comboSpeechCloud:(p)=>`${p} übernimmt die Erkennung in der Cloud.`
  });

  const speechPlans = {
    groq:{name:'Groq', icon:'groq'},
    openai:{name:'OpenAI', icon:'openai'},
    deepgram:{name:'Deepgram', icon:'deepgram'}
  };
  const writingPlans = {
    deepseek:{name:'DeepSeek', icon:'deepseek'}, openai:{name:'OpenAI', icon:'openai'},
    google:{name:'Google', icon:'gemini'}, anthropic:{name:'Anthropic', icon:'claude'},
    ollama:{name:'Ollama', icon:'ollama', local:true}, off:{name:'', icon:null, off:true}
  };
  const state = {speech:'groq', writing:'deepseek'};
  const speechSelects = [...document.querySelectorAll('[data-usage-speech]')];
  const writingSelect = document.getElementById('usage-writing');
  const examples = {
    dictation:{speech:'groq', writing:'off'},
    cloud:{speech:'groq', writing:'deepseek'},
    local:{speech:'groq', writing:'ollama'}
  };
  const exampleButtons = [...document.querySelectorAll('[data-usage-example]')];
  const live = document.getElementById('usage-live');
  let announceTimer;
  const language = () => document.documentElement.lang.startsWith('zh') ? 'zh' : document.documentElement.lang.startsWith('de') ? 'de' : 'en';
  const put = (selector,text) => document.querySelectorAll(selector).forEach(el => {el.textContent = text;});
  function updateBrand(selector,icon) {
    document.querySelectorAll(selector).forEach(img => {
      img.hidden = !icon;
      if (icon) img.src = `assets/providers/${icon}.svg`;
    });
  }
  function render(announce = false) {
    const t = words[language()];
    const speech = speechPlans[state.speech], writing = writingPlans[state.writing];
    speechSelects.forEach(el => {el.value = state.speech;});
    writingSelect.value = state.writing;
    exampleButtons.forEach(button => {
      const example = examples[button.dataset.usageExample];
      button.setAttribute('aria-pressed', String(example.speech === state.speech && example.writing === state.writing));
    });
    put('[data-usage-speech-location]',t.cloud);
    put('[data-usage-speech-billing]',t.speechBillingCloud);
    put('#usage-writing-location',writing.off ? t.off : writing.local ? t.local : t.cloud);
    put('#usage-writing-billing',writing.off ? t.polishNone : writing.local ? t.polishLocal : t.tokenBilling);
    const combination = writing.off ? t.directCombination(speech.name) : t.combination(speech.name,writing.name);
    const firstStep = t.comboSpeechCloud(speech.name);
    const secondStep = writing.off ? t.polishNone : writing.local ? t.polishLocal : t.polishCloud(writing.name);
    put('#usage-combination-name',combination);
    put('#usage-combination-detail',`${firstStep} ${secondStep}`);
    updateBrand('[data-usage-speech-icon]',speech.icon);
    updateBrand('[data-usage-writing-icon]',writing.icon);
    if (announce && live) {
      clearTimeout(announceTimer);
      announceTimer = setTimeout(() => {live.textContent = `${combination}. ${firstStep} ${secondStep}`;},180);
    }
  }
  function translate() {
    const t = words[language()];
    document.querySelectorAll('[data-usage]').forEach(el => {
      const value = t[el.dataset.usage];
      if (typeof value === 'string') el.textContent = value;
    });
    document.querySelectorAll('[data-usage-aria]').forEach(el => {
      const value = t[el.dataset.usageAria];
      if (typeof value === 'string') el.setAttribute('aria-label',value);
    });
    clearTimeout(announceTimer);
    if (live) live.textContent = '';
    render();
  }
  speechSelects.forEach(select => select.addEventListener('change',() => {
    if (Object.hasOwn(speechPlans,select.value)) {state.speech = select.value;render(true);}
  }));
  writingSelect.addEventListener('change',() => {
    if (Object.hasOwn(writingPlans,writingSelect.value)) {state.writing = writingSelect.value;render(true);}
  });
  exampleButtons.forEach(button => button.addEventListener('click',() => {
    const example = examples[button.dataset.usageExample];
    if (!example) return;
    Object.assign(state,example);
    render(true);
  }));
  document.addEventListener('vowrite-language-change',translate);
  translate();
  document.querySelectorAll('[data-usage-control]').forEach(el => {el.disabled = false;});
  page.dataset.usageReady = 'true';
})();
