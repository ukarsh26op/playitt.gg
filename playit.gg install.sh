cat > ~/playit-setup.sh << 'PLAYIT_END'
#!/usr/bin/env bash
# playit.gg agent: install once, auto-start after every Codespace restart
set -Eeuo pipefail

VER="v0.15.26"
DIR="$HOME/.playit"
BIN="$DIR/playit"
LOG="$DIR/playit.log"
mkdir -p "$DIR"

case "$(uname -m)" in
  x86_64)        ASSET="playit-linux-amd64" ;;
  aarch64|arm64) ASSET="playit-linux-aarch64" ;;
  *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

# ---------- 1. install ----------
if [[ ! -x "$BIN" ]]; then
  echo "[1/3] Downloading playit $VER ($ASSET)..."
  if curl -fL --retry 3 -o "$BIN.tmp" "https://github.com/playit-cloud/playit-agent/releases/download/${VER}/${ASSET}"; then
    mv -f "$BIN.tmp" "$BIN"
    chmod +x "$BIN"
  else
    rm -f "$BIN.tmp"
    echo "Download failed - using the fallback installer..."
    bash <(curl -s https://raw.githubusercontent.com/JishnuTheGamer/Vps/refs/heads/main/playit-ins) || true
    FOUND="$(command -v playit || true)"
    [[ -n "$FOUND" ]] || { echo "Fallback did not install a 'playit' command. Stopping."; exit 1; }
    ln -sfn "$FOUND" "$BIN"
  fi
else
  echo "[1/3] playit already installed"
fi

# ---------- 2. start script (safe to run many times) ----------
echo "[2/3] Creating start script and auto-start hook..."
cat > "$DIR/start.sh" <<STARTEOF
#!/usr/bin/env bash
DIR="$DIR"
BIN="$BIN"
if [[ -f "\$DIR/playit.pid" ]] && kill -0 "\$(cat "\$DIR/playit.pid")" 2>/dev/null; then exit 0; fi
if pgrep -f "\$BIN" >/dev/null 2>&1; then exit 0; fi
if [[ -f "\$DIR/playit.log" && "\$(stat -c%s "\$DIR/playit.log" 2>/dev/null || echo 0)" -gt 1048576 ]]; then : > "\$DIR/playit.log"; fi
nohup "\$BIN" >>"\$DIR/playit.log" 2>&1 &
echo \$! > "\$DIR/playit.pid"
STARTEOF
chmod +x "$DIR/start.sh"

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [[ "$rc" == *zshrc && ! -f "$rc" ]]; then continue; fi
  touch "$rc"
  if ! grep -q 'playit-autostart' "$rc"; then
    printf '\n# playit-autostart\n[ -x "$HOME/.playit/start.sh" ] && (nohup "$HOME/.playit/start.sh" >/dev/null 2>&1 &)\n' >> "$rc"
  fi
done

# ---------- 3. start now ----------
echo "[3/3] Starting playit..."
"$DIR/start.sh"
sleep 6

LINK="$(grep -Eo 'https://playit\.gg/[^ ]+' "$LOG" 2>/dev/null | tail -1 || true)"
echo
if [[ -n "$LINK" ]]; then
  echo "First time? Open this link to claim the agent:"
  echo "  $LINK"
else
  echo "If this is your first run, the claim link will be in the log:"
  echo "  tail -f $LOG"
fi
echo
echo "Log:    tail -f $LOG"
echo "Stop:   kill \$(cat $DIR/playit.pid)"
echo "Start:  $DIR/start.sh"
PLAYIT_END
bash ~/playit-setup.sh
