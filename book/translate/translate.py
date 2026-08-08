#!/usr/bin/env python3
"""
Translate the book's Markdown chapters to Portuguese (pt-BR) or Spanish (es) with Google
Gemini, preserving all code/config/CLI/Markdown structure and the English figures.

- Engine: Gemini text model, cheapest tier (configurable). Reads the API key the same way
  book/illustrate/nanobanana.py does (.env / environment). Never prints the key.
- Images stay English: ![alt](../images/NAME) link targets are kept verbatim (alt text may be
  translated). No figure is regenerated.
- Caches by source content hash, so unchanged chapters are not re-translated (and not re-paid).

Usage:
  python3 book/translate/translate.py --lang pt            # all chapters -> i18n/pt/chapters/
  python3 book/translate/translate.py --lang es --only 05-part2.md
  python3 book/translate/translate.py --lang pt --force    # ignore cache
"""
import argparse, hashlib, json, os, re, socket, sys, time, urllib.request, urllib.error


def mask_code(md):
    """Replace every fenced and inline code span with an opaque sentinel so the model can
    never alter code/CLI/config. Returns (masked_text, blocks)."""
    blocks = []

    def repl(m):
        blocks.append(m.group(0))
        return "【C%d】" % (len(blocks) - 1)   # 【C0】 — distinctive, model leaves it alone

    md = re.sub(r"```.*?```", repl, md, flags=re.S)      # fenced blocks first
    md = re.sub(r"`[^`\n]+`", repl, md)                  # then inline code
    md = re.sub(r"(?<=\])\([^)]+\)", repl, md)           # link/image targets (…) after ] — protect URLs/paths
    return md, blocks


def unmask_code(md, blocks):
    for i, b in enumerate(blocks):
        md = md.replace("【C%d】" % i, b)
    return md


# English function words that NO target language (de/es/fr/it/pt prose, or ar/hi/zh/ja at all) uses —
# their presence in a "translated" chunk means prose was left in English. Used to gate completeness.
EN_STOP = re.compile(
    r"\b(the|and|is|are|was|were|this|that|these|those|with|from|your|you|will|would|can|could|"
    r"when|where|which|while|used|using|following|between|before|after|both|into|their|there|have|"
    r"has|had|each|also|such|than|then|them|they|its|not|but|been|being|only|other|more|most|some|"
    r"any|all|one|two|first|second|must|should|need|allow|allows|provide|provides|example)\b", re.I)


def english_leak(text):
    """Count English function words in prose (code/sentinels excluded). A real translation ≈ 0."""
    t = re.sub(r"```.*?```", " ", text, flags=re.S)
    t = re.sub(r"`[^`\n]+`|【C\d+】", " ", t)
    return len(EN_STOP.findall(t))

