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
    { f: 'index.html',                    n: '',   t: 'Lab home',                 g: 'Start' },
    { f: '0000-prework.html',             n: '00', t: 'Prework',                  g: 'Before the session' },

    /* Part 1, how a harness is built. Lesson 0N is deliberately the same number
     * as ai-harness-app/0N_*.py, so a page and its script never disagree. */
    { f: '0001-one-call.html',            n: '01', t: 'One call to a model',      g: 'Part 1 · How a harness is built' },
    { f: '0002-give-it-a-tool.html',      n: '02', t: 'Give it a tool',           g: 'Part 1 · How a harness is built' },
    { f: '0003-make-it-an-agent.html',    n: '03', t: 'Make it an agent',         g: 'Part 1 · How a harness is built' },
    { f: '0004-context-engineering.html', n: '04', t: 'Context engineering',      g: 'Part 1 · How a harness is built' },
    { f: '0005-when-data-lies.html',      n: '05', t: 'When the data lies',       g: 'Part 1 · How a harness is built' },

    { f: '0006-setup.html',               n: '06', t: 'Wake up your agent',       g: 'Part 2 · AI Harness: Claude Code' },
    { f: '0007-find-the-secrets.html',    n: '07', t: 'Find the secrets',         g: 'Part 2 · AI Harness: Claude Code' },
    { f: '0008-zsp-access.html',          n: '08', t: 'Zero standing privileges', g: 'Part 2 · AI Harness: Claude Code' },
    { f: '0009-fix-the-app.html',         n: '09', t: 'Delete the key',           g: 'Part 2 · AI Harness: Claude Code' },
    { f: '0010-identity-broker.html',     n: '10', t: 'The Identity Broker',      g: 'Part 2 · AI Harness: Claude Code' },
    { f: '0011-build-from-nothing.html',  n: '11', t: 'Build from one prompt',    g: 'Part 2 · Optional advanced courses' },
    { f: '0012-write-a-skill.html',       n: '12', t: 'Write your own skill',     g: 'Part 2 · Optional advanced courses' },
    { f: '0013-afk-harness.html',         n: '13', t: 'Build something AFK',      g: 'Part 2 · Optional advanced courses' },
    { f: 'reference/cheatsheet.html',     n: '',   t: 'Cheat sheet',              g: 'Reference' }
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

  function initCopy() {
    all('.code').forEach(function (block) {
      var pre = block.querySelector('pre');
      if (!pre) return;

      var btn = el('button', 'copy', 'Copy');
      btn.type = 'button';
      btn.addEventListener('click', function () {
        var ok = copyText(pre.innerText.replace(/\s+$/, ''));
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

  /* ---------- steps + progress -----------------------------------------
   * Each .step gets a tick box. Ticks persist per page so a browser reload
   * mid-lab does not lose anyone's place.
   */

  function initSteps() {
    var steps = all('.step');
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
    all('.check').forEach(function (check, n) {
      var answer = check.getAttribute('data-answer');
      var buttons = all('.opts button', check);
      var whys = all('.why', check);

      if (!check.querySelector('.check-kicker')) {
        check.insertBefore(el('p', 'check-kicker', '✅ Knowledge check ' + (n + 1)), check.firstChild);
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

  /* ---------- go ---------- */

  function boot() {
    buildBrand();
    buildNav();
    buildPager();
    initOS();
    initCopy();
    initSteps();
    initChecks();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
