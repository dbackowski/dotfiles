#!/usr/bin/env bash
# Sums today's token spend across every Claude Code session transcript.
#
# Rows are deduped by message.id: a streamed assistant message is written to the
# transcript once per content block, so summing raw rows overcounts several-fold.
# Bedrock leaves costUSD null, so cost is computed from statusline-pricing.json.
#
# Cached to keep the status line responsive; TTL seconds via first arg.

set -uo pipefail

TTL="${1:-60}"
ROOT="$HOME/.claude/projects"
PRICING="$HOME/.claude/statusline-pricing.json"
CACHE="${TMPDIR:-/tmp}/claude-daily-cost-$(id -u).cache"

if [ -f "$CACHE" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || echo 0) ))
  if [ "$age" -lt "$TTL" ]; then
    cat "$CACHE"
    exit 0
  fi
fi

today=$(date +%Y-%m-%d)

# Only scan files touched today; a full 109MB sweep would stall the status line.
files=$(find "$ROOT" -name '*.jsonl' -newermt "$today" 2>/dev/null)
if [ -z "$files" ]; then
  printf '0.00\t0\t0' | tee "$CACHE"
  exit 0
fi

printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 cat 2>/dev/null | jq -rs --arg today "$today" --slurpfile pricing "$PRICING" '
  ($pricing[0]) as $p

  # Dedup by message id, keeping one row per assistant message.
  | map(select(.message.usage and .message.id and (.timestamp // "" | startswith($today))))
  | unique_by(.message.id)

  | map(
      .message.usage as $u
      | (.message.model // "") as $m
      | ($p.models[$m] // $p.default) as $rate
      | (($u.cache_creation.ephemeral_1h_input_tokens // 0)) as $w1h
      | (($u.cache_creation.ephemeral_5m_input_tokens // 0)) as $w5m
      # Fall back to the aggregate field when the per-TTL breakdown is absent.
      | (if ($w1h + $w5m) > 0 then 0 else ($u.cache_creation_input_tokens // 0) end) as $wflat
      | {
          cost: (
              (($u.input_tokens // 0)            * $rate.input          / 1000000)
            + (($u.output_tokens // 0)           * $rate.output         / 1000000)
            + (($u.cache_read_input_tokens // 0) * $rate.cache_read     / 1000000)
            + ($w1h                              * $rate.cache_write_1h / 1000000)
            + (($w5m + $wflat)                   * $rate.cache_write_5m / 1000000)
          ),
          billed: (($u.input_tokens // 0) + ($u.output_tokens // 0)
                   + ($u.cache_read_input_tokens // 0)
                   + $w1h + $w5m + $wflat),
          msgs: 1
        }
    )
  | (reduce .[] as $x ({c:0,t:0,n:0};
      {c: (.c + $x.cost), t: (.t + $x.billed), n: (.n + $x.msgs)})) as $tot

  | ((($tot.c * 100) | round) / 100 | tostring) + "\t"
  + ($tot.t | tostring) + "\t"
  + ($tot.n | tostring)
' > "$CACHE".tmp 2>/dev/null

if [ -s "$CACHE".tmp ]; then
  mv "$CACHE".tmp "$CACHE"
else
  rm -f "$CACHE".tmp
  printf '0.00\t0\t0' > "$CACHE"
fi

cat "$CACHE"
