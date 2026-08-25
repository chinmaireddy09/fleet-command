#!/bin/bash
# install.sh — link this checkout into ~/.claude so `git pull` IS the update.
#
# ── WHY LINK RATHER THAN COPY ────────────────────────────────────────────────────
# Claude Code reads skills from ~/.claude/skills, never from your clone. With a copied
# install that means `git pull` changes nothing about what actually runs -- the pull
# updates the checkout and the tool keeps executing yesterday's files until somebody
# remembers a second command. That is a silent failure: everything looks updated.
#
# A symlink removes the second step entirely. Verified on a live machine 2026-08-25:
# all four skills and all three commands run correctly through symlinks.
#
# ── WHAT IT WILL NOT DO ──────────────────────────────────────────────────────────
# ~/.claude/skills holds EVERY skill the user has, from every source. This script
# touches only the entries this repository ships, and it will not delete a real
# directory or file it did not create. An existing COPIED install is a directory
# somebody may have edited, so it is moved aside with a printed path, never removed.
#
#   bash install.sh              link everything (idempotent)
#   bash install.sh --force      also replace copied installs, moving them to .bak-N
#   bash install.sh --uninstall  remove ONLY the symlinks that point into this checkout
#   bash install.sh --check      report what is linked, copied, missing or foreign
set -u

SRC="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DST="${MC_SKILLS_DIR:-$HOME/.claude/skills}"
CMDS_DST="${MC_COMMANDS_DIR:-$HOME/.claude/commands}"
MODE="${1:-link}"
case "$MODE" in link|--force|--uninstall|--check) ;;
  *) echo "usage: install.sh [--force|--uninstall|--check]" >&2; exit 2 ;; esac

[ -d "$SRC/skills" ] || { echo "FAILED: no skills/ beside install.sh — run it from the checkout" >&2; exit 1; }

LINKED=0; SKIPPED=0; MOVED=0; REMOVED=0; BLOCKED=0

# Is this path a symlink that points somewhere inside THIS checkout? That is the only
# thing --uninstall may remove, and the only thing `link` may silently replace.
ours() {
  [ -L "$1" ] || return 1
  case "$(readlink "$1")" in "$SRC"/*) return 0 ;; *) return 1 ;; esac
}

place() {                       # place <source-path> <dest-path>
  local src="$1" dst="$2" name; name=$(basename "$dst")
  if ours "$dst"; then
    if [ "$(readlink "$dst")" = "$src" ]; then
      SKIPPED=$((SKIPPED+1)); return 0          # already correct
    fi
    rm -f "$dst"                                 # ours, but pointing at an old checkout
  elif [ -L "$dst" ]; then
    echo "  SKIP  $name — a symlink to somewhere else: $(readlink "$dst")"
    echo "        Not touching it. Remove it yourself if you want this one."
    BLOCKED=$((BLOCKED+1)); return 0
  elif [ -e "$dst" ]; then
    if [ "$MODE" != "--force" ]; then
      echo "  SKIP  $name — a real $( [ -d "$dst" ] && echo directory || echo file ) is already there (a copied install)."
      echo "        It may have local edits, so it is left alone. Re-run with --force to move it aside."
      BLOCKED=$((BLOCKED+1)); return 0
    fi
    local n=1; while [ -e "$dst.bak-$n" ]; do n=$((n+1)); done
    mv "$dst" "$dst.bak-$n" || { echo "  FAILED to move $dst aside" >&2; return 1; }
    echo "  MOVED $name -> $(basename "$dst").bak-$n   (nothing deleted)"
    MOVED=$((MOVED+1))
  fi
  ln -s "$src" "$dst" || { echo "  FAILED to link $name" >&2; return 1; }
  # NAME EACH ONE. "linked 7" is a number a first-time installer cannot check anything against;
  # a missing entry looks identical to a present one. The list is what lets somebody see that
  # the short forms (/mc, /backlog) arrived, which is the half people skip when copying.
  echo "  linked $name"
  LINKED=$((LINKED+1))
}

targets() {                     # emit "src<TAB>dst" for everything this repo ships
  local d f
  for d in "$SRC"/skills/*/; do [ -d "$d" ] && printf '%s\t%s\n' "${d%/}" "$SKILLS_DST/$(basename "${d%/}")"; done
  for f in "$SRC"/commands/*.md; do [ -f "$f" ] && printf '%s\t%s\n' "$f" "$CMDS_DST/$(basename "$f")"; done
}

if [ "$MODE" = "--check" ]; then
  echo "checkout: $SRC"
  while IFS=$'\t' read -r src dst; do
    n=$(basename "$dst")
    if ours "$dst" && [ "$(readlink "$dst")" = "$src" ]; then echo "  linked   $n"
    elif [ -L "$dst" ]; then                       echo "  FOREIGN  $n -> $(readlink "$dst")"
    elif [ -e "$dst" ]; then                       echo "  copied   $n   (git pull will NOT update this)"
    else                                           echo "  missing  $n"; fi
  done < <(targets)
  exit 0
fi

if [ "$MODE" = "--uninstall" ]; then
  while IFS=$'\t' read -r src dst; do
    if ours "$dst"; then rm -f "$dst"; echo "  unlinked $(basename "$dst")"; REMOVED=$((REMOVED+1))
    elif [ -e "$dst" ]; then echo "  kept     $(basename "$dst") — not a link into this checkout, so not ours to remove"; fi
  done < <(targets)
  echo "removed $REMOVED symlink(s). Nothing else was touched."
  exit 0
fi

mkdir -p "$SKILLS_DST" "$CMDS_DST"
while IFS=$'\t' read -r src dst; do place "$src" "$dst"; done < <(targets)

echo ""
echo "linked $LINKED · already correct $SKIPPED · moved aside $MOVED · left alone $BLOCKED"
echo "  $SKILLS_DST"
echo "  $CMDS_DST"
if [ "$BLOCKED" -gt 0 ]; then
  echo ""
  echo "SOME ENTRIES WERE LEFT ALONE, and they are still running their old copies —"
  echo "a git pull will not reach them. Re-run with --force to move those aside and link."
else
  echo ""
  echo "From here, \`git pull\` in this checkout IS the update. Nothing to copy."
fi
echo ""
echo "Optional, and the one thing that cannot be fixed later: make a bare \`claude\` come up"
echo "already named as the coordinator, so Control's messages carry its call-sign from the first"
echo "one. It writes one line to your shell profile, so it is never done for you:"
echo "  bash '$SRC/skills/mission-control/control-shell-hook.sh' --install"
