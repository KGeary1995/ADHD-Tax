@AGENTS.md

## Claude Code specifics

- Cloud sessions: Flutter is at `/opt/flutter/bin` (not on PATH). Use `app/tool/check.sh`, or `export PATH=/opt/flutter/bin:$PATH` in the same command, since shell state doesn't persist between Bash calls.
- Chromium for screenshots is preinstalled (`PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers`). Never run `playwright install`. `app/tool/screenshots/shoot.mjs` passes the session's HTTPS proxy to Chromium automatically.
- GitHub access is through the GitHub MCP tools (no `gh` CLI). Releases can be read (`get_release_by_tag`) but not created from the session; CI creates them.
- The owner usually follows along on a phone. Give them direct download links, and say plainly what was and wasn't verified on a real device.
