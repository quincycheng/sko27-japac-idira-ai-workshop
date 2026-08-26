/* Shared behaviour for the SKO27 TechSummit - Idira AI Workshops lab guide.
 *
 * Constraints this file respects, deliberately:
 *   - runs from file:// by double-click, so: no modules, no fetch, no imports
 *   - no network of any kind
 *   - every browser API that can be blocked on file:// is wrapped in try/catch
 *
 * Features: brand bar, page selector, OS switcher, copy buttons, step ticks
 * with progress bar, knowledge checks.
 */
(function () {
  'use strict';

  /* ---------- the lesson list ------------------------------------------
   * Single source of truth. The top nav and the bottom pager on every page
   * are generated from this, so adding a lesson means editing one array.
   * Paths are relative to lab/.
   */

  var PAGES = [
    { f: 'index.html',                            n: '',   t: 'Welcome!',                      g: 'Start' },
    { f: '0000-setup.html',                       n: '00', t: 'Setup',                         g: 'Before the session' },

    /* Lessons 01 to 05 carry deliberately the same number as
     * ai-harness-app/0N_*.py, so a page and its script never disagree. Numbers do
     * not move when a lesson changes group, so 01 and 02 keep theirs while being
     * done at home. Lesson 06 has no script: it is the break time activity that
     * follows Part 1, and its own group says so. */
    { f: '0001-one-call.html',                    n: '01', t: 'One call to a model',           g: 'Before the session' },
    { f: '0002-conversation-history.html',        n: '02', t: 'Conversation history',          g: 'Before the session' },

    { f: '0003-context-engineering.html',         n: '03', t: 'Context engineering',           g: 'Part 1 · Build your own AI harness' },
    { f: '0004-tools-and-agents.html',            n: '04', t: 'Tools and agents',              g: 'Part 1 · Build your own AI harness' },
    { f: '0005-the-harness.html',                 n: '05', t: 'The harness',                   g: 'Part 1 · Build your own AI harness' },

    { f: '0006-who-runs-the-agents.html',         n: '06', t: 'Who runs the agents?',          g: 'Break time activity · Govern what you built' },

    { f: '0007-setup.html',                       n: '07', t: 'Get Started: Claude Code',      g: 'Part 2 · Practical Guide to AI Harness' },
    { f: '0008-find-the-secrets.html',            n: '08', t: 'Vibe coding: Find the secrets', g: 'Part 2 · Practical Guide to AI Harness' },
    { f: '0009-zsp-access.html',                  n: '09', t: 'Skills: ZSP by Idsec CLI',      g: 'Part 2 · Practical Guide to AI Harness' },
    { f: '0010-identity-broker.html',             n: '10', t: 'MCP: AI Agent Identity Broker', g: 'Part 2 · Practical Guide to AI Harness' },
    { f: '0011-build-from-nothing.html',          n: '11', t: 'Build from one prompt',         g: 'Part 3 · Optional Deep Dives' },
    { f: '0012-write-a-skill.html',               n: '12', t: 'Write your own skill',          g: 'Part 3 · Optional Deep Dives' },
    { f: '0013-afk-harness.html',                 n: '13', t: 'Build something AFK',           g: 'Part 3 · Optional Deep Dives' },
    { f: '0014-fix-the-app.html',                 n: '14', t: 'Delete the key',                g: 'Part 3 · Optional Deep Dives' },
    { f: '0015-external-mcp-server.html',         n: '15', t: 'Bring your own MCP server',     g: 'Part 3 · Optional Deep Dives' },
    { f: '0016-identity-broker-apj-secrets.html', n: '16', t: 'Identity Broker on apj-secrets', g: 'Part 3 · Optional Deep Dives' },
    { f: 'reference/securing-agentic-ai.html',    n: '',   t: 'Post-Workshop Resources',       g: 'Reference' },
    { f: 'reference/cheatsheet.html',             n: '',   t: 'Cheat sheet',                   g: 'Reference' }
  ];

  /* ---------- tiny helpers ---------- */

  function all(sel, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(sel));
  }

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }

  // localStorage is unavailable in some file:// contexts. Never let it throw.
  var store = {
    get: function (k) {
      try { return window.localStorage.getItem(k); } catch (e) { return null; }
    },
    set: function (k, v) {
      try { window.localStorage.setItem(k, v); } catch (e) { /* ignore */ }
    }
  };

  /* Where is lab/ from here? Derived from this script's own src, so it works
   * whether the page sits in lab/ or lab/reference/, and survives the whole
   * folder being renamed or moved. */
  var BASE = (function () {
    var s = document.currentScript;
    if (!s) {
      var list = all('script[src]');
      s = list[list.length - 1];
    }
    var src = (s && s.getAttribute('src')) || '';
    return src.replace(/assets\/lab\.js.*$/, '');
  })();

  var HERE = (function () {
    var last = decodeURIComponent(location.pathname.split('/').pop() || 'index.html');
    if (!last) last = 'index.html';
    for (var i = 0; i < PAGES.length; i++) {
      if (PAGES[i].f.split('/').pop() === last) return i;
    }
    return -1;
  })();

  var pageKey = 'idira-lab:' + (HERE >= 0 ? PAGES[HERE].f : 'unknown');

  function href(page) {
    return BASE + page.f;
  }

  function label(page) {
    return page.n ? page.n + ' · ' + page.t : page.t;
  }

  /* ---------- brand bar ------------------------------------------------
   * The masthead every page carries: Idira logo + the workshop title. Injected
   * rather than copied into each file so the title exists in exactly one place.
   * The logo is a local file — like everything else here, it must render with
   * the network unplugged.
   */

  var SITE_TITLE = 'SKO27 TechSummit - AI Workshop for Idira DC';

  function buildBrand() {
    if (document.querySelector('.site-brand')) return;

    var bar = el('div', 'site-brand');
    var inner = el('div', 'site-brand-inner');

    var logo = document.createElement('img');
    logo.className = 'site-logo';
    logo.src = BASE + 'assets/idira-logo-light.svg';
    logo.alt = 'Idira';
    inner.appendChild(logo);

    inner.appendChild(el('span', 'site-title', SITE_TITLE));
    bar.appendChild(inner);
    document.body.insertBefore(bar, document.body.firstChild);
  }

  /* ---------- page selector --------------------------------------------
   * <nav id="page-nav"></nav>   at the top of every page
   * <div id="page-pager"></div> at the bottom
   */

  function buildNav() {
    var mount = document.getElementById('page-nav');
    if (!mount) return;

    var prev = HERE > 0 ? PAGES[HERE - 1] : null;
    var next = HERE >= 0 && HERE < PAGES.length - 1 ? PAGES[HERE + 1] : null;

    var back = el('a', 'nav-arrow', '‹ Back');
    if (prev) { back.href = href(prev); back.title = label(prev); }
    else { back.className = 'nav-arrow disabled'; back.setAttribute('aria-hidden', 'true'); }
    mount.appendChild(back);

    var select = el('select', 'nav-select');
    select.setAttribute('aria-label', 'Jump to a page');
    var groups = {};
    PAGES.forEach(function (p, i) {
      if (!groups[p.g]) {
        var og = document.createElement('optgroup');
        og.label = p.g;
        groups[p.g] = og;
        select.appendChild(og);
      }
      var opt = el('option', null, label(p));
      opt.value = String(i);
      if (i === HERE) opt.selected = true;
      groups[p.g].appendChild(opt);
    });
    select.addEventListener('change', function () {
      var p = PAGES[parseInt(select.value, 10)];
      if (p) location.href = href(p);
    });
    mount.appendChild(select);

    var fwd = el('a', 'nav-arrow', 'Next ›');
    if (next) { fwd.href = href(next); fwd.title = label(next); }
    else { fwd.className = 'nav-arrow disabled'; fwd.setAttribute('aria-hidden', 'true'); }
    mount.appendChild(fwd);
  }

  function buildPager() {
    var mount = document.getElementById('page-pager');
    if (!mount) return;

    var prev = HERE > 0 ? PAGES[HERE - 1] : null;
    var next = HERE >= 0 && HERE < PAGES.length - 1 ? PAGES[HERE + 1] : null;

    if (prev) {
      var a = el('a', null, '← ' + label(prev));
      a.href = href(prev);
      mount.appendChild(a);
    } else {
      mount.appendChild(el('span', null, ' '));
    }

    if (next) {
      var b = el('a', null, label(next) + ' →');
      b.href = href(next);
      mount.appendChild(b);
    } else {
      mount.appendChild(el('span', null, ' '));
    }
  }

  /* ---------- OS switcher -------------------------------------------------
   * Mixed-OS room. One control at the top of the page swaps every
   * platform-specific block at once, and the choice follows the attendee
   * from lesson to lesson.
   *
   *   <div class="os-switch" data-os-switch></div>   (buttons injected)
   *   <div class="os os-mac"> ... </div>
   *   <div class="os os-win"> ... </div>
   */

  var OS_KEY = 'idira-lab:os';
  var OS_LABELS = { mac: '🍎 macOS', win: '🪟 Windows' };

  function applyOS(os) {
    all('.os').forEach(function (e) {
      e.classList.toggle('active', e.classList.contains('os-' + os));
    });
    all('[data-os-switch] button').forEach(function (b) {
      b.setAttribute('aria-pressed', b.getAttribute('data-os') === os ? 'true' : 'false');
    });
    loadCasts();
  }

  /* ---------- walkthrough players -----------------------------------------
   * Each lesson holds two recordings, one per OS, and shows the one the switch
   * above selects:
   *
   *   <div class="cast" data-cast="<asciinema id>" data-rows="44"></div>
   *
   * The asciinema tag cannot simply sit in the hidden block. It builds its
   * player inside an iframe, measures it once, and never measures it again, so
   * a player created while its block is display:none renders at the wrong font
   * size and loses the right-hand columns when the block is revealed. So the
   * tag is injected here instead, on the first reveal, and only the recording
   * being watched is ever downloaded.
   */

  function loadCasts() {
    all('.cast').forEach(function (slot) {
      if (slot.getAttribute('data-loaded')) return;
      // Hidden blocks have no layout box. Nothing to measure yet, so wait.
      if (!slot.offsetWidth && !slot.offsetHeight) return;

      var id = slot.getAttribute('data-cast');
      var s = document.createElement('script');
      s.src = 'https://asciinema.org/a/' + id + '.js';
      s.id = 'asciicast-' + id;
      s.async = true;
      s.setAttribute('data-rows', slot.getAttribute('data-rows'));
      slot.setAttribute('data-loaded', '1');
      slot.appendChild(s);
    });
  }

  function initOS() {
    var mounts = all('[data-os-switch]');
    if (!mounts.length) return;

    var saved = store.get(OS_KEY);
    var os = (saved === 'mac' || saved === 'win') ? saved
           : (navigator.platform && navigator.platform.indexOf('Win') === 0 ? 'win' : 'mac');

    mounts.forEach(function (mount) {
      mount.setAttribute('role', 'group');
      mount.setAttribute('aria-label', 'Choose your operating system');
      Object.keys(OS_LABELS).forEach(function (key) {
        var b = el('button', null, OS_LABELS[key]);
        b.type = 'button';
        b.setAttribute('data-os', key);
        b.addEventListener('click', function () {
          store.set(OS_KEY, key);
          applyOS(key);
        });
        mount.appendChild(b);
      });
    });

    applyOS(os);
  }

  /* ---------- copy buttons ----------------------------------------------
   * navigator.clipboard is often absent on file://, so fall back to the old
   * hidden-textarea trick, which still works everywhere.
   */

  function copyText(text) {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text);
        return true;
      }
    } catch (e) { /* fall through */ }

    try {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed';
      ta.style.top = '-1000px';
      document.body.appendChild(ta);
      ta.select();
      var ok = document.execCommand('copy');
      document.body.removeChild(ta);
      return ok;
    } catch (e) {
      return false;
    }
  }

  /* A generated source listing has one block-level <span class="l"> per line and
   * NO newlines between them -- see build-lab-code.py for why. So the newlines are
   * put back here, from the spans, rather than trusting innerText to infer them
   * from block layout. textContent also skips the ::before line numbers, which is
   * the whole reason they are a CSS counter. */
  function preText(pre) {
    var lines = pre.querySelectorAll('.l');
    if (!lines.length) return pre.innerText;
    var out = [];
    for (var i = 0; i < lines.length; i++) out.push(lines[i].textContent);
    return out.join('\n');
  }

  function initCopy() {
    all('.code').forEach(function (block) {
      var pre = block.querySelector('pre');
      if (!pre) return;
      // .code-term is the app's own OUTPUT. There is nothing to paste anywhere.
      if (block.classList.contains('code-term')) return;

      var btn = el('button', 'copy', 'Copy');
      btn.type = 'button';
      btn.addEventListener('click', function () {
        var ok = copyText(preText(pre).replace(/\s+$/, ''));
        btn.textContent = ok ? 'Copied ✓' : 'Select it';
        btn.classList.toggle('ok', ok);
        setTimeout(function () {
          btn.textContent = 'Copy';
          btn.classList.remove('ok');
        }, 1600);
      });
      block.appendChild(btn);
    });
  }

  /* ---------- one copy button per prompt, inside a transcript ------------
   * A terminal block is a transcript: prompts AND the answers to them. The
   * whole-block button above is deliberately absent from it, because a clipboard
   * holding two questions and two model answers is no use to anybody.
   *
   * The prompts are useful though -- they are the things you type. So
   * build-lab-code.py wraps every `›` line in a .term-prompt carrying the prompt
   * text in data-copy, and each one gets its own button here.
   *
   * The text comes from the attribute rather than from the DOM on purpose: it is
   * how the `› ` marker, the rich colour spans and this button's own glyph are all
   * guaranteed to stay out of what you paste.
   */
  function initTermCopy() {
    all('.term-prompt').forEach(function (line) {
      var text = line.getAttribute('data-copy');
      if (!text) return;

      var btn = el('button', 'term-copy', '⧉');
      btn.type = 'button';
      btn.title = 'Copy this prompt';
      btn.setAttribute('aria-label', 'Copy this prompt: ' + text);
      btn.addEventListener('click', function () {
        var ok = copyText(text);
        btn.textContent = ok ? '✓' : '✗';
        btn.classList.toggle('ok', ok);
        setTimeout(function () {
          btn.textContent = '⧉';
          btn.classList.remove('ok');
        }, 1600);
      });
      line.appendChild(btn);
    });
  }

  /* ---------- steps + progress -----------------------------------------
   * Each required .step gets a tick box. Ticks persist per page so a browser
   * reload mid-lab does not lose anyone's place.
   *
   * `.step-opt` is excluded on purpose. The rail and the counter answer "have I
   * finished this lesson?", and the optional coding exercises are not part of
   * finishing it — counting them means the bar can never reach 100% for the
   * attendees who skip the Python, which is most of the room.
   */

  function initSteps() {
    var steps = all('.step').filter(function (s) {
      return !s.classList.contains('step-opt');
    });
    if (!steps.length) return;

    var fill = document.getElementById('progress-fill');

    function repaint() {
      var done = steps.filter(function (s) { return s.classList.contains('done'); }).length;
      if (fill) fill.style.width = (done / steps.length * 100) + '%';
      var counter = document.getElementById('step-counter');
      if (counter) {
        counter.textContent = done === steps.length
          ? '🎉 All ' + steps.length + ' steps done'
          : done + ' of ' + steps.length + ' steps done';
      }
    }

    var saved = (store.get(pageKey + ':steps') || '').split(',');

    steps.forEach(function (step, i) {
      var lab = el('label', 'tickbox');
      var box = el('input');
      box.type = 'checkbox';
      lab.appendChild(box);
      lab.appendChild(el('span', null, 'Done'));
      step.appendChild(lab);

      if (saved.indexOf(String(i)) !== -1) {
        box.checked = true;
        step.classList.add('done');
      }

      box.addEventListener('change', function () {
        step.classList.toggle('done', box.checked);
        var done = [];
        steps.forEach(function (s, j) { if (s.classList.contains('done')) done.push(j); });
        store.set(pageKey + ':steps', done.join(','));
        repaint();
      });
    });

    repaint();
  }

  /* ---------- knowledge checks -----------------------------------------
   *   <div class="check" data-answer="b">
   *     <p class="check-q">…</p>
   *     <ul class="opts">
   *       <li><button data-opt="a">…</button></li>
   *     </ul>
   *     <p class="why" data-for="a">…</p>     one per option
   *   </div>
   */

  function initChecks() {
    var checks = all('.check');
    checks.forEach(function (check, n) {
      var answer = check.getAttribute('data-answer');
      var buttons = all('.opts button', check);
      var whys = all('.why', check);

      // "Question 2 of 3" rather than "Knowledge Check 2": the questions now sit
      // under a section heading that already says Knowledge Check, and repeating
      // it on every box read as a stutter. The total also tells a reader how much
      // is left, which the old label never did.
      if (!check.querySelector('.check-kicker')) {
        check.insertBefore(
          el('p', 'check-kicker', 'Question ' + (n + 1) + ' of ' + checks.length),
          check.firstChild
        );
      }

      buttons.forEach(function (btn) {
        btn.type = 'button';
        btn.addEventListener('click', function () {
          var picked = btn.getAttribute('data-opt');
          var correct = picked === answer;

          btn.classList.add(correct ? 'right' : 'wrong');

          if (correct) {
            // Lock the question once it is answered correctly, and reveal
            // the right answer so a wrong guess still teaches.
            buttons.forEach(function (b) { b.disabled = true; });
          } else {
            btn.disabled = true;
          }

          whys.forEach(function (w) {
            w.classList.toggle('show', w.getAttribute('data-for') === picked);
          });
        });
      });
    });
  }

  /* ---------- annotated source -------------------------------------------
   * Markup generated by build-lab-code.py:
   *
   *   <div class="src">
   *     <div class="src-head">…</div>
   *     <div class="code"><pre><code>
   *       <span class="l">plain line</span>
   *       <span class="l ann" data-ann="1" role="button" tabindex="0">…</span>
   *       <span class="src-note" data-ann="1">…</span>   <-- under its own block
   *     </code></pre></div>
   *   </div>
   *
   * Click or Enter expands the note that belongs to the block, in place, directly
   * under it; clicking the same block again collapses it. One at a time, so the
   * listing does not grow under the reader while they are in it.
   *
   * Hover only tints (in CSS). Expanding on hover would move the code out from
   * under the pointer, and on a phone there is no hover to expand with anyway.
   *
   * Every note is already in the page. Nothing here fetches anything, because
   * nothing here can — the guide runs from file://.
   */

  function initSource() {
    all('.src').forEach(function (block) {
      var notes = all('.src-note', block);
      var lines = all('.l.ann', block);
      if (!notes.length || !lines.length) return;

      var open = null;

      function show(n) {
        open = n;
        notes.forEach(function (note) {
          note.classList.toggle('show', note.getAttribute('data-ann') === n);
        });
        lines.forEach(function (line) {
          var on = line.getAttribute('data-ann') === n;
          line.classList.toggle('on', on);
          // Only the first line of a block is a tab stop, and only it carries the
          // state for a screen reader.
          if (line.hasAttribute('aria-expanded')) {
            line.setAttribute('aria-expanded', on ? 'true' : 'false');
          }
        });
      }

      function pin(n) {
        show(open === n ? null : n);
        if (open) keepInView(block.querySelector('.src-note[data-ann="' + open + '"]'));
      }

      /* A twenty-line annotated block puts its note twenty lines below the line
       * that was clicked, which on a long file can be off the bottom of the
       * scroller or off the bottom of the window. Nudge, by the smallest amount
       * that brings the whole note into view. */
      function keepInView(note) {
        if (!note) return;
        var pre = block.querySelector('pre');
        if (pre && pre.scrollHeight > pre.clientHeight + 1) {
          var over = note.offsetTop + note.offsetHeight - (pre.scrollTop + pre.clientHeight);
          if (over > 0) pre.scrollTop += over + 12;
          return;
        }
        try {
          var box = note.getBoundingClientRect();
          var spare = window.innerHeight - box.bottom;
          if (spare < 12) window.scrollBy(0, 12 - spare);
        } catch (e) { /* file:// with a locked-down window object */ }
      }

      /* Jump-to-highlight. session.py and harness.py are shown whole, and three
       * marked lines in five hundred are unfindable by scrolling. Built here
       * rather than in the generated HTML so build-lab-code.py stays a text
       * transform with nothing to know about behaviour. */
      var pre = block.querySelector('pre');
      var order = [];
      lines.forEach(function (line) {
        var n = line.getAttribute('data-ann');
        if (order.indexOf(n) === -1) order.push(n);
      });

      function reveal(n) {
        show(n);
        var target = block.querySelector('.l.ann[data-ann="' + n + '"]');
        if (target && pre) {
          // Manual scroll rather than scrollIntoView, which would also drag the
          // whole page around and lose the reader's place in the lesson.
          pre.scrollTop = Math.max(0, target.offsetTop - pre.clientHeight / 3);
        }
      }

      function step(delta) {
        var at = order.indexOf(open);
        var next = at === -1 ? (delta > 0 ? 0 : order.length - 1) : at + delta;
        if (next < 0) next = order.length - 1;
        if (next >= order.length) next = 0;
        reveal(order[next]);
      }

      if (order.length > 1) {
        var nav = el('span', 'src-jump');
        [['◂', -1, 'Previous highlight'], ['▸', 1, 'Next highlight']].forEach(function (spec) {
          var btn = el('button', null, spec[0]);
          btn.type = 'button';
          btn.title = spec[2];
          btn.setAttribute('aria-label', spec[2]);
          btn.addEventListener('click', function () { step(spec[1]); });
          nav.appendChild(btn);
        });
        var head = block.querySelector('.src-head');
        if (head) head.appendChild(nav);
      }

      lines.forEach(function (line) {
        var n = line.getAttribute('data-ann');

        line.addEventListener('click', function () { pin(n); });
        line.addEventListener('keydown', function (e) {
          if (e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar') {
            e.preventDefault();   // or Space scrolls the page out from under them
            pin(n);
          }
        });
      });

      block.addEventListener('keydown', function (e) {
        if (e.key === 'Escape' && open) show(null);
      });

      show(null);
    });
  }

  /* ---------- external links -------------------------------------------------
     Anywhere the guide sends you off the guide -- the CLI docs, a release page, a
     video -- opens in its own tab. The reason is the ticked steps and the answered
     questions: those live in localStorage per page, but a reader who navigates away
     and comes back with the back button gets the page rebuilt from scratch, and on
     file:// there is no guarantee the storage was there to read in the first place.
     Leaving the guide open is the only version of that which cannot lose anything.

     Stamped here rather than typed into the markup so it holds for every page and
     every link, including ones added later. The markup only has to say href. */

  function initLinks() {
    all('a[href]').forEach(function (a) {
      if (!/^https?:/i.test(a.getAttribute('href'))) return;
      a.target = '_blank';
      // noopener: the new tab gets no window.opener handle back to this one.
      a.rel = 'noopener noreferrer';
    });
  }

  /* ---------- go ---------- */

  function boot() {
    buildBrand();
    buildNav();
    buildPager();
    initOS();
    initCopy();
    initTermCopy();
    initSteps();
    initChecks();
    initSource();
    initLinks();
    // Again after initOS, for any recording that sits outside an .os block.
    loadCasts();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
