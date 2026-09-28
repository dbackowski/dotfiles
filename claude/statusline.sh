#!/usr/bin/env bash
# Claude Code status line: context usage + subscription plan limits.
#
# .rate_limits is only present for subscription (claude.ai) auth; it is absent
# on API-key/Bedrock/Vertex sessions, where those windows simply do not render.

input=$(cat)

[ -n "$YOLO_CLAUDE_SANDBOX" ] && printf '\033[33m[sandboxed]\033[0m '

printf '%s' "$input" | jq -r --arg home "$HOME" '
  def fmt:
    (. // 0)
    | if . >= 1000000 then (((. / 100000) | floor) / 10 | tostring) + "M"
      elif . >= 1000 then (((. / 1000) | floor) | tostring) + "k"
      else (. | floor | tostring) end;

  def paint(c): "[" + c + "m" + . + "[0m";

  # Percentage -> 10-cell bar. Empty cells use the same glyph in grey so both
  # halves have equal height, then colour $c is restored for the rest of the segment.
  def bar($c):
    ([[., 0] | max, 100] | min / 10 | floor) as $f
    | ("█" * $f) + "\u001b[38;5;240m" + ("█" * (10 - $f)) + "\u001b[" + $c + "m";

  # Green below 70% used, amber to 90%, red above.
  def pcol: if . >= 90 then "31" elif . >= 70 then "33" else "32" end;

  # Epoch seconds -> time left in that window, as 3h5m / 42m.
  def left:
    ((. - now) | floor)
    | if . <= 0 then "now"
      else (. / 3600 | floor) as $h | (. % 3600 / 60 | floor) as $m
        | if $h > 0 then ($h | tostring) + "h" + ($m | tostring) + "m"
          else ($m | tostring) + "m" end
      end;

  def window($label):
    if . == null then empty
    else ((.used_percentage // 0) | floor) as $p
      | ((.resets_at // null) | if . == null then "" else " " + (tonumber | left) end) as $r
      | ($label + " " + ($p | bar($p | pcol)) + " " + ($p | tostring) + "%" + $r) | paint($p | pcol)
    end;

  (.context_window // {}) as $cw
  | (.rate_limits // {}) as $rl
  | (($cw.used_percentage // 0) | floor) as $pct
  | [
      ((.workspace.current_dir // .cwd // "")
        | if startswith($home) then "~" + ltrimstr($home) else . end | paint("38;5;208")),

      (.model.display_name // "?" | paint("36")),

      ("ctx " + ($cw.total_input_tokens | fmt) + "/" + ($cw.context_window_size | fmt)
        + " " + ($pct | bar($pct | pcol)) + " " + ($pct | tostring) + "%" | paint($pct | pcol))
    ]
    + [$rl.five_hour   | window("5h")]
    + [$rl.seven_day   | window("7d")]
    + [$rl.spend_limit | window("credits")]
    + (if .effort then [("effort " + .effort.level | paint("38;5;220"))] else [] end)
    + (if .exceeds_200k_tokens then ["[31m>200k[0m"] else [] end)
  | join(" [2m|[0m ")
'
