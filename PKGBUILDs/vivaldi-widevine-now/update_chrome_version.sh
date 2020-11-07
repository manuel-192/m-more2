#!/bin/bash

printf2() { printf "$@" >&2 ; }

DIE() {
    printf2 "Error: %s\n" "$1"
    exit 1
}

ShowChanges() {
    local pkg="$1"
    local current="$2"
    local new="$3"     # optional

    if [ -z "$new" ] ; then
        printf2 "===> %-25s: OK (%s)\n" "$pkg" "$current"
    else
        printf2 "===> %-25s: %s --> %s\n" "$pkg" "$current" "$new"
    fi
}

CheckChromeChanges() {

    # Check latest google-chrome-stable version

    # Get chrome channel
    local ChromeChannel="$(awk -F '=' '/^_channel/{ print $2 }' PKGBUILD)"
    [ -n "$ChromeChannel" ] || DIE "no '_channel' in PKGBUILD"
    local Pkg="google-chrome-$ChromeChannel"

    # Get latest version
    LatestChrome=$(
        curl -sSf https://dl.google.com/linux/chrome/deb/dists/stable/main/binary-amd64/Packages |
            grep -A1 "^Package: $Pkg" |
            grep ^Version: |
            awk '{print $2}' | cut -d '-' -f1
          )
    [ -n "$LatestChrome" ] || DIE "latest $Pkg version unavailable!"

    local CurrentChrome="$(grep "^_chrome_ver=" PKGBUILD | cut -d '=' -f2)"

    if [ "$LatestChrome" != "$CurrentChrome" ] ; then
        ShowChanges "$Pkg" "$CurrentChrome" "$LatestChrome"
        return 1
    else
        ShowChanges "$Pkg" "$CurrentChrome" ""
        return 0
    fi
}

Yes() {
    local prompt="$1"
    printf2 "\n"
    read -p "$prompt (Y/n)? " >&2
    case "$REPLY" in
        ""|[Yy]*) return 0 ;;
        *)        return 1 ;;
    esac
}

Makepkg() {
    # Update .SRCINFO
    #makepkg --printsrcinfo >.SRCINFO

    Yes "Build package" || return 1
    makepkg -cf
}

Gitupdate() {
    # Commit changes
    Yes "Commit to git version control" || return 1
    git add PKGBUILD # .SRCINFO
    git commit -m "${Pkg} v${LatestChrome}"
}

UpdatePkgbuild() {
    Yes "Update PKGBUILD" || return 1
    sed -i PKGBUILD \
        -e "s/^_chrome_ver=.*/_chrome_ver=${LatestChrome}/" \
        -e 's/^pkgrel=.*/pkgrel=1/'
    updpkgsums
}

Main() {
    set -euo pipefail
    local LatestChrome=0
    if (! CheckChromeChanges) ; then
        if (UpdatePkgbuild) ; then
            Makepkg && Gitupdate
        fi
    fi
}

Main "$@"