DEFAULT_MODEL = os.environ.get("GEMINI_TRANSLATE_MODEL", "gemini-flash-lite-latest")
KEY_NAMES = ("GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_GENAI_API_KEY")
# Optional OpenAI-compatible backend. When LLM_BASE_URL is set, translation goes to
# {LLM_BASE_URL}/chat/completions instead of Gemini. Two profiles, auto-handled:
#   * SipPulse AI / gpt-oss (LLM_BASE_URL=https://api.sippulse.ai/v1, LLM_MODEL=gpt-oss-120b):
#     Bearer-auth with SIPPULSE_API_KEY, reasoning_effort from LLM_REASONING (e.g. "low"). Fast & cheap.
#   * Local vLLM / Qwen (LLM_BASE_URL=http://host:8001/v1): no key, thinking disabled (/no_think).
# Code is always masked to opaque sentinels first, so no backend can ever mutate code/CLI/config.
LLM_BASE_URL = os.environ.get("LLM_BASE_URL")
LLM_MODEL = os.environ.get("LLM_MODEL", "qwen-translate")
LLM_CTX = int(os.environ.get("LLM_CTX", "32768"))         # server max_model_len
LLM_API_KEY = os.environ.get("LLM_API_KEY") or os.environ.get("SIPPULSE_API_KEY")  # Bearer, optional
LLM_REASONING = os.environ.get("LLM_REASONING")           # e.g. "low" for gpt-oss; unset for others
LANG_NAMES = {"pt": "Brazilian Portuguese (pt-BR)", "es": "Latin American Spanish (es)",
              "fr": "French", "de": "German", "it": "Italian", "hi": "Hindi",
              "zh": "Simplified Chinese (Mandarin)", "ja": "Japanese",
              "ar": "Modern Standard Arabic"}
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def load_api_key():
    if LLM_BASE_URL:
        return ""   # local OpenAI-compatible backend needs no key
    for n in KEY_NAMES:
        if os.environ.get(n):
            return os.environ[n].strip()
    for envf in (os.path.join(ROOT, ".env"), os.path.join(ROOT, "..", ".env")):
        if os.path.isfile(envf):
            for line in open(envf):
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                if k.strip() in KEY_NAMES:
                    return v.strip().strip('"').strip("'")
    sys.exit("ERROR: no Gemini API key. Set one of %s in env or .env." % ", ".join(KEY_NAMES))


def prompt_for(lang_name, glossary, md):
    keep = ", ".join(glossary)
    return f"""You are a professional technical translator. Translate the following Markdown \
chapter of a book about Asterisk (VoIP/telephony) from English into {lang_name}.

Translate EVERY sentence of prose fully into {lang_name}. Never leave a sentence, paragraph, \
heading, list item, or table cell in English. The ONLY things that stay in English are the 【C…】 \
placeholders and the specific technical terms listed below — everything else MUST be {lang_name}.

STRICT RULES — follow exactly:
- Translate ONLY human-readable prose: paragraph text, headings, list-item text, table-cell \
text, blockquote text, image alt-text, and captions.
- DO NOT translate or alter in any way:
  * fenced code blocks (between ``` ```), including comments inside them — copy byte for byte;
  * inline `code`, configuration keys/values, CLI commands and their output, file paths, \
option names, numbers, version strings, URLs, and email addresses;
  * Markdown syntax: heading markers (#), list bullets, table pipes (|), blockquote >, link \
and image targets — keep every `](target)` and `](path)` EXACTLY (you may translate an image's \
alt text, never its path); Pandoc attributes like {{.unnumbered}} and {{width=...}}.
- The text contains opaque placeholders like 【C0】, 【C1】 (these stand for code/CLI/config). \
Keep every placeholder EXACTLY as-is and in place — never translate, edit, remove, reorder, or \
add spaces inside them.
- Keep these technical terms in English (do not translate): {keep}.
- Preserve all blank lines and the overall layout so the Markdown renders identically.
- Output ONLY the translated Markdown. No preamble, no explanation, and do NOT wrap the whole \
document in a code fence.

--- BEGIN MARKDOWN ---
{md}
--- END MARKDOWN ---"""


def _llm_key():
    """Bearer key for the OpenAI-compatible backend: env first, then .env (SIPPULSE_API_KEY)."""
    if LLM_API_KEY:
        return LLM_API_KEY
    for envf in (os.path.join(ROOT, ".env"), os.path.join(ROOT, "..", ".env")):
        if os.path.isfile(envf):
            for line in open(envf):
                line = line.strip()
                if line.startswith(("SIPPULSE_API_KEY=", "LLM_API_KEY=")):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
    return None


