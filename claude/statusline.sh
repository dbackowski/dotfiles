#!/usr/bin/env bash
# Claude Code status line: token/context usage + session cost (for token-priced
# auth such as AWS Bedrock, where .rate_limits is absent).

input=$(cat)

[ -n "$YOLO_CLAUDE_SANDBOX" ] && printf '\033[33m[sandboxed]\033[0m '

# Cumulative spend across every session today. Session cost from the payload
# resets on /clear, so this is the figure that tracks real token burn.
IFS=$'\t' read -r day_cost day_tokens _ < <("$HOME/.claude/statusline-daily-cost.sh" 60 2>/dev/null || true)

printf '%s' "$input" | jq -r --arg day_cost "${day_cost:-0}" --arg day_tokens "${day_tokens:-0}" --arg home "$HOME" '
  def fmt:
    (. // 0)
    | if . >= 1000000 then (((. / 100000) | floor) / 10 | tostring) + "M"
      elif . >= 1000 then (((. / 1000) | floor) | tostring) + "k"
      else (. | floor | tostring) end;

  def money:
    ((. // 0) * 100 | round) as $c
    | ($c / 100 | floor | tostring) + "." + ($c % 100 | tostring | if length < 2 then "0" + . else . end);

  def paint(c): "[" + c + "m" + . + "[0m";

  (.context_window // {}) as $cw
  | (.cost // {}) as $cost
  | (($cw.used_percentage // 0) | floor) as $pct
  | (if $pct >= 90 then "31" elif $pct >= 70 then "33" else "32" end) as $pcol
  | [
      ((.workspace.current_dir // .cwd // "")
        | if startswith($home) then "~" + ltrimstr($home) else . end | paint("38;5;208")),

      (.model.display_name // "?" | paint("36")),

      ("ctx " + ($cw.total_input_tokens | fmt) + "/" + ($cw.context_window_size | fmt)
        + " " + ($pct | tostring) + "%" | paint($pcol)),

      ("sess $" + ($cost.total_cost_usd | money) | paint("35")),

      ("today $" + ($day_cost | tonumber | money)
        + " / " + ($day_tokens | tonumber | fmt) | paint("35"))
    ]
    + (if .effort then [("effort " + .effort.level | paint("38;5;220"))] else [] end)
    + (if .exceeds_200k_tokens then ["[31m>200k[0m"] else [] end)
  | join(" [2m|[0m ")
'
