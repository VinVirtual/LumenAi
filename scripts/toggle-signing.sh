#!/usr/bin/env bash
# Toggle between free Personal Team signing (no paid capabilities)
# and paid Apple Developer Program signing (full capabilities).
#
# Usage:
#   ./scripts/toggle-signing.sh free    # strip paid capabilities
#   ./scripts/toggle-signing.sh paid    # restore paid capabilities
#   ./scripts/toggle-signing.sh status  # show current mode

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENT_PAIRS=(
  "App/Lumen.entitlements"
  "Widgets/LumenWidgets.entitlements"
  "NotificationService/LumenNotificationService.entitlements"
)

case "${1:-status}" in
  status)
    if grep -q "applesignin" App/Lumen.entitlements 2>/dev/null; then
      echo "Current mode: PAID (Apple Developer Program required)"
    else
      echo "Current mode: FREE (Personal Team signing)"
    fi
    ;;
  free)
    for f in "${ENT_PAIRS[@]}"; do
      [[ -f "$f.paid-backup" ]] || cp "$f" "$f.paid-backup"
    done
    cat > App/Lumen.entitlements <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array><string>$(APP_GROUP_ID)</string></array>
</dict>
</plist>
EOF
    cat > Widgets/LumenWidgets.entitlements <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array><string>$(APP_GROUP_ID)</string></array>
</dict>
</plist>
EOF
    cat > NotificationService/LumenNotificationService.entitlements <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array><string>$(APP_GROUP_ID)</string></array>
</dict>
</plist>
EOF
    xcodegen generate >/dev/null
    echo "✓ Switched to FREE Personal Team mode (paid capabilities stripped)"
    echo "  Run xcodebuild or hit ⌘R in Xcode."
    ;;
  paid)
    for f in "${ENT_PAIRS[@]}"; do
      if [[ -f "$f.paid-backup" ]]; then
        cp "$f.paid-backup" "$f"
      else
        echo "warn: no backup found for $f — leaving as-is" >&2
      fi
    done
    xcodegen generate >/dev/null
    echo "✓ Switched to PAID Apple Developer Program mode"
    echo "  Make sure your Team ID is in .env and run ./scripts/sync-secrets.sh first."
    ;;
  *)
    echo "Usage: $0 {free|paid|status}" >&2
    exit 1
    ;;
esac
