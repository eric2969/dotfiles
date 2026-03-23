#!/bin/sh
# Claude Code status line - inspired by Powerlevel10k classic style

input=$(cat)

# DEBUG: uncomment to inspect available fields
# echo "$input" | jq '.' > /tmp/claude-statusline-debug.json

# Directory (shorten home to ~)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
cwd_display=$(echo "$cwd" | sed "s|^$HOME|~|")

# Git branch
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.hooksPath=/dev/null symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" -c core.hooksPath=/dev/null rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    if git -C "$cwd" -c core.hooksPath=/dev/null status --porcelain 2>/dev/null | grep -q .; then
      git_branch=" \033[33m$branch*\033[0m"
    else
      git_branch=" \033[32m$branch\033[0m"
    fi
  fi
fi

# Model name + effort from settings
model=$(echo "$input" | jq -r '.model.display_name // .model.id // ""')
effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

# Context window remaining
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Rate limits
five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# --- Build the status line ---

# Left: dir + git
printf "\033[34m%s\033[0m" "$cwd_display"
printf "%b" "$git_branch"

# Separator
printf "  \033[90m|\033[0m  "

# Model + effort
printf "\033[36m%s\033[0m" "$model"
if [ -n "$effort" ]; then
  printf "\033[90m/%s\033[0m" "$effort"
fi

# Context remaining
if [ -n "$remaining" ]; then
  remaining_int=$(printf "%.0f" "$remaining")
  if [ "$remaining_int" -lt 20 ]; then
    printf "  \033[31mctx:%s%%\033[0m" "$remaining_int"
  elif [ "$remaining_int" -lt 50 ]; then
    printf "  \033[33mctx:%s%%\033[0m" "$remaining_int"
  else
    printf "  \033[90mctx:%s%%\033[0m" "$remaining_int"
  fi
fi

# Rate limits: 5h (current session) + 7d (weekly all models)
if [ -n "$five_hour" ] || [ -n "$seven_day" ]; then
  printf "  \033[90m|\033[0m"
fi

if [ -n "$five_hour" ]; then
  five_int=$(printf "%.0f" "$five_hour")
  if [ "$five_int" -ge 80 ]; then
    printf "  \033[31m5h:%s%%\033[0m" "$five_int"
  elif [ "$five_int" -ge 50 ]; then
    printf "  \033[33m5h:%s%%\033[0m" "$five_int"
  else
    printf "  \033[90m5h:%s%%\033[0m" "$five_int"
  fi
fi

if [ -n "$seven_day" ]; then
  seven_int=$(printf "%.0f" "$seven_day")
  if [ "$seven_int" -ge 80 ]; then
    printf "  \033[31m7d:%s%%\033[0m" "$seven_int"
  elif [ "$seven_int" -ge 50 ]; then
    printf "  \033[33m7d:%s%%\033[0m" "$seven_int"
  else
    printf "  \033[90m7d:%s%%\033[0m" "$seven_int"
  fi
fi
