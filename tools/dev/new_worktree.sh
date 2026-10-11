#!/usr/bin/env bash
# Crée un worktree isolé pour un module : /home/user/wt/<nom> sur la branche wip/<nom>, depuis la branche d'intégration,
# puis importe les assets (cache .godot local au worktree).   Usage : tools/dev/new_worktree.sh <nom>
set -e
name="$1"; [ -n "$name" ] || { echo "usage: $0 <nom>"; exit 1; }
repo=/home/user/trajectoire
dst=/home/user/wt/$name
base=${BASE:-claude/friendly-shannon-mkzhif}
mkdir -p /home/user/wt
if [ -d "$dst" ]; then echo "existe déjà : $dst"; exit 0; fi
git -C "$repo" worktree add -q -b "wip/$name" "$dst" "$base"
# les assets binaires ne changent pas : on recopie le cache d'import du dépôt principal s'il existe (gain de temps)
if [ -d "$repo/.godot/imported" ]; then mkdir -p "$dst/.godot" && cp -r "$repo/.godot/imported" "$dst/.godot/" ; fi
find "$repo/assets" -name '*.import' | while read -r f; do rel=${f#$repo/}; [ -f "$dst/$rel" ] || cp "$f" "$dst/$rel"; done
cd "$dst" && "$repo/tools/dev/gd" --headless --path . --import > /tmp/import-$name.log 2>&1 || true
echo "worktree prêt : $dst (branche wip/$name)"
