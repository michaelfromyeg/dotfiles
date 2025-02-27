#!/usr/bin/env bash

# Put the dock back on my main monitor.

osascript <<EOF
tell application "System Settings"
    activate
    delay 1
    tell application "System Events"
        click menu item "Displays" of menu "View" of menu bar 1 of application process "System Settings"
        delay 1

        # Find and click on the Dock & Menu Bar section
        set displayGroup to group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window "Displays" of application process "System Settings"

        # Look for the Dock location and click to toggle it
        repeat with aGroup in UI elements of displayGroup
            if exists button "Dock" of aGroup then
                click button "Dock" of aGroup
                exit repeat
            end if
        end repeat
    end tell

    delay 0.5
    quit
end tell
EOF

# Restart the Dock to apply changes
killall Dock
