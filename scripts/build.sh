#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
app="dist/Machenike Control.app"
bundle_id="${MACHENIKE_BUNDLE_ID:-io.github.machenikecontrol.app}"
[[ "$bundle_id" =~ ^[A-Za-z0-9.-]+$ ]] || { print -u2 "Invalid bundle identifier"; exit 1; }
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -swift-version 5 -O Sources/Security.swift Sources/Hardware.swift Sources/OnboardKeys.swift Sources/Keys.swift Sources/Shortcuts.swift Sources/Configuration.swift Sources/Model.swift Sources/Diagram.swift Sources/Theme.swift Sources/TargetEditor.swift Sources/KeyboardPage.swift Sources/ContentView.swift Sources/App.swift -o "$app/Contents/MacOS/MachenikeControl" -framework SwiftUI -framework AppKit -framework IOKit
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MachenikeControl</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleName</key><string>Machenike Control</string>
<key>CFBundleDisplayName</key><string>Machenike Control</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSInputMonitoringUsageDescription</key><string>Acceder al teclado Machenike conectado por USB para leer y configurar iluminación RGB.</string>
</dict></plist>
PLIST
codesign --force --sign - "$app"
print "Compilada: $PWD/$app"
