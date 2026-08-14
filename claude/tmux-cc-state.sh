#!/bin/sh
# Record what this Claude Code session is doing on its own tmux pane, so the
# window tab can show it: busy -> "claude*", wait -> "claude!", done -> "claude✓".
# Rendered by @cc_agg / @cc_mark in ~/.tmux.conf.local.
#
# Called from the hooks in ~/.claude/settings.json. Always exits 0: a marker is
# never worth failing a hook and blocking the session over.
[ -n "$TMUX_PANE" ] || exit 0

state=$1
if [ "$state" = notify ]; then
  # Notification fires both when a permission prompt is on screen and as a 60s
  # idle nudge ("is waiting for your input"). Only the first means the session is
  # actually blocked on you; the idle nudge would wrongly relabel a finished tab.
  grep -q 'needs your permission' || exit 0
  state=wait
fi

tmux set-option -p -t "$TMUX_PANE" @cc "$state" 2>/dev/null
exit 0
