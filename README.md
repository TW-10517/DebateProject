# Debate Stage

A topic-driven debate platform. You pick the topic, pick the cast, and watch
a referee + players + speakers argue it out on a stage — grounded in real
data, with scorecard and guidance at the end. **Not advice-giving: balanced
analysis of a topic.**

Two ways to run it:

1. **`stage.html`** — browser artifact. Configure topic and roster in the
   UI, press *Generate & start*, and Claude writes the debate in-page.
2. **`advisor.py`** — the original CLI version for the investment-advice
   case: six fixed advocates (Stocks, Mutual Funds, Post Office, Real
   Estate, Gold, Bitcoin) + a referee, backed by live `yfinance` prices.

> Educational / analytical output only — not personalized advice.

## 1. Browser stage (`stage.html`)

The stage is a single HTML file. Open it as a Claude artifact (it uses the
Claude Artifact `sample` capability to write the debate without an API key
on your machine).

**Flow:**

1. Open the artifact → **Configure topic & roster**.
2. Type any topic ("Should remote work be the default?", "Nuclear vs
   renewables for Japan's 2040 grid", "React Server Components: hype or
   substance?" — anything).
3. Edit the roster. Default: **1 referee + 2 players + 2 speakers**. Add,
   remove, or rename characters; each gets a `kind` (referee / player /
   speaker) and a free-text role/stance.
4. **Generate & start** → Claude authors a 6-round debate grounded in
   current facts, and the stage auto-plays it with spotlight, typing
   bubble, and rolling transcript. A verdict scorecard appears at the end.

Config persists in `localStorage` — refreshes keep your last debate.

Advanced: paste a pre-authored JSON script (same shape the generator
produces) into the "Advanced" box if you want to hand-write one or replay
a previous debate.

## 2. Investment-debate CLI (`advisor.py`)

The original domain-specific debate: six advocate agents + a referee,
each arguing for one of six asset classes with live market data.

```bash
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...
python advisor.py --question "I'm 30, long horizon, where should I put $10k?"
```

No API key? Run against a local Ollama model:

```bash
python advisor.py --backend ollama --question "..."
```

### CLI flags

| Flag | Default | What |
| --- | --- | --- |
| `--minutes` | `20` | Minimum real-time duration (minutes) |
| `--rounds-min` | `12` | Minimum full rounds |
| `--delay` | `4` | Per-turn thinking delay (seconds, jittered) |
| `--max-rounds` | `40` | Hard safety cap |
| `--backend` | `anthropic` | `anthropic` or `ollama` |
| `--question` | — | User question; prompts interactively if omitted |
| `--out-dir` | `./transcripts` | Where to save the final `.md` |

Env vars: `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`, `ANTHROPIC_SUMMARIZER_MODEL`,
`MAX_TOTAL_INPUT_TOKENS`, `MAX_TOTAL_OUTPUT_TOKENS`,
`OLLAMA_HOST` (default `http://127.0.0.1:11434`), `OLLAMA_MODEL`.

### Hardened Docker run

```bash
docker build -t invest-debate .

mkdir -p ./transcripts

docker run --rm \
  --read-only \
  --tmpfs /tmp:rw,size=16m,mode=1777 \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --pids-limit 128 \
  --memory 512m \
  --cpus 1.0 \
  --user 1000:1000 \
  -e ANTHROPIC_API_KEY \
  -v "$PWD/transcripts:/home/app/transcripts" \
  invest-debate \
  --minutes 20 --rounds-min 12 --delay 4 \
  --question "I'm 30, long horizon, where should I put \$10k?"
```

What that command gives you:

- `--read-only` immutable rootfs; only `/tmp` + mounted `transcripts/` writable.
- `--cap-drop ALL` + `--security-opt no-new-privileges` — no caps, no privilege
  escalation.
- Pid / memory / CPU limits block fork/mem bombs.
- Non-root user (`app`, uid 1000).
- No tools exposed to the LLM — plain `messages.create`, no shell path.
- Python `-I` ignores planted `sitecustomize.py` / `PYTHON*` env vars.
- Egress: Anthropic API + `query*.finance.yahoo.com` only.

## Design notes

- The stage adapts to any roster size — podium positions compute along an
  arc, colors assign from a 12-color palette, scorecard rows match the
  cast.
- The browser stage asks Claude to produce one JSON object with the whole
  debate (`rounds`, `summaries`, `round_summaries`, `verdict`). The viewer
  renders that object; there's no streaming / no multi-turn agent loop in
  the browser.
- The CLI version does the opposite: it drives a long conversation turn by
  turn with a rolling summary, pacing itself to ≥20 minutes. Use it when
  you want a deep, slow debate saved as Markdown.
- Neither mode gives personalized advice. The referee returns a balanced
  verdict and short analytical guidance.

## Files

| File | What |
| --- | --- |
| `stage.html` | Browser debate stage (Claude Artifact) |
| `advisor.py` | CLI investment-debate program |
| `requirements.txt` | `anthropic`, `yfinance` |
| `Dockerfile` | Sandbox for `advisor.py` |
| `.gitignore` | Ignores `transcripts/`, caches, venvs |
