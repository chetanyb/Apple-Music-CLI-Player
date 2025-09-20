#!/bin/zsh

# Scrolling text function
scroll_text() {
	local text="$1"
	local max_width="$2"
	local scroll_speed="${3:-1}"  # Default scroll speed (frames per character)
	
	# If text is shorter than max width, just return it padded
	if [ ${#text} -le $max_width ]; then
		printf "%-${max_width}s" "$text"
		return
	fi
	
	# Calculate scroll position based on frame counter - make it much faster
	local frame_counter=${4:-0}
	local scroll_pos=$((frame_counter * 4))  # Move 4 characters per frame
	local text_length=${#text}
	
	# Create a circular text by repeating the text with spaces for smooth transition
	local circular_text="${text}    "  # Add spaces for smooth transition
	local circular_length=${#circular_text}
	
	# Use modulo to create truly continuous scrolling (no reset to 0)
	scroll_pos=$((scroll_pos % circular_length))
	
	# Extract the visible portion from circular text
	local visible_text="${circular_text:$scroll_pos:$max_width}"
	
	# If we don't have enough characters, wrap around
	if [ ${#visible_text} -lt $max_width ]; then
		local remaining=$((max_width - ${#visible_text}))
		local wrap_text="${circular_text:0:$remaining}"
		visible_text="${visible_text}${wrap_text}"
	fi
	
	# Ensure we always return exactly max_width characters
	printf "%-${max_width}s" "$visible_text"
}

np(){
	init=1
	help='false'
	square_mode='false'
	scroll_frame=0
	# Default size (can be overridden with -s small, -s large, -s xl, -s square)
	art_width=31
	art_height=14

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
			-s)
				if [ "$2" != "" ]; then
					case "$2" in
						"small")
							art_width=25
							art_height=12
							shift 2
							;;
						"large")
							art_width=45
							art_height=20
							shift 2
							;;
						"xl")
							art_width=60
							art_height=28
							shift 2
							;;
						"square")
							art_width=35
							art_height=18
							square_mode='true'
							shift 2
							;;
						*)
							echo "Invalid size option. Use: small, large, xl, square"
							return
							;;
					esac
				else
					echo "Size option requires an argument"
					return
				fi
				;;
			-t)
				# Text mode flag - will be handled later
				shift
				;;
			*)
				# Unknown option, keep for compatibility
				break
				;;
		esac
	done
	while :
	do
		# Increment scroll frame counter for scrolling text
		scroll_frame=$((scroll_frame + 1))
		
		vol=$(osascript -e 'tell application "Music" to get sound volume')
		shuffle=$(osascript -e 'tell application "Music" to get shuffle enabled')
		repeat=$(osascript -e 'tell application "Music" to get song repeat')
	    keybindings="
Keybindings:

p                       Play / Pause
f                       Forward one track
b                       Backward one track
>                       Begin fast forwarding current track
<                       Begin rewinding current track
R                       Resume normal playback
+                       Increase Music.app volume 5%
-                       Decrease Music.app volume 5%
s                       Toggle shuffle
r                       Toggle song repeat
q                       Quit np
Q                       Quit np and Music.app
?                       Show / hide keybindings

Size options:
np -s small             Use small album art (25x12)
np -s large             Use large album art (45x20)
np -s xl                Use extra large album art (60x28)
np -s square            Use square layout with text below (35x18)
np -t                   Text mode (no album art)"
		duration=$(osascript -e 'tell application "Music" to get {player position} & {duration} of current track')
		arr=(`echo ${duration}`)
		curr=$(cut -d . -f 1 <<< ${arr[-2]})
		currMin=$(echo $(( curr / 60 )))
		currSec=$(echo $(( curr % 60 )))
		if [ ${#currMin} = 1 ]; then
			currMin="0$currMin"
		fi
		if [ ${#currSec} = 1 ]; then
			currSec="0$currSec"
		fi
		if (( curr < 2 || init == 1 )); then
			init=0
			# Reset scroll position when track changes
			scroll_frame=0
			name=$(osascript -e 'tell application "Music" to get name of current track')
			artist=$(osascript -e 'tell application "Music" to get artist of current track')
			record=$(osascript -e 'tell application "Music" to get album of current track')
			end=$(cut -d . -f 1 <<< ${arr[-1]})
			endMin=$(echo $(( end / 60 )))
			endSec=$(echo $(( end % 60 )))
			if [ ${#endMin} = 1 ]
			then
				endMin="0$endMin"
			fi
			if [ ${#endSec} = 1 ]
			then
				endSec="0$endSec"
			fi
			if [ "$1" != "-t" ]
			then
				rm ~/Library/Scripts/tmp*
				osascript ~/Library/Scripts/album-art.applescript
				if [ -f ~/Library/Scripts/tmp.png ]; then
					art=$(clear; viu -b ~/Library/Scripts/tmp.png -w $art_width -h $art_height)
				else
					art=$(clear; viu -b ~/Library/Scripts/tmp.jpg -w $art_width -h $art_height)
				fi
			fi
			cyan=$(echo -e '\e[00;36m')
			magenta=$(echo -e '\033[01;35m')
			nocolor=$(echo -e '\033[0m')
		fi
		if [ $vol = 0 ]; then
			volIcon=🔇
		else
			volIcon=🔊
		fi
		vol=$(( vol / 12 ))
		if [ $shuffle = 'false' ]; then
			shuffleIcon='➡️ '
		else
			shuffleIcon=🔀
		fi
		if [ $repeat = 'off' ]; then
			repeatIcon='↪️ '
		elif [ $repeat = 'one' ]; then
			repeatIcon=🔂
		else
			repeatIcon=🔁
		fi
		volBars='▁▂▃▄▅▆▇'
		volBG=${volBars:$vol}
		vol=${volBars:0:$vol}
		progressBars='▇▇▇▇▇▇▇▇▇'
		percentRemain=$(( (curr * 100) / end / 10 ))
		progBG=${progressBars:$percentRemain}
		prog=${progressBars:0:$percentRemain}
		if [ "$1" = "-t" ]
		then
			clear
			# Use scrolling text for long track names and artist-album info
			scrolled_name=$(scroll_text "$name" 50 8 $scroll_frame)
			scrolled_artist_record=$(scroll_text "$artist - $record" 50 8 $scroll_frame)
			paste <(printf '%s\n' "$scrolled_name" "$scrolled_artist_record" "$shuffleIcon $repeatIcon $(echo $currMin:$currSec ${cyan}${prog}${nocolor}${progBG} $endMin:$endSec)" "$volIcon $(echo "${magenta}$vol${nocolor}$volBG")")
		elif [ $square_mode = 'true' ]
		then
			clear
			# Display album art centered
			printf %s "$art"
			echo ""
			# Display track info below art with scrolling text
			scrolled_name=$(scroll_text "$name" 35 8 $scroll_frame)
			scrolled_artist_record=$(scroll_text "$artist - $record" 35 8 $scroll_frame)
			printf '%s\n' "$scrolled_name"
			printf '%s\n' "$scrolled_artist_record"
			printf '%s\n' "$shuffleIcon $repeatIcon $(echo $currMin:$currSec ${cyan}${prog}${nocolor}${progBG} $endMin:$endSec)"
			printf '%s\n' "$volIcon $(echo "${magenta}$vol${nocolor}$volBG")"
		elif [ $art_width -gt 31 ] || [ $art_height -gt 14 ]
		then
			# For larger custom sizes, display text below album art
			clear
			printf %s "$art"
			echo ""
			# Adjust text width based on album art width
			text_width=$art_width
			if [ $text_width -gt 80 ]; then
				text_width=80
			fi
			# Use scrolling text for long track names and artist-album info
			scrolled_name=$(scroll_text "$name" $text_width 8 $scroll_frame)
			scrolled_artist_record=$(scroll_text "$artist - $record" $text_width 8 $scroll_frame)
			printf '%s\n' "$scrolled_name"
			printf '%s\n' "$scrolled_artist_record"
			printf '%s\n' "$shuffleIcon $repeatIcon $(echo $currMin:$currSec ${cyan}${prog}${nocolor}${progBG} $endMin:$endSec)"
			printf '%s\n' "$volIcon $(echo "${magenta}$vol${nocolor}$volBG")"
		else
			# Default layout for standard size with scrolling text
			scrolled_name=$(scroll_text "$name" 50 8 $scroll_frame)
			scrolled_artist_record=$(scroll_text "$artist - $record" 50 8 $scroll_frame)
			paste <(printf %s "$art") <(printf %s "") <(printf %s "") <(printf %s "") <(printf '%s\n' "$scrolled_name" "$scrolled_artist_record" "$shuffleIcon $repeatIcon $(echo $currMin:$currSec ${cyan}${prog}${nocolor}${progBG} $endMin:$endSec)" "$volIcon $(echo "${magenta}$vol${nocolor}$volBG")")
		fi
		if [ $help = 'true' ]; then
			printf '%s\n' "$keybindings"
		fi
		input=$(/bin/bash -c "read -n 1 -t 1 input; echo \$input | xargs")
		if [[ "${input}" == *"s"* ]]; then
			if $shuffle ; then
				osascript -e 'tell application "Music" to set shuffle enabled to false'
			else
				osascript -e 'tell application "Music" to set shuffle enabled to true'
			fi
		elif [[ "${input}" == *"r"* ]]; then
			if [ $repeat = 'off' ]; then
				osascript -e 'tell application "Music" to set song repeat to all'
			elif [ $repeat = 'all' ]; then
				osascript -e 'tell application "Music" to set song repeat to one'
			else
				osascript -e 'tell application "Music" to set song repeat to off'
			fi
		elif [[ "${input}" == *"+"* ]]; then
			osascript -e 'tell application "Music" to set sound volume to sound volume + 5'
		elif [[ "${input}" == *"-"* ]]; then
			osascript -e 'tell application "Music" to set sound volume to sound volume - 5'
		elif [[ "${input}" == *">"* ]]; then
			osascript -e 'tell application "Music" to fast forward'
		elif [[ "${input}" == *"<"* ]]; then
			osascript -e 'tell application "Music" to rewind'
		elif [[ "${input}" == *"R"* ]]; then
			osascript -e 'tell application "Music" to resume'
		elif [[ "${input}" == *"f"* ]]; then
			osascript -e 'tell app "Music" to play next track'
		elif [[ "${input}" == *"b"* ]]; then
			osascript -e 'tell app "Music" to back track'
		elif [[ "${input}" == *"p"* ]]; then
			osascript -e 'tell app "Music" to playpause'
		elif [[ "${input}" == *"q"* ]]; then
			clear
			exit
		elif [[ "${input}" == *"Q" ]]; then
			killall Music
			clear
			exit
		elif [[ "${input}" == *"?"* ]]; then
			if [ $help = 'false' ]; then
				help='true'
			else
				help='false'
			fi
		fi
		read -sk 1 -t 0.001
	done
}
list(){
	usage="Usage: list [-grouping] [name]

  -s                    List all songs.
  -r                    List all records.
  -r PATTERN            List all songs in the record PATTERN.
  -a                    List all artists.
  -a PATTERN            List all songs by the artist PATTERN.
  -p                    List all playlists.
  -p PATTERN            List all songs in the playlist PATTERN.
  -g                    List all genres.
  -g PATTERN            List all songs in the genre PATTERN."
	if [ "$#" -eq 0 ]; then
		printf '%s\n' "$usage";
	else
		if [ $1 = "-p" ]
		then
			if [ "$#" -eq 1 ]; then
				shift
				osascript -e 'tell application "Music" to get name of playlists' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
			else
				shift
				osascript -e 'on run args' -e 'tell application "Music" to get name of every track of playlist (item 1 of args)' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
			fi
		elif [ $1 = "-s" ]
		then
			if [ "$#" -eq 1 ]; then
				shift
				osascript -e 'on run args' -e 'tell application "Music" to get name of every track' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
			else
				echo $usage
			fi
		elif [ $1 = "-r" ]
		then
			if [ "$#" -eq 1 ]; then
				shift
				osascript -e 'on run args' -e 'tell application "Music" to get album of every track' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
			else
				shift
				osascript -e 'on run args' -e 'tell application "Music" to get name of every track whose album is (item 1 of args)' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
			fi
		elif [ $1 = "-a" ]
		then
			if [ "$#" -eq 1 ]; then
				shift
				osascript -e 'on run args' -e 'tell application "Music" to get artist of every track' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
			else
				shift
				osascript -e 'on run args' -e 'tell application "Music" to get name of every track whose artist is (item 1 of args)' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
			fi
		elif [ $1 = "-g" ]
		then
			if [ "$#" -eq 1 ]; then
				shift
				osascript -e 'on run args' -e 'tell application "Music" to get genre of every track' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
			else
				shift
				osascript -e 'on run args' -e 'tell application "Music" to get name of every track whose genre is (item 1 of args)' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
			fi
		else
			printf '%s\n' "$usage";
		fi
	fi
}

play() {
	usage="Usage: play [-grouping] [name]

  -s                    Fzf for a song and begin playback.
  -s PATTERN            Play the song PATTERN.
  -r                    Fzf for a record and begin playback.
  -r PATTERN            Play from the record PATTERN.
  -a                    Fzf for an artist and begin playback.
  -a PATTERN            Play from the artist PATTERN.
  -p                    Fzf for a playlist and begin playback.
  -p PATTERN            Play from the playlist PATTERN.
  -g                    Fzf for a genre and begin playback.
  -g PATTERN            Play from the genre PATTERN.
  -l                    Play from your entire library."
	if [ "$#" -eq 0 ]; then
		printf '%s\n' "$usage"
	else
		if [ $1 = "-p" ]
		then
			if [ "$#" -eq 1 ]; then
				playlist=$(osascript -e 'tell application "Music" to get name of playlists' | tr "," "\n" | fzf)
				set -- ${playlist:1}
			else
				shift
			fi
			osascript -e 'on run argv
				tell application "Music" to play playlist (item 1 of argv)
			end' "$*"
		elif [ $1 = "-s" ]
		then
			if [ "$#" -eq 1 ]; then
				song=$(osascript -e 'tell application "Music" to get name of every track' | tr "," "\n" | fzf)
				set -- ${song:1}
			else
				shift
			fi
		osascript -e 'on run argv
			tell application "Music" to play track (item 1 of argv)
		end' "$*"
		elif [ $1 = "-r" ]
		then
			if [ "$#" -eq 1 ]; then
				record=$(osascript -e 'tell application "Music" to get album of every track' | tr "," "\n" | sort | awk '!seen[$0]++' | fzf)
				set -- ${record:1}
			else
				shift
			fi
			osascript -e 'on run argv' -e 'tell application "Music"' -e 'if (exists playlist "temp_playlist") then' -e 'delete playlist "temp_playlist"' -e 'end if' -e 'set name of (make new playlist) to "temp_playlist"' -e 'set theseTracks to every track of playlist "Library" whose album is (item 1 of argv)' -e 'repeat with thisTrack in theseTracks' -e 'duplicate thisTrack to playlist "temp_playlist"' -e 'end repeat' -e 'play playlist "temp_playlist"' -e 'end tell' -e 'end' "$*"
		elif [ $1 = "-a" ]
		then
			if [ "$#" -eq 1 ]; then
				artist=$(osascript -e 'tell application "Music" to get artist of every track' | tr "," "\n" | sort | awk '!seen[$0]++' | fzf)
				set -- ${artist:1}
			else
				shift
			fi
			osascript -e 'on run argv' -e 'tell application "Music"' -e 'if (exists playlist "temp_playlist") then' -e 'delete playlist "temp_playlist"' -e 'end if' -e 'set name of (make new playlist) to "temp_playlist"' -e 'set theseTracks to every track of playlist "Library" whose artist is (item 1 of argv)' -e 'repeat with thisTrack in theseTracks' -e 'duplicate thisTrack to playlist "temp_playlist"' -e 'end repeat' -e 'play playlist "temp_playlist"' -e 'end tell' -e 'end' "$*"
		elif [ $1 = "-g" ]
		then
			if [ "$#" -eq 1 ]; then
				genre=$(osascript -e 'tell application "Music" to get genre of every track' | tr "," "\n" | sort | awk '!seen[$0]++' | fzf)
				set -- ${genre:1}
			else
				shift
			fi
			osascript -e 'on run argv' -e 'tell application "Music"' -e 'if (exists playlist "temp_playlist") then' -e 'delete playlist "temp_playlist"' -e 'end if' -e 'set name of (make new playlist) to "temp_playlist"' -e 'set theseTracks to every track of playlist "Library" whose genre is (item 1 of argv)' -e 'repeat with thisTrack in theseTracks' -e 'duplicate thisTrack to playlist "temp_playlist"' -e 'end repeat' -e 'play playlist "temp_playlist"' -e 'end tell' -e 'end' "$*"
		elif [ $1 = "-l" ]
		then
			osascript -e 'tell application "Music"' -e 'play playlist "Library"' -e 'end tell'
		else
			printf '%s\n' "$usage";
		fi
	fi
}

usage="Usage: am.sh [function] [-grouping] [name]

  list -s              	List all songs in your library.
  list -r              	List all records.
  list -r PATTERN       List all songs in the record PATTERN.
  list -a              	List all artists.
  list -a PATTERN       List all songs by the artist PATTERN.
  list -p              	List all playlists.
  list -p PATTERN       List all songs in the playlist PATTERN.
  list -g              	List all genres.
  list -g PATTERN       List all songs in the genre PATTERN.

  play -s               Fzf for a song and begin playback.
  play -s PATTERN       Play the song PATTERN.
  play -r              	Fzf for a record and begin playback.
  play -r PATTERN       Play from the record PATTERN.
  play -a              	Fzf for an artist and begin playback.
  play -a PATTERN       Play from the artist PATTERN.
  play -p              	Fzf for a playlist and begin playback.
  play -p PATTERN       Play from the playlist PATTERN.
  play -g              	Fzf for a genre and begin playback.
  play -g PATTERN       Play from the genre PATTERN.
  play -l              	Play from your entire library.
  
  np                    Open the \"Now Playing\" TUI widget.
                        (Music.app track must be actively
			playing or paused)
  np -t			Open in text mode (disables album art)
  np -s small           Open with small album art (25x12)
  np -s large           Open with large album art (45x20)
  np -s xl              Open with extra large album art (60x28)
  np -s square          Open with square layout and text below (35x18)
 
  np keybindings:

  p                     Play / Pause
  f                     Forward one track
  b                     Backward one track
  >                     Begin fast forwarding current track
  <                     Begin rewinding current track
  R                     Resume normal playback
  +                     Increase Music.app volume 5%
  -                     Decrease Music.app volume 5%
  s                     Toggle shuffle
  r                     Toggle song repeat
  q                     Quit np
  Q                     Quit np and Music.app
  ?                     Show / hide keybindings"
if [ "$#" -eq 0 ]; then
	printf '%s\n' "$usage";
else
	if [ $1 = "np" ]
	then
		shift
		np "$@"
	elif [ $1 = "list" ]
	then
		shift
		list "$@"
	elif [ $1 = "play" ]
	then
		shift
		play "$@"
	else
		printf '%s\n' "$usage";
	fi
fi
