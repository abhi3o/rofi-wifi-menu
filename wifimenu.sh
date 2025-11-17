#!/usr/bin/env bash

## Author: Abhishek Bhagwat
## Gitlab: @abhi3o

# Purpose: rofi based Wi-FI menu to enable/disable wifi, or connect to an AP
# Dependencies: rofi, nmcli

# Bug: SSIDs with --,WEP,WPA in name with spaces cannot be handled correctly
# For example, AP with SSID: 'Home WiFi WPA' cannot be handled

wifimenu() {
  rofi -dmenu \
  	-config ./wifimenu.rasi \
  	-no-lazy-grab \
  	"$@"
}

STATE=$(nmcli radio wifi)

# Only proceed if the Wi-Fi is enabled
if [[ "$STATE" == "enabled" ]]; then
	TOGGLE="toggle off"

	# Get a list of available APs without the connection IN-USE
	LIST=$(nmcli --fields IN-USE,SSID,SECURITY,SIGNAL device wifi list | sed "s/^IN-USE\s//g" | sed '/*/d' | sed 's/^ *//')

	# For some reason rofi always approximates character width 2 short... hmmm
	# Source: https://github.com/zbaylin/rofi-wifi-menu/
	export WIDTH=$(($(echo "$LIST" | head -n 1 | awk '{print length($0); }')+2))ch

	# Limit the length of the menu to 7 lines
	if [ "$(echo "$LIST" | wc -l)" -gt 6 ]; then
		LINES=7
	else
		LINES=$(($(echo "$LIST" | wc -l)+1))
	fi

	SROW=$(echo -e "$TOGGLE\n$LIST" | wifimenu -i -no-custom -p "Wi-Fi SSID" -l "$LINES" -theme-str 'window {width: ${WIDTH};}')

	# Only proceed if a row is selected, so as to not interrupt the current connection
	if [[ -n "$SROW" ]]; then
		SNAME=$(echo "$SROW" | sed 's/\s\+\(--\|WEP\|WPA\).*//')

		# Toggle Wi-Fi OFF
		if [[ "$SROW" == "$TOGGLE" ]]; then
			nmcli radio wifi off

		# Check and connect if the connection already exists
		elif [[ -n $(nmcli --fields NAME connection show | grep "$SNAME") ]]; then
			nmcli connection up id "$SNAME"

		# Handle a new connection
		else

			# Connect directly if the AP is OPEN
			if [[ "$SROW" =~ "--" ]]; then
				nmcli device wifi connect "$SNAME"

			# Connect to the secure AP after a password input
			else
				PASSWORD=$(wifimenu -password -p "Password" -l 0 -theme-str 'window {width: ${WIDTH};}')

				# Attempt to connect to the AP with the password entered
				if [[ -n "$PASSWORD" ]]; then
					nmcli device wifi connect "$SNAME" password "$PASSWORD"

				# Exit if the password is a null string, so as to not interrupt the current connection
				else
					exit 0
				fi
			fi
		fi

	# Exit if no row is selected, so as to not interrupt the current connection
	else
		exit 0
	fi

# Only toggle ON option if the Wi-Fi is disabled
else
	ROW=$(echo "toggle on" | wifimenu -p "Wi-Fi" -l 1 -theme-str 'window {width: 28ch;}')

	if [[ "$ROW" == "toggle on" ]]; then
		nmcli radio wifi on
	fi
fi
