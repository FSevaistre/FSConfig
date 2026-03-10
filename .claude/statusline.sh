#!/usr/bin/env bash
# Claude Code status line script
# Reads JSON from stdin and outputs a compact status line

input=$(cat)

# Model display name
model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')

# Context window usage percentage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used_pct" ]; then
  ctx_int=$(printf "%.0f" "$used_pct")
  if   [ "$ctx_int" -ge 80 ]; then cc=$'\033[01;31m'
  elif [ "$ctx_int" -ge 50 ]; then cc=$'\033[01;33m'
  else                              cc=$'\033[00;32m'
  fi
  ctx_label="${cc}Ctx:${ctx_int}%"$'\033[00m'
else
  ctx_label="Ctx:-"
fi

# Rate limit utilization from Claude Code's JSON input (no API call needed)
rate_label=""
s_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
w_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$s_pct" ] || [ -n "$w_pct" ]; then
  s_pct="${s_pct:-0}"
  w_pct="${w_pct:-0}"
  max_pct=$(( s_pct > w_pct ? s_pct : w_pct ))
  if   [ "$max_pct" -ge 80 ]; then rc=$'\033[01;31m'  # red
  elif [ "$max_pct" -ge 50 ]; then rc=$'\033[01;33m'  # yellow
  else                              rc=$'\033[00;32m'  # green
  fi
  rate_label="${rc}S:${s_pct}%  W:${w_pct}%"$'\033[00m'
fi

# Current working directory
cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$cwd" ]; then
  cwd=$(pwd)
fi

# Git branch
branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)

# Build output: model, rate limits, context, cwd, branch
out="${model}"
if [ -n "$rate_label" ]; then
  out="${out}  ${rate_label}"
fi
out="${out}  ${ctx_label}"
out="${out}  \033[01;34m${cwd}\033[00m"
if [ -n "$branch" ]; then
  out="${out}  \033[01;33m(${branch})\033[00m"
fi
printf "%b" "$out"

# DEBUG: log input to tmp file
echo "$input" > /tmp/statusline_debug.json
