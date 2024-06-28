#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1091

#// set variables

scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

#//functions

fn_hyprlock() {
    if [[ $(playerctl status) == Playing ]]; then
        hyprlock --config "${confDir}/hyprlock/presets/hyprlock_music.conf"
    elif [[ $(playerctl status) == Paused ]]; then
        hyprlock --config "${confDir}/hyprlock/presets/hyprlock_music_paused.conf"
    else
        hyprlock --config "${confDir}/hyprlock/presets/hyprlock_no_music.conf"
    fi
}

replace_lockfile_in_background() {
    local file=$1
    local wallpaper_path=$2
    local tmp_file

    # Erstellen einer temporären Datei
    tmp_file=$(mktemp)

    # Verwenden von awk, um die Datei zu bearbeiten
    awk -v wallpaper_path="$wallpaper_path" '
    # Wenn die Zeile $lockFile = enthält, ersetze den Pfad
    /\$lockFile =/ { sub(/=.*/, "= \"" wallpaper_path "\""); }
    # Drucke jede Zeile (modifiziert oder unverändert)
    { print }
    ' "$file" >"$tmp_file" && mv "$tmp_file" "$file"
}

fn_background() {
    local wallpaper_path
    wallpaper_path=$(swww query | grep -oP '(?<=image: ).*' | head -n 1)

    # Ersetze lockFile in den Konfigurationsdateien
    replace_lockfile_in_background "${confDir}/hypr/hyprlock.conf" "$wallpaper_path"
    for file in "${confDir}/hyprlock/presets"/*; do
        replace_lockfile_in_background "$file" "$wallpaper_path"
    done
}

fn_mpris() {
    local thumb
    thumb="${cacheDir}/mpris"
    { playerctl metadata --format '{{title}}   {{artist}}' && mpris_thumb; } || { rm -f "${thumb}*" && exit 1; }
}

# Generate thumbnail for mpris
mpris_thumb() {
    local artUrl
    artUrl=$(playerctl metadata --format '{{mpris:artUrl}}')
    [[ "${artUrl}" = "$(cat "${thumb}.inf")" ]] && return 0

    printf "%s\n" "$artUrl" >"${thumb}.inf"

    curl -so "${thumb}.png" "$artUrl"
    pkill -USR2 hyprlock # updates the mpris thumbnail
}

# Funktion zum auswählen der hyprlock Konfiguration
main() {
    while getopts ":hbm" opt; do
        case $opt in
        h)
            fn_hyprlock
            ;;
        b)
            fn_background
            ;;
        m)
            fn_mpris
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            exit 1
            ;;
        esac
    done
}

main "$@"
