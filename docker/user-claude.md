# Pod environment

You run in an ephemeral Linux Pod (Debian, non-root user `dev`). Project instructions in the repo's own CLAUDE.md take precedence over this file.

- Work happens in `/workspace`, which is lost when the Pod is replaced. Push work to GitHub.
- System Python is 3.11. For Python projects use `uv`, which downloads the Python version the project needs:
  `uv venv --python 3.12 /workspace/.venv-<repo>` then `uv pip install --python /workspace/.venv-<repo> -e ".[dev]"`.
- Create venvs outside the repo. Ignore a `.venv` from the repo if it has `Scripts/` (Windows layout); it does not work here.
- Internet egress is open (GitHub, PyPI, npm). If a command runs longer than 2 minutes with no output, treat it as stuck: stop it, check connectivity with `curl -sI <url>`, and report what you found instead of waiting.
- In your final report, list checks you could not run, and why.