def openai_generate(prompt):
    """OpenAI-compatible chat completion. `prompt` is the full instruction+content. Returns the
    translated text, or "" on a context-length 400 so the caller falls back to per-section chunks."""
    out_budget = min(32000, max(512, LLM_CTX - (len(prompt) // 4) - 600))  # cap completion for the API
    body = {"model": LLM_MODEL, "temperature": 0.2, "max_tokens": out_budget,
            "messages": [{"role": "user", "content": prompt}]}
    if LLM_REASONING:                                             # gpt-oss style: set reasoning level
        body["reasoning_effort"] = LLM_REASONING
    else:                                                         # Qwen-style local model: no thinking
        body["messages"][0]["content"] = prompt + "\n\n/no_think"
        body["chat_template_kwargs"] = {"enable_thinking": False}
    headers = {"Content-Type": "application/json"}
    _k = _llm_key()
    if _k:
        headers["Authorization"] = "Bearer " + _k
    url = LLM_BASE_URL.rstrip("/") + "/chat/completions"
    for attempt in range(8):
        req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers)
        try:
            data = json.loads(urllib.request.urlopen(req, timeout=900).read())
            return data["choices"][0]["message"]["content"]
        except urllib.error.HTTPError as e:
            if e.code == 400:
                return ""   # too long for the context → caller chunks by section
            if e.code == 429 and attempt < 7:               # rate limit: patient exponential backoff
                time.sleep(min(60, 4 * (2 ** attempt))); continue
            if e.code in (500, 502, 503, 504) and attempt < 7:
                time.sleep(4 * (attempt + 1)); continue
            sys.exit("ERROR: LLM HTTP %s: %s" % (e.code, e.read().decode()[:400]))
        except (socket.timeout, urllib.error.URLError, ConnectionError, OSError) as e:
            if attempt < 7:                              # transient network blips (reset, refused) — retry
                time.sleep(4 * (attempt + 1)); continue
            sys.exit("ERROR: LLM request failed after retries: %s" % e)


def translate(model, key, text):
    if LLM_BASE_URL:
        return openai_generate(text)
    body = {"contents": [{"parts": [{"text": text}]}],
            "generationConfig": {"temperature": 0.2, "maxOutputTokens": 65536}}
    url = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent" % model
    # Retry transient failures (read timeouts, 429/5xx) so one hiccup doesn't kill a whole run.
    data = None
    for attempt in range(5):
        req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json",
                                              "x-goog-api-key": key})
        try:
            resp = urllib.request.urlopen(req, timeout=300)
            data = json.loads(resp.read())
            break
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and attempt < 4:
                time.sleep(5 * (attempt + 1)); continue
            sys.exit("ERROR: Gemini HTTP %s: %s" % (e.code, e.read().decode()[:500]))
        except (socket.timeout, urllib.error.URLError) as e:
            if attempt < 4:
                time.sleep(5 * (attempt + 1)); continue
            sys.exit("ERROR: Gemini request failed after retries: %s" % e)
    try:
        parts = data["candidates"][0]["content"]["parts"]
        return "".join(p.get("text", "") for p in parts)
    except (KeyError, IndexError):
        sys.exit("ERROR: unexpected Gemini response: %s" % json.dumps(data)[:500])


def translate_block(text, lang_name, glossary, model, key, attempts=3):
    """Mask code → translate → restore, retrying drops/dupes. Returns (restored_text, ok).
    Masking hides code from the model so it can never be mutated; restoration is byte-exact."""
    masked, blocks = mask_code(text)
    prompt = prompt_for(lang_name, glossary, masked)
    leak_max = max(2, int(0.20 * english_leak(text)))   # translated output must shed ≥80% of English
    restored = None
    for _ in range(attempts):
        t = translate(model, key, prompt).replace("```", "")  # spurious fences are not real code
        seen = set()                                          # drop repeated sentinels (keep first)
        t = re.sub(r"【C\d+】",
                   lambda m: "" if m.group(0) in seen else (seen.add(m.group(0)) or m.group(0)), t)
        missing = [i for i in range(len(blocks)) if ("【C%d】" % i) not in t]
        restored = unmask_code(t, blocks)
        if not missing and "【C" not in restored and english_leak(restored) <= leak_max:
            return restored, True   # code intact AND prose actually translated
    return restored, False


