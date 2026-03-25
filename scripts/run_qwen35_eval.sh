#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Evaluate Qwen 3.5 (397B-A17B) via OpenRouter on final-answer math benchmarks
#
# Usage:
#   bash scripts/run_qwen35_eval.sh              # full eval (264 problems, n=4)
#   bash scripts/run_qwen35_eval.sh --dry-run    # print what would run, don't execute
#   bash scripts/run_qwen35_eval.sh --n 1        # single run per problem (cheap test)
#   bash scripts/run_qwen35_eval.sh --comps aime  # only AIME competitions
# =============================================================================

# ── Defaults ──────────────────────────────────────────────────────────────────
MODEL="qwen/qwen3.5_397b"
DEFAULT_N=4
DRY_RUN=false
FILTER=""
CUSTOM_N=""

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=true; shift ;;
    --n)        CUSTOM_N="$2"; shift 2 ;;
    --comps)    FILTER="$2"; shift 2 ;;
    --model)    MODEL="$2"; shift 2 ;;
    *)          echo "Unknown arg: $1"; exit 1 ;;
  esac
done

N="${CUSTOM_N:-$DEFAULT_N}"

# ── Check prerequisites ──────────────────────────────────────────────────────
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "ERROR: OPENROUTER_API_KEY is not set."
  echo "  export OPENROUTER_API_KEY=your-key-here"
  exit 1
fi

# ── Competition sets by difficulty tier ───────────────────────────────────────
# Intermediate: AIME, HMMT, SMT, CMIMC, BRUMO (~246 problems)
INTERMEDIATE=(
  "aime/aime_2025"
  "aime/aime_2026"
  "hmmt/hmmt_feb_2025"
  "hmmt/hmmt_feb_2026"
  "hmmt/hmmt_nov_2025"
  "smt/smt_2025"
  "cmimc/cmimc_2025"
  "brumo/brumo_2025"
)

# Advanced: APEX shortlist + APEX (~60 problems)
ADVANCED=(
  "apex/shortlist_2025"
  "apex/apex_2025"
)

# Research: ArXiv math (~72 problems)
RESEARCH=(
  "arxiv/december"
  "arxiv/january"
  "arxiv/february"
)

# ── Select competitions based on filter ───────────────────────────────────────
COMPS=()
case "${FILTER,,}" in
  aime)         COMPS=("aime/aime_2025" "aime/aime_2026") ;;
  hmmt)         COMPS=("hmmt/hmmt_feb_2025" "hmmt/hmmt_feb_2026" "hmmt/hmmt_nov_2025") ;;
  intermediate) COMPS=("${INTERMEDIATE[@]}") ;;
  advanced)     COMPS=("${ADVANCED[@]}") ;;
  research)     COMPS=("${RESEARCH[@]}") ;;
  all|"")       COMPS=("${INTERMEDIATE[@]}" "${ADVANCED[@]}" "${RESEARCH[@]}") ;;
  *)            echo "Unknown filter: $FILTER (use: aime, hmmt, intermediate, advanced, research, all)"; exit 1 ;;
esac

# ── Per-competition N overrides (APEX needs more runs for statistical power) ─
declare -A N_VALUES=(
  ["apex/apex_2025"]=16
)

COMP_N_OVERRIDES=()
for comp in "${COMPS[@]}"; do
  if [[ -n "${N_VALUES[$comp]:-}" ]]; then
    COMP_N_OVERRIDES+=("${comp}=${N_VALUES[$comp]}")
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo "============================================"
echo "MathArena Eval: Qwen 3.5 via OpenRouter"
echo "============================================"
echo "Model:        $MODEL"
echo "Runs/problem: $N (default), overrides: ${COMP_N_OVERRIDES[*]:-none}"
echo "Competitions: ${COMPS[*]}"
echo "Total comps:  ${#COMPS[@]}"
echo "============================================"

if $DRY_RUN; then
  echo ""
  echo "[DRY RUN] Would execute:"
  echo "  python scripts/run.py \\"
  echo "    --comp ${COMPS[*]} \\"
  echo "    --models $MODEL \\"
  echo "    --n $N"
  if [[ ${#COMP_N_OVERRIDES[@]} -gt 0 ]]; then
    echo "    --comp-n ${COMP_N_OVERRIDES[*]}"
  fi
  exit 0
fi

# ── Run eval ──────────────────────────────────────────────────────────────────
echo ""
echo "Starting eval..."

CMD=(python scripts/run.py --comp "${COMPS[@]}" --models "$MODEL" --n "$N")
if [[ ${#COMP_N_OVERRIDES[@]} -gt 0 ]]; then
  CMD+=(--comp-n "${COMP_N_OVERRIDES[@]}")
fi

"${CMD[@]}"

echo ""
echo "============================================"
echo "Eval complete. Results in outputs/"
echo "Inspect: python scripts/app.py --comp COMP_NAME"
echo "============================================"
