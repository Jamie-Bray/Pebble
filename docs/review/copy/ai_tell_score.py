#!/usr/bin/env python3
"""Count common "AI-written" tells in a copy inventory.

Usage (from the repo root):
    python3 docs/review/copy/ai_tell_score.py docs/review/copy/inventory_before.txt
    python3 docs/review/copy/ai_tell_score.py docs/review/copy/inventory_after.txt --show em_dash

This is a guide for a human editor, not a target. Each check is a plain regex
count, so it misses things a reader would catch and flags some things that are
fine (a list of three real features is not a tell). Never rewrite a line only
to lower a number here.

Checks (one count per match):
  em_dash            "—" and spaced " – " / " -- " used as a dash
  not_x_but_y        "Not X. Not Y." / "not X, it's Y" / "isn't just" / "not just"
  fragment_triplet   three or more 1-3 word sentences in a row ("Calm. Clear. Done.")
  dramatic_fragment  a 1-2 word sentence that follows another sentence in the same line
                     ("Lasting ripples."). Plain imperatives such as "Try again." or
                     "Tap to start." are skipped: they are instructions, not effect.
  trailing_ellipsis  "..." or "…" not after an -ing word (Loading..., Saving... are fine)
  colon_reveal       "Here's the thing:", "The result:", "The best part:" and similar
  buzzword           seamless, effortless, elevate, empower, unlock, journey,
                     peace of mind, delightful, magic, crafted, designed to, simply,
                     ensure, at your fingertips, level up, game-changer, take the
                     guesswork, worry-free, hassle-free, stress-free, robust,
                     whether you're, every single, truly, perfect for
  just_softener      "just" used as a softener
  feelings_claim     telling people how they feel ("we know how", "you deserve",
                     "you've got this", "let's get started")
  exclamation        "!" at the end of a sentence
  committee_voice    "is securely", "are safely", "is seamlessly" and similar
  title_case         3+ word labels with every main word capitalised
  stacked_or_triplet stacked adjectives ("a warm, grown-up pink") and three-item
                     lists with a serial comma ("warm, gentle, and quietly"), the
                     rule-of-three rhythm. Noisy: real lists of features match too.
  hype_reassurance   confidence, never slip/miss/wonder, future-you, kept safe,
                     safe copy, doubt, worry, ripples, nudges. (Store docs quote
                     banned phrases in their notes, so they score here too, the
                     same way before and after.)
"""
import re
import sys
from collections import Counter, defaultdict

SMALL = {'a', 'an', 'and', 'or', 'the', 'of', 'to', 'in', 'on', 'for', 'at', 'by', 'with', 'vs'}

CHECKS = {
    'em_dash': re.compile(r'—|\s–\s|\s--\s'),
    'not_x_but_y': re.compile(
        r"\bNot [^.]{1,30}\.\s+Not\b|\bnot [^.,]{1,30}, (it's|it is|but)\b|\bisn't just\b|\bnot just\b",
        re.I),
    'trailing_ellipsis': re.compile(r'(?<!ing)(?<!ing )(\.\.\.|…)'),
    'colon_reveal': re.compile(
        r"\b(here's|here is) (the|what|how|why)\b[^:]{0,20}:|\bthe (result|best part|catch|truth|"
        r"point|secret|difference|twist|bottom line)\s*:", re.I),
    'buzzword': re.compile(
        r'\b(seamless(ly)?|effortless(ly)?|elevate[sd]?|empower(s|ing)?|unlock(s|ing)?|journey|'
        r'peace of mind|delightful|magic(al)?|crafted|designed to|simply|ensures?|'
        r'at your fingertips|level up|game[- ]changer|take the guesswork|worry[- ]free|'
        r'hassle[- ]free|stress[- ]free|robust|whether you\'re|every single|truly|perfect for)\b',
        re.I),
    'just_softener': re.compile(r"\bjust\b(?! (now|a moment|before|after|like|in time))", re.I),
    'feelings_claim': re.compile(
        r"\bwe know how\b|\byou deserve\b|\byou've got this\b|\blet's (get started|go|begin|do this)\b|"
        r"\bno more (worry|stress)|\bwe get it\b|\bwe understand\b", re.I),
    'exclamation': re.compile(r'[A-Za-z0-9)]!(\s|$|["\'])'),
    'stacked_or_triplet': re.compile(
        r'\b(?:a|an)\s+[a-z]+,\s+[a-z-]+\s+[a-z]+|\b[A-Za-z]+, [a-z]+, and [a-z]+', re.I),
    'hype_reassurance': re.compile(
        r'\b(total confidence|with confidence|never (slip|miss|wonder|worry)|slip your mind|'
        r'future-you|kept safe|stays? safe|safe copy|keeps safe|doubt|worry|ripples?|nudges?)\b',
        re.I),
    'committee_voice': re.compile(
        r'\b(is|are|be|been) (securely|safely|seamlessly|carefully|automatically)\b', re.I),
}

