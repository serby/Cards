#!/bin/bash

# Kill all apps
osascript -e 'tell application "System Events" to set quitapps to name of every application process whose background only is false' -e 'repeat with closeall in quitapps' -e 'tell application closeall to quit' -e 'end repeat'

# Wait for apps to close
sleep 5

# Check current Xcode version
current_version=$(xcodebuild -version | head -1 | awk '{print $2}')
echo "Current Xcode version: $current_version"

# Try App Store update first
echo "Attempting App Store update..."
mas upgrade 497799835

# Wait and check if updated
sleep 30
new_version=$(xcodebuild -version | head -1 | awk '{print $2}')

if [[ "$new_version" == "26.2" ]]; then
    echo "Xcode 26.2 installed successfully"
else
    echo "App Store update failed, downloading from Developer portal..."
    # Download Xcode 26.2 directly
    curl -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" \
         -L "https://download.developer.apple.com/Developer_Tools/Xcode_26.2_RC/Xcode_26.2_RC.xip" \
         -o ~/Downloads/Xcode_26.2.xip
    
    # Install from XIP
    cd ~/Downloads
    xip -x Xcode_26.2.xip
    sudo mv Xcode.app /Applications/Xcode.app
    sudo xcode-select -s /Applications/Xcode.app
fi

# Verify installation
final_version=$(xcodebuild -version | head -1 | awk '{print $2}')
echo "Final Xcode version: $final_version"

# Restart system
sudo shutdown -r +1
