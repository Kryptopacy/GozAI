.PHONY: test eval lint

# Run unit tests
test:
	uv run python -m pytest gozai_agent/rag_service_test.py -v

# Run ADK evals (requires GEMINI_API_KEY to be set)
eval:
	uv run adk eval gozai_agent tests/eval/evalsets/gozai_core.json --config_file_path=tests/eval/eval_config.json --print_detailed_results

# Lint
lint:
	uv run ruff check .

# Run the ADK web playground (interactive testing)
playground:
	uv run adk web .
