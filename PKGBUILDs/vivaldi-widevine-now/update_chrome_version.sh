#!/bin/bash

printf2() { printf "$@" >&2 ; }

DIE() {
    printf2 "Error: %s\n" "$1"
    exit 1
}

Main() {
    set -euo pipefail

    # Check latest google-chrome-stable version

    # Get chrome channel
    local ChromeChannel="$(awk -F '=' '/^_channel/{ print $2 }' PKGBUILD)"
    [ -n "$ChromeChannel" ] || DIE "no '_channel' in PKGBUILD"
    local Pkg="google-chrome-$ChromeChannel"

    # Get latest version
    local LatestChrome=$(
        curl -sSf https://dl.google.com/linux/chrome/deb/dists/stable/main/binary-amd64/Packages |
            grep -A1 "^Package: google-chrome-$ChromeChannel" |
            grep ^Version: |
            awk '{print $2}' | cut -d '-' -f1
          )
    [ -n "$LatestChrome" ] || DIE "latest $Pkg version unavailable!"

    local CurrentChrome="$(grep "^_chrome_ver=" PKGBUILD | cut -d '=' -f2)"

    [ "$LatestChrome" = "$CurrentChrome" ] && {
        printf2 "===> Package ${Pkg} has most recent version ${LatestChrome}\n"
        return
    }

    printf2 "$Pkg changed from $CurrentChrome to $LatestChrome.\n"

    # Insert latest chrome version into PKGBUILD and update hashes
    sed -i PKGBUILD \
        -e "s/^_chrome_ver=.*/_chrome_ver=${LatestChrome}/" \
        -e 's/pkgrel=.*/pkgrel=1/'

    updpkgsums
    makepkg -cf

    printf2 "\n===> PKGBUILD updated. Please update with git.\n"

    # Update .SRCINFO
    #makepkg --printsrcinfo >.SRCINFO

    # Commit changes
    #git add PKGBUILD .SRCINFO
    #git commit -m "${Pkg} v${LatestChrome}"
}

Main "$@"
