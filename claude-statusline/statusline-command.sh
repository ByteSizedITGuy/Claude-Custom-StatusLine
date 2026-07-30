#!/usr/bin/env bash
# Claude Code custom status line -- bash renderer (macOS / Linux).
#
# Renders two lines from the JSON the Claude Code harness pipes in on stdin:
#
#   Opus 4.8 (1M context) | 128.4k/1000k (13%) | high
#   5h 42%@3:15pm | 7d 61%@jul 12, 9:00am
#
# Line 1: model name, context window used, effort level.
# Line 2: 5-hour and 7-day rate-limit windows with reset times.
# Percentages are colored: green <50%, yellow 50-69%, orange 70-89%, red >=90%.
# Every segment is optional -- whatever the harness does not report is omitted.
#
# Requires: jq on PATH.
# Install: see install-unix.sh, or copy this to ~/.claude/statusline-command.sh
#          and point settings.json at it.

input=$(cat)

esc=$'\033'
reset="${esc}[0m"
dim="${esc}[38;2;150;150;150m"
blue="${esc}[38;2;0;153;255m"
mag="${esc}[38;2;200;130;230m"
sep=" ${dim}|${reset} "

if ! command -v jq >/dev/null 2>&1; then
  printf '%s' "${dim}claude (install jq for status line)${reset}"
  exit 0
fi

# Pull every field in one pass. Missing values arrive as empty strings.
# The delimiter is US (0x1f), not a tab: bash collapses runs of whitespace
# delimiters, which would shift fields whenever one came back empty.
IFS=$'\x1f' read -r model cw_size total_in ctx_pct effort five_pct five_reset seven_pct seven_reset <<EOF
$(printf '%s' "$input" | jq -r '[
  .model.display_name,
  .context_window.context_window_size,
  .context_window.total_input_tokens,
  .context_window.used_percentage,
  .effort.level,
  .rate_limits.five_hour.used_percentage,
  .rate_limits.five_hour.resets_at,
  .rate_limits.seven_day.used_percentage,
  .rate_limits.seven_day.resets_at
] | map(if . == null then "" else tostring end) | join("\u001f")' 2>/dev/null)
EOF

pct_color() {
  local p="$1"
  if [ -z "$p" ]; then printf '%s' "$dim"; return; fi
  awk -v p="$p" -v e="$esc" 'BEGIN {
    if (p >= 90)      printf "%s[38;2;255;85;85m",  e
    else if (p >= 70) printf "%s[38;2;255;176;85m", e
    else if (p >= 50) printf "%s[38;2;240;220;90m", e
    else              printf "%s[38;2;120;220;120m", e
  }'
}

round() { awk -v n="$1" 'BEGIN { printf "%.0f", n }'; }
round1() { awk -v n="$1" 'BEGIN { printf "%.1f", n }'; }

# Format an epoch as "3:15pm" today, or "jul 12, 9:00am" on a later day.
fmt_reset() {
  local epoch="$1" today when out
  [ -z "$epoch" ] && return 0
  if date -r "$epoch" +%s >/dev/null 2>&1; then
    # BSD / macOS date
    today=$(date +%Y%m%d)
    when=$(date -r "$epoch" +%Y%m%d)
    if [ "$when" = "$today" ]; then
      out=$(date -r "$epoch" "+%I:%M%p")
    else
      out=$(date -r "$epoch" "+%b %d, %I:%M%p")
    fi
  else
    # GNU date
    today=$(date +%Y%m%d)
    when=$(date -d "@$epoch" +%Y%m%d 2>/dev/null) || return 0
    if [ "$when" = "$today" ]; then
      out=$(date -d "@$epoch" "+%I:%M%p")
    else
      out=$(date -d "@$epoch" "+%b %d, %I:%M%p")
    fi
  fi
  # Lowercase, and strip zero-padding from the hour and day-of-month.
  printf '%s' "$out" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/^0//' -e 's/ 0/ /' -e 's/, 0/, /'
}

line1=()
line2=()

[ -n "$model" ] && line1+=("${blue}${model}${reset}")

if [ -n "$cw_size" ] && [ -n "$total_in" ]; then
  used_k=$(round1 "$(awk -v t="$total_in" 'BEGIN { print t / 1000 }')")
  max_k=$(round "$(awk -v c="$cw_size" 'BEGIN { print c / 1000 }')")
  c=$(pct_color "$ctx_pct")
  p=0
  [ -n "$ctx_pct" ] && p=$(round "$ctx_pct")
  line1+=("${c}${used_k}k/${max_k}k (${p}%)${reset}")
elif [ -n "$ctx_pct" ]; then
  c=$(pct_color "$ctx_pct")
  line1+=("${c}ctx $(round "$ctx_pct")%${reset}")
fi

[ -n "$effort" ] && line1+=("${mag}${effort}${reset}")

if [ -n "$five_pct" ]; then
  c=$(pct_color "$five_pct")
  seg="${c}5h $(round "$five_pct")%${reset}"
  rs=$(fmt_reset "$five_reset")
  [ -n "$rs" ] && seg="${seg}${dim}@${rs}${reset}"
  line2+=("$seg")
fi

if [ -n "$seven_pct" ]; then
  c=$(pct_color "$seven_pct")
  seg="${c}7d $(round "$seven_pct")%${reset}"
  rs=$(fmt_reset "$seven_reset")
  [ -n "$rs" ] && seg="${seg}${dim}@${rs}${reset}"
  line2+=("$seg")
fi

join_segs() {
  local out="" s
  for s in "$@"; do
    if [ -z "$out" ]; then out="$s"; else out="${out}${sep}${s}"; fi
  done
  printf '%s' "$out"
}

if [ ${#line1[@]} -eq 0 ] && [ ${#line2[@]} -eq 0 ]; then
  printf '%s' "${dim}claude${reset}"
  exit 0
fi

if [ ${#line1[@]} -eq 0 ]; then
  out=$(join_segs "${line2[@]}")
elif [ ${#line2[@]} -eq 0 ]; then
  out=$(join_segs "${line1[@]}")
else
  out="$(join_segs "${line1[@]}")"$'\n'"$(join_segs "${line2[@]}")"
fi

printf '%s' "$out"
