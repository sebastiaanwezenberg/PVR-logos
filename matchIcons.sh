#!/bin/bash
# matchIcons.sh, dk@diddle-online.de, 20140227
#
# Takes a Tvheadend configuration and a directory containing channel icons, scans
# the channels in the config and tries to match them to the icon file names, creates
# symlinks in the icon directory for non-exact matches, writes file:// URLs to the
# configuration. 
# The orignal channel configuration is NOT touched by default. Instead we work on 
# a copy that needs to be moved into place manually before restarting Tvheadend.
#
# Tested only on recent Tvheadend 3.9.x versions (dvb rewrite)!
# Feedback welcome!
#

# config section

htsconf="/home/hts/.hts/tvheadend"
newchannel="$htsconf/channel.new$$"
icondir="/home/hts/channelicons"

[ "$1" = "-c" ] && clear=1

# function secion

function simplify {
	simple=$(echo "$1" | sed -e 's/[^a-zA-Z0-9]//g' -e 's/\(.*\)/\L\1/' -e 's/.*\///')

	echo "$simple"
}

function exist {
	[ -f "$1" -o -h "$1" ]
}


function name2icon {
	typeset icon=""
	while [ -n "$1" -a -z "$icon" ]; do
	        simplename=$(simplify "$1")
		icon=$(echo "$iconlist" | awk -F'\t' -vname="$simplename" '{if ($2==name) print $1;}' | head -1)
		shift
	done
	echo "$icon"
}

function service2name {
	grep '"svcname"' "$htsconf/input/linuxdvb/networks/"*"/muxes/"*"/services/$1" |
	awk -F\" '{print $4}' |
	sed -e 's/[ /:\\<>|*?'"'"'"][ /:\\<>|*?'"'"'"]*/-/g'
	#sed -e 's/\//-/g'/-/g'
}

function patchicon {
	channelfile="$1"
	iconfile="$2"

	exist "$channelfile" || return

	if [ -n "$iconfile" ]; then
		exist "$iconfile" || return
		url=$(echo "file://$iconfile" | sed -e 's/"/\\"/g')
	else
		url=""
	fi
	
	savetxt=$(grep -v -Ee '{|}|"icon"' "$channelfile")
	echo '{' >"$channelfile"
	[ -n "$url" ] && echo "        \"icon\": \"$url\"," >>"$channelfile"
	echo "$savetxt" >>"$channelfile"
	echo '}' >>"$channelfile"
}

############## MAIN

[ -d "$newchannel" ] && echo "$newcchannel exists!" && exit 1

echo "Copying current channel dir to $newchannel..."
cp -rp "$htsconf/channel" "$newchannel" || exit 1

echo "Scanning $icondir..."
iconlist=$(
	ls -1 "$icondir" | 
	while read line; do
		if [[ "$icondir/$line" == *.png ]] && exist "$icondir/$line"; then
			printf "%s\t%s\n" "$line" $(simplify "${line%.png}") 
			printf . >&2
		fi
	done
	echo >&2
)
#echo "$iconlist" && exit 0

ls -1 "$newchannel/"* |
while read channelfile; do
	exist "$channelfile" || continue

	if [ "$clear" = "1" ]; then
		patchicon "$channelfile" ""
		continue
	fi

	name=$(service2name $(grep -A 1 '"services"' "$channelfile" | tail -1 | awk -F\" '{print $2}'))
	#icon=$(name2icon "${name% [hH][dD]}" "${name/[hH][dD]//}" "$name")
	icon=$(name2icon "$name" "${name/[hH][dD]//}")

	echo "Processing '$name'..."
	if exist "$icondir/$icon"; then
		if ! exist "$icondir/$name.png"; then
			echo "  Creating symlink $icondir/$name.png -> $icondir/$icon"
			ln -sf "$icondir/$icon" "$icondir/$name.png"
		fi
		echo "  Setting URL 'file://$icondir/$name.png'..."
		patchicon "$channelfile" "$icondir/$name.png"
	else
		echo "  No icon found for '$name'."
	fi
done

echo "
Finished creating $newchannel.
Next steps: move in place and restart tvheadend.
Enjoy!
"
