# Investment debate advisor

Six LLM-powered advocate agents debate six asset classes — Stocks, Mutual
Funds, Post Office Savings, Land/Real Estate, Gold, Bitcoin — in a sustained,
natural conversation using **live market data**. A seventh referee/advisor
scores the debate and gives the user balanced, plain-language guidance.

> **Educational content only — not personalized financial advice.** Markets
> carry risk of loss. Consult a licensed advisor for your situation.

## Features

- **Real conversation, not monologues.** Every agent sees a running
  transcript and directly rebuts others by name each round.
- **Live prices every run** — S&P 500, Gold futures, VNQ (real-estate ETF
  proxy), BTC-USD via `yfinance`. Post Office is fixed ~7%.
- **Paced, not token-burning.** A configurable think-delay between turns
  fills real time naturally; a rolling summary keeps prompt size bounded.
- **Minimum 20 minutes and ≥12 rounds**, with hard safety caps on rounds
  and tokens so it cannot run forever.
- **Guardrails.** Agents have no tools, stay on-topic, and refuse role changes.
- **Transcript saved** to a timestamped Markdown file.

## Run locally

```bash
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...
# Optional: export ANTHROPIC_MODEL=claude-sonnet-4-5
python advisor.py --question "I'm 30, long horizon, where should I put $10k?"
```

CLI flags:

| Flag | Default | What |
| --- | --- | --- |
| `--minutes` | `20` | Minimum real-time duration (minutes) |
| `--rounds-min` | `12` | Minimum full rounds (one turn per advocate = one round) |
| `--delay` | `4` | Per-turn thinking delay (seconds, jittered) |
| `--max-rounds` | `40` | Hard safety cap on rounds |
| `--question` | — | User question; interactive prompt if omitted |
| `--out-dir` | `./transcripts` | Where to save the final `.md` |

Env vars: `ANTHROPIC_API_KEY` (required), `ANTHROPIC_MODEL`,
`ANTHROPIC_SUMMARIZER_MODEL`, `MAX_TOTAL_INPUT_TOKENS`,
`MAX_TOTAL_OUTPUT_TOKENS`.

## Run in the hardened Docker sandbox

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

- **`--read-only`** — the container filesystem is immutable; only
  `/tmp` (tmpfs) and the mounted `transcripts/` volume are writable.
- **`--cap-drop ALL` + `--security-opt no-new-privileges`** — no Linux
  capabilities, no privilege escalation (no `setuid` surprises).
- **`--pids-limit`, `--memory`, `--cpus`** — fork/mem/CPU bombs blocked.
- **Non-root user** (`app`, uid baked in; `--user 1000:1000` for safety
  when the volume is host-owned).
- **No tools exposed to the LLM** — agents are plain `messages.create`
  calls, so there is no path from the model to a shell or the filesystem.
- **Python `-I`** — isolated mode, so planted `sitecustomize.py` /
  `PYTHON*` env vars from an attacker-controlled working dir are ignored.
- **Egress.** The only outbound traffic the program makes is to the
  Anthropic API and `query*.finance.yahoo.com` (yfinance). If you run with
  `--network` restricted to an egress proxy, allow those two destinations.

If `yfinance` cannot reach Yahoo (offline, blocked egress), the program
logs that the quote is unavailable and the debate proceeds with reasoning
only — so sandbox network restrictions do not break the app.

## Files

- `advisor.py` — the whole program (agents, loop, referee, transcript I/O)
- `requirements.txt` — `anthropic`, `yfinance`
- `Dockerfile` — non-root, minimal, `ENTRYPOINT`-driven
- `README.md` — this file

## Notes

- Agents are capped at ~350 output tokens/turn; the referee at ~1800.
- Older rounds are summarized every 3 rounds; the last 3 rounds stay
  verbatim. This keeps prompts bounded over the full 20 minutes.
- The referee runs **after** the minimum time/round thresholds are met,
  then the transcript is written and the process exits.