def _passthrough(text, lang_name, glossary, model, key):
    """Robust path: fenced code blocks pass through byte-for-byte (never sent to the model); the
    prose between them is translated, paragraph-by-paragraph if a segment still drops a sentinel."""
    parts = re.split(r"(```.*?```)", text, flags=re.S)   # ``` blocks land on the odd indices
    out, ok = [], True
    for i, part in enumerate(parts):
        if i % 2 == 1 or not part.strip():
            out.append(part); continue
        lead = part[:len(part) - len(part.lstrip("\n"))]
        trail = part[len(part.rstrip("\n")):]
        core = part.strip("\n")
        r, ok2 = translate_block(core, lang_name, glossary, model, key)
        if not ok2:
            paras = re.split(r"\n\n+", core)
            rr, ok2 = [], True
            for para in paras:
                pr, okp = translate_block(para, lang_name, glossary, model, key)
                rr.append(pr.strip("\n")); ok2 = ok2 and okp
            r = "\n\n".join(rr)
        out.append(lead + r.strip("\n") + trail); ok = ok and ok2
    return "".join(out), ok


def translate_document(text, lang_name, glossary, model, key):
    """Translate a chapter section by section (split on `## `). The model translates a section in one
    masked call reliably; whole big chapters it truncates (too many sentinels). A section that drops a
    code sentinel falls back to fenced-passthrough (code blocks copied verbatim). Returns (text, ok)."""
    parts = re.split(r"(?m)(?=^## )", text)              # zero-width split: "".join(parts) == text
    out, ok_all = [], True
    for part in parts:
        if not part.strip():
            out.append(part); continue
        lead = part[:len(part) - len(part.lstrip("\n"))]
        trail = part[len(part.rstrip("\n")):]
        core = part.strip("\n")
        r, ok = translate_block(core, lang_name, glossary, model, key, attempts=2)
        if not ok or "【C" in r:
            r, ok = _passthrough(core, lang_name, glossary, model, key)
        out.append(lead + r.strip("\n") + trail); ok_all = ok_all and ok
    return "".join(out), ok_all


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", required=True, choices=list(LANG_NAMES))
    ap.add_argument("--src", default=os.path.join(ROOT, "src", "chapters"))
    ap.add_argument("--out", default=None)
    ap.add_argument("--glossary", default=os.path.join(HERE, "glossary.txt"))
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--only", default=None, help="translate just this filename")
    ap.add_argument("--force", action="store_true", help="ignore the cache")
    a = ap.parse_args()

    out = a.out or os.path.join(ROOT, "i18n", a.lang, "chapters")
    os.makedirs(out, exist_ok=True)
    glossary = [ln.strip() for ln in open(a.glossary)
                if ln.strip() and not ln.startswith("#")]
    key = load_api_key()
    manifest_path = os.path.join(out, ".hashes.json")
    manifest = json.load(open(manifest_path)) if os.path.isfile(manifest_path) else {}

    files = sorted(f for f in os.listdir(a.src) if f.endswith(".md"))
    if a.only:
        files = [a.only]
    done = skipped = 0
    for f in files:
        src = open(os.path.join(a.src, f)).read()
        h = hashlib.sha256(src.encode()).hexdigest()
        dst = os.path.join(out, f)
        if not a.force and manifest.get(f) == h and os.path.isfile(dst):
            print("  = %s (cached)" % f); skipped += 1; continue
        print("  → %s (%s)" % (f, LANG_NAMES[a.lang]))
        restored, ok = translate_document(src, LANG_NAMES[a.lang], glossary, a.model, key)
        ok = ok and "【C" not in restored
        open(dst, "w").write(restored.rstrip() + "\n")
        done += 1
        if not ok:
            print("    ! WARNING: %s still imperfect after fallback — NOT caching" % f)
            continue
        manifest[f] = h
        json.dump(manifest, open(manifest_path, "w"), indent=0)
    print("Done: %d translated, %d cached → %s" % (done, skipped, out))


if __name__ == "__main__":
    main()