IMPERATIVE = re.compile(
    r'^(Try|Tap|Sign|Open|Check|Turn|Renew|Retry|Continue|Cancel|Save|Start|Choose|Add)\b')
SENT_SPLIT = re.compile(r'(?<=[.!?])\s+')


def sentence_checks(text):
    """Return counts for fragment_triplet and dramatic_fragment."""
    sents = [s for s in SENT_SPLIT.split(text.strip()) if s]
    counts = Counter()
    if len(sents) < 2:
        return counts
    short = [len(re.findall(r"[A-Za-z']+", s)) <= 3 and s.endswith(('.', '!')) for s in sents]
    run = 0
    for flag in short + [False]:
        if flag:
            run += 1
        else:
            if run >= 3:
                counts['fragment_triplet'] += 1
            run = 0
    for i, s in enumerate(sents[1:], 1):
        n = len(re.findall(r"[A-Za-z']+", s))
        if re.match(IMPERATIVE, s):
            continue
        if n <= 2 and s.endswith(('.', '!')) and not re.match(r'^\$|^X$', s):
            counts['dramatic_fragment'] += 1
    return counts


def title_case(text):
    t = re.sub(r'\$\{[^}]*\}|\$\w+', '', text).strip()
    words = re.findall(r"[A-Za-z][A-Za-z']*", t)
    main = [w for w in words if w.lower() not in SMALL]
    if len(words) < 3 or len(main) < 3 or len(t) > 60 or t.endswith('.'):
        return 0
    if all(w[0].isupper() for w in main) and not all(w.isupper() for w in main):
        # brand names that are legitimately capitalised
        if re.fullmatch(r'(Pebble Routines|Personal Premium|Google Play|App Store)', t):
            return 0
        return 1
    return 0


def score(path, show=None):
    section = 'preamble'
    totals = defaultdict(Counter)
    examples = []
    for raw in open(path, encoding='utf-8'):
        line = raw.rstrip('\n')
        if line.startswith('## '):
            section = line[3:].strip()
            if section.startswith(('App', 'Website', 'Emails', 'Store')):
                section = section.split(' ')[0]
            continue
        if not line.strip() or line.startswith('#'):
            continue
        text = re.sub(r'^\d+: ', '', line)
        c = Counter()
        for name, rx in CHECKS.items():
            n = len(rx.findall(text))
            if n:
                c[name] += n
        c.update(sentence_checks(text))
        if title_case(text):
            c['title_case'] += 1
        totals[section].update(c)
        if show and c.get(show):
            examples.append(text)
    return totals, examples


def main():
    args = sys.argv[1:]
    show = None
    if '--show' in args:
        i = args.index('--show')
        show = args[i + 1]
        del args[i:i + 2]
    totals, examples = score(args[0], show)
    names = list(CHECKS) + ['fragment_triplet', 'dramatic_fragment', 'title_case']
    sections = [s for s in ('App', 'Website', 'Emails', 'Store') if s in totals]
    print(f"{'check':<20}" + ''.join(f'{s:>9}' for s in sections) + f"{'total':>9}")
    grand = 0
    for n in names:
        row = [totals[s][n] for s in sections]
        grand += sum(row)
        print(f'{n:<20}' + ''.join(f'{v:>9}' for v in row) + f'{sum(row):>9}')
    print(f"{'ALL':<20}" + ''.join(f'{sum(totals[s].values()):>9}' for s in sections) + f'{grand:>9}')
    if show:
        print(f'\n--- lines flagged for {show} ---')
        for e in examples:
            print(e)


if __name__ == '__main__':
    main()
