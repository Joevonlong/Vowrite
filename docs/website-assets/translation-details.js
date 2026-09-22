
    // Live demo rotator — swaps through 4 sentence pairs
    (function () {
      const samples = [
        {
          flagIn: '🇨🇳', langInKey: 'tr.lang.zh', langInDefault: 'Chinese',
          textIn: '嗯…那个，明天下午三点开个会，把翻译模式的设计方案过一下。',
          flagOut: '🇺🇸', langOutDefault: 'English', langOutKey: null,
          textOut: "Let's meet at 3 pm tomorrow to walk through the Translate mode design."
        },
        {
          flagIn: '🇺🇸', langInKey: null, langInDefault: 'English',
          textIn: "Hey, can you push the latest config to staging and let QA know once it's live? Thanks!",
          flagOut: '🇨🇳', langOutKey: 'tr.lang.zh', langOutDefault: 'Chinese',
          textOut: '能把最新配置推到 staging，然后告诉 QA 已经上线了吗？谢谢！'
        },
        {
          flagIn: '🇯🇵', langInKey: 'tr.lang.ja', langInDefault: 'Japanese',
          textIn: 'えっと、来週の月曜にデモやりたいんですけど、空いてますか？',
          flagOut: '🇺🇸', langOutKey: null, langOutDefault: 'English',
          textOut: "I'd like to do a demo next Monday — are you free?"
        },
        {
          flagIn: '🇩🇪', langInKey: 'tr.lang.de', langInDefault: 'German',
          textIn: 'Können wir den Release-Termin auf nächste Woche verschieben? Ich brauche noch ein bisschen Zeit für die Tests.',
          flagOut: '🇨🇳', langOutKey: 'tr.lang.zh', langOutDefault: 'Chinese',
          textOut: '能把发布时间挪到下周吗？我还需要一点时间做测试。'
        }
      ];

      const flagIn = document.getElementById('trDemoFlagIn');
      const langIn = document.getElementById('trDemoLangIn');
      const textIn = document.getElementById('trDemoIn');
      const flagOut = document.getElementById('trDemoFlagOut');
      const langOut = document.getElementById('trDemoLangOut');
      const textOut = document.getElementById('trDemoOut');
      const row = document.getElementById('trDemoRow');
      const dots = document.querySelectorAll('.tr-demo-dot');

      function langText(key, fallback) {
        if (!key) return fallback;
        const lang = document.documentElement.lang === 'zh-CN' ? 'zh' : document.documentElement.lang;
        if (lang === 'en') return fallback;
        if (typeof i18n !== 'undefined' && i18n[lang] && i18n[lang][key]) return i18n[lang][key];
        return fallback;
      }

      let idx = 0;
      function render(i) {
        const s = samples[i];
        flagIn.textContent = s.flagIn;
        langIn.textContent = langText(s.langInKey, s.langInDefault);
        textIn.textContent = s.textIn;
        flagOut.textContent = s.flagOut;
        langOut.textContent = langText(s.langOutKey, s.langOutDefault);
        textOut.textContent = s.textOut;
        row.classList.remove('tr-demo-fade');
        void row.offsetWidth;
        row.classList.add('tr-demo-fade');
        dots.forEach((d,j)=>{d.classList.toggle('active',j===i);d.setAttribute('aria-pressed',String(j===i));});
      }

      const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
      let paused=motion.matches, interval=null;
      const pause=document.createElement('button');pause.type='button';pause.className='tr-demo-pause';
      dots[0].parentElement.classList.add('tr-demo-controls');dots[0].parentElement.append(pause);
      function labels(){const lang=document.documentElement.lang;const words=lang==='zh-CN'?['暂停轮播','播放轮播','示例']:lang==='de'?['Pause','Abspielen','Beispiel']:['Pause','Play','Example'];pause.textContent=words[paused?1:0];pause.setAttribute('aria-pressed',String(paused));dots.forEach((d,i)=>d.setAttribute('aria-label',words[2]+' '+(i+1)));}
      function schedule(){clearInterval(interval);if(!paused)interval=setInterval(()=>{if(!document.hidden){idx=(idx+1)%samples.length;render(idx)}},4200);labels();}
      pause.addEventListener('click',()=>{paused=!paused;schedule()});
      motion.addEventListener('change',()=>{if(motion.matches)paused=true;schedule()});
      document.addEventListener('vowrite-language-change',()=>{render(idx);labels()});
      schedule();render(idx);

      dots.forEach((d) => {
        d.addEventListener('click', () => {
          paused=true;schedule();idx = parseInt(d.getAttribute('data-i'), 10);
          render(idx);
        });
      });
    })();
