"""Export MathArena outputs to .jsonl with full thinking traces.

Usage:
    uv run python scripts/export_jsonl.py --comp aime/aime_2025
    uv run python scripts/export_jsonl.py --comp aime/aime_2025 --model qwen/qwen3.5_397b
    uv run python scripts/export_jsonl.py --comp aime/aime_2025 --output results.jsonl
"""

import argparse
import json
import os
from pathlib import Path

import yaml


def _load_model_max_tokens(model_config_path: str) -> int | None:
    """Load max_tokens from a model config YAML file."""
    path = Path("configs/models") / f"{model_config_path}.yaml"
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as f:
        config = yaml.safe_load(f)
    return config.get("max_tokens")


def export(comp: str, model_filter: str | None, output_path: str):
    outputs_dir = Path("outputs") / comp

    if not outputs_dir.exists():
        print(f"No outputs found at {outputs_dir}")
        return

    records = []

    # Cache model max_tokens lookups
    max_tokens_cache: dict[str, int | None] = {}

    # Walk model directories
    for model_dir in sorted(outputs_dir.rglob("*.json")):
        raw = json.loads(model_dir.read_text(encoding="utf-8"))

        # Derive model name from path: outputs/comp/.../model_dir/problem.json
        rel = model_dir.relative_to(Path("outputs") / comp)
        model_name = str(rel.parent)

        if model_filter and model_filter not in model_name:
            continue

        # Look up configured max_tokens for this model
        if model_name not in max_tokens_cache:
            max_tokens_cache[model_name] = _load_model_max_tokens(model_name)
        configured_max_tokens = max_tokens_cache[model_name]

        problem_idx = raw.get("idx")
        n_runs = raw.get("N", 0)

        for run_idx in range(n_runs):
            messages = raw.get("messages", [])[run_idx] if run_idx < len(raw.get("messages", [])) else []

            # Separate thinking and response
            thinking_parts = []
            response_parts = []
            for msg in messages:
                if msg.get("role") == "assistant":
                    if msg.get("type") in ("cot", "reasoning"):
                        thinking_parts.append(msg.get("content", ""))
                    elif msg.get("type") == "response" or "type" not in msg:
                        response_parts.append(msg.get("content", ""))

            # Detect truncation: output_tokens hit the configured max_tokens limit
            cost_entry = raw.get("detailed_costs", [{}])[run_idx] if run_idx < len(raw.get("detailed_costs", [])) else {}
            output_tokens = cost_entry.get("output_tokens", 0)
            truncated = (
                configured_max_tokens is not None
                and output_tokens >= configured_max_tokens
            )

            record = {
                "competition": comp,
                "model": model_name,
                "problem_idx": problem_idx,
                "run_idx": run_idx,
                "problem": raw.get("problem", ""),
                "gold_answer": raw.get("gold_answer", ""),
                "model_answer": raw["answers"][run_idx] if run_idx < len(raw.get("answers", [])) else None,
                "correct": raw["correct"][run_idx] if run_idx < len(raw.get("correct", [])) else None,
                "warning": raw["warnings"][run_idx] if run_idx < len(raw.get("warnings", [])) else None,
                "truncated": truncated,
                "output_tokens": output_tokens,
                "max_tokens": configured_max_tokens,
                "thinking_trace": "\n\n".join(thinking_parts),
                "response": "\n\n".join(response_parts),
                "messages_raw": messages,
                "cost": cost_entry,
                "problem_types": raw.get("types", []),
                "source": raw.get("source"),
            }
            records.append(record)

    if not records:
        print("No matching records found.")
        return

    with open(output_path, "w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")

    print(f"Exported {len(records)} records to {output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export MathArena results to JSONL")
    parser.add_argument("--comp", required=True, help="Competition path (e.g., aime/aime_2025)")
    parser.add_argument("--model", default=None, help="Filter by model name substring")
    parser.add_argument("--output", "-o", default=None, help="Output file path (default: exports/<comp>_<model>.jsonl)")
    args = parser.parse_args()

    if args.output is None:
        os.makedirs("exports", exist_ok=True)
        safe_name = args.comp.replace("/", "_")
        if args.model:
            safe_name += f"_{args.model.replace('/', '_')}"
        args.output = f"exports/{safe_name}.jsonl"

    export(args.comp, args.model, args.output)
