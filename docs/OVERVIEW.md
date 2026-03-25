# MathArena Overview

A guide for evaluating LLMs on high-level math benchmarks, focused on using OpenRouter (e.g., Qwen 3.5).

## What is MathArena?

MathArena is a benchmark platform (NeurIPS D&B '25) that evaluates LLMs on **real, recent math competitions**: AIME, IMO, Putnam, HMMT, and more. Problems are sourced from HuggingFace datasets. The pipeline: send problems to an LLM API, parse `\boxed{}` answers, grade against gold answers, produce leaderboards.

## Repository Structure

```
matharena/
├── scripts/run.py              # Main entry point — runs evaluations
├── scripts/regrade.py          # Re-grade existing results
├── scripts/app.py              # Web UI to inspect results (localhost:5001)
├── scripts/extraction/         # Leaderboard and analysis scripts
│
├── configs/
│   ├── competitions/           # YAML configs per benchmark
│   │   ├── aime/              # AIME 2024-2026 (30 problems each)
│   │   ├── hmmt/              # HMMT Feb/Nov 2024-2026
│   │   ├── smt/               # Stanford Math Tournament 2025
│   │   ├── cmimc/             # Carnegie Mellon 2025
│   │   ├── apex/              # APEX + Shortlist 2025
│   │   ├── imo/               # International Math Olympiad 2025
│   │   ├── putnam/            # Putnam 2025
│   │   ├── arxiv/             # Research-level ArXiv problems
│   │   └── ...                # Kangaroo, USAMO, Euler, etc.
│   │
│   └── models/                 # YAML configs per model
│       ├── qwen/              # Qwen 3, 3.5, QwQ configs (OpenRouter)
│       ├── openai/            # GPT-4o, o1, o3, o4-mini, GPT-5
│       ├── anthropic/         # Claude Opus 4
│       ├── google/            # Gemini variants
│       ├── deepseek/          # DeepSeek R1, V3
│       └── ...                # xai, together, vllm, etc.
│
├── src/matharena/
│   ├── runner.py               # Orchestrator: load problems, run solver, grade
│   ├── api_client.py           # Unified API client (OpenAI, Anthropic, OpenRouter, etc.)
│   ├── parser.py               # Extract \boxed{} answers from model output
│   ├── grader.py               # Compare extracted answer to gold answer
│   ├── solvers/                # Pure model (CoT) and agent solvers
│   └── tools/                  # Code execution, paper search, etc.
│
└── outputs/                    # Results saved here (auto-created)
```

## Available Benchmarks

### Final-Answer Competitions (auto-graded)

| Competition | Config Path | # Problems | Date | Difficulty |
|---|---|---|---|---|
| AIME 2025 | `aime/aime_2025` | 30 | Feb 2025 | Intermediate |
| AIME 2026 | `aime/aime_2026` | 30 | Feb 2026 | Intermediate |
| HMMT Feb 2025 | `hmmt/hmmt_feb_2025` | 30 | Feb 2025 | Intermediate |
| HMMT Feb 2026 | `hmmt/hmmt_feb_2026` | 33 | Feb 2026 | Intermediate |
| HMMT Nov 2025 | `hmmt/hmmt_nov_2025` | 30 | Nov 2025 | Intermediate |
| SMT 2025 | `smt/smt_2025` | 53 | Dec 2025 | Intermediate |
| CMIMC 2025 | `cmimc/cmimc_2025` | 40 | Jul 2025 | Intermediate |
| BRUMO 2025 | `brumo/brumo_2025` | 30 | Apr 2025 | Intermediate |
| APEX 2025 | `apex/apex_2025` | 12 | Aug 2025 | Advanced |
| APEX Shortlist | `apex/shortlist_2025` | 48 | Aug 2025 | Advanced |
| ArXiv December | `arxiv/december` | 17 | Dec 2025 | Research |
| ArXiv January | `arxiv/january` | 23 | Jan 2026 | Research |
| ArXiv February | `arxiv/february` | 32 | Feb 2026 | Research |
| Kangaroo 2025 | `kangaroo/kangaroo_2025_*` | 168 (6 levels) | Mar 2025 | Easy-Intermediate |

### Proof-Based Competitions (require human judging)

| Competition | Config Path | # Problems | Date |
|---|---|---|---|
| IMO 2025 | `imo/imo_2025` | 6 | Jul 2025 |
| USAMO 2025 | `usamo/usamo_2025` | 6 | Mar 2025 |
| Putnam 2025 | `putnam/putnam_2025` | 12 | Dec 2025 |
| IMC 2025 | `imc/imc_2025` | 10 | Jul 2025 |

**For automated eval, use the final-answer competitions.** Proof-based ones require manual grading.

## Qwen 3.5 on OpenRouter

The model config already exists at `configs/models/qwen/qwen3.5_397b.yaml`:

```yaml
model: qwen/qwen3.5-397b-a17b
api: openrouter
max_tokens: 65536
temperature: 0.6
top_p: 0.95
concurrent_requests: 20
read_cost: 0.6        # $/M input tokens
write_cost: 3.6       # $/M output tokens
human_readable_id: Qwen3.5-397b-a17b
```

The only requirement is setting the `OPENROUTER_API_KEY` environment variable.

## Pipeline Flow

```
run.py
  → Runner loads competition problems from HuggingFace
  → Solver sends problems to LLM API (N times each)
  → Parser extracts \boxed{} answers
  → Grader compares to gold answers
  → Results saved to outputs/{comp}/{model}/
```

## Cost Estimation

With Qwen 3.5 on OpenRouter ($0.60/M input, $3.60/M output) and 65K max output tokens:

- **Worst case per problem** (1 run): ~$0.24 output tokens
- **4 runs x 264 problems**: ~$250 worst case (assuming max output every time)
- **Realistic estimate**: Most responses are much shorter. Expect $30-80 for a full 264-problem, 4-run eval.

Reduce cost by using `--n 1` (single run per problem) for initial testing.

## Setup (Step by Step)

### 1. Install UV (package manager)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Then restart your shell or run `source ~/.zshrc` (or `~/.bashrc`).

### 2. Set your API key

```bash
export OPENROUTER_API_KEY="sk-or-v1-your-key-here"
```

Add this to your `~/.zshrc` or `~/.bashrc` to persist it, or create a `.env` file in the repo root (the repo uses `python-dotenv`).

### 3. Verify the install

```bash
cd /path/to/matharena

# uv will auto-create venv and install deps on first run
uv run python -c "from matharena.api_client import APIClient; print('OK')"
```

No manual `venv` creation needed — `uv` handles it automatically based on `pyproject.toml`. It creates a `.venv/` in the repo root on first `uv run`.

### 4. Quick smoke test (1 problem, 1 run)

```bash
uv run python scripts/run.py \
  --comp aime/aime_2025 \
  --models qwen/qwen3.5_397b \
  --n 1 \
  --problems 1
```

This sends a single AIME problem to Qwen 3.5, parses the answer, grades it. Results go to `outputs/aime/aime_2025/Qwen3.5-397b-a17b/`.

### 5. Run the full eval

```bash
# Full run: all final-answer competitions, 4 runs per problem
bash scripts/run_qwen35_eval.sh

# Or filter by tier:
bash scripts/run_qwen35_eval.sh --comps aime          # just AIME (60 problems)
bash scripts/run_qwen35_eval.sh --comps intermediate   # AIME+HMMT+SMT+CMIMC+BRUMO (246 problems)
bash scripts/run_qwen35_eval.sh --comps advanced        # APEX + shortlist (60 problems)
bash scripts/run_qwen35_eval.sh --comps research        # ArXiv math (72 problems)

# Cheap test run (1 run per problem instead of 4):
bash scripts/run_qwen35_eval.sh --n 1

# Dry run (shows what would execute, no API calls):
bash scripts/run_qwen35_eval.sh --dry-run
```

### 6. Inspect results

```bash
# Web UI (browse to http://localhost:5001)
uv run python scripts/app.py --comp aime/aime_2025

# Generate leaderboard
uv run python scripts/extraction/leaderboard.py \
  --comps aime/aime_2025 aime/aime_2026 hmmt/hmmt_feb_2025
```

### Resumability

If the run is interrupted (rate limits, network issues, etc.), just re-run the same command. It **skips problems that already have results** in `outputs/` and picks up where it left off. Use `--redo-all` only if you want to discard existing results and start fresh.

## Alternative: Conda Setup (no UV)

If you prefer not to use UV:

```bash
conda create -n matharena python=3.12
conda activate matharena
pip install -e .
```

Then replace all `uv run python` commands with just `python`.
