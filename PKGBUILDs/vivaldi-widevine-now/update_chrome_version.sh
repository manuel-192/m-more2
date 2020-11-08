#!/bin/bash

printf2() { printf "$@" >&2 ; }

DIE() {
    printf2 "Error: %s\n" "$1"
    Execute usage
    exit 1
}

ShowAny() {
    printf2 "===> %s\n" "$1"
}

ShowChanges() {
    local pkg="$1"
    local current="$2"
    local new="$3"     # optional

    if [ -z "$new" ] ; then
        ShowAny "$(printf "%-25s: OK (%s)" "$pkg" "$current")"
    else
        ShowAny "$(printf "%-25s: %s --> %s" "$pkg" "$current" "$new")"
    fi
}

ChromeVersionCurrent() {
    grep "^_chrome_ver=" PKGBUILD | cut -d '=' -f2
}

ChromeVersionLatest() {
    local pkg="$1"
    echo "$PkgInfo" | grep -A1 "^Package: $pkg" | grep ^Version: | awk '{print $2}' | cut -d '-' -f1
}

Verify256sum() {
    local ChromeSum="$(echo "$PkgInfo" | grep -A2 "^Filename: .*/google-chrome-$ChromeChannel" | grep "^SHA256:" | awk '{print $2}')"
    local pkgsum=$(grep ^sha256sums= PKGBUILD | sed "s|^.*'\([^']*\)'.*|\1|")
    if [ "$ChromeSum" != "$pkgsum" ] ; then
        printf2 "ERROR: sha256 sums don't match!\n"
        return 1
    fi
}

CheckChromeChanges() {
    if [ "$LatestChrome" != "$CurrentChrome" ] ; then
        ShowChanges "$Pkg" "$CurrentChrome" "$LatestChrome"
        return 1
    else
        [ "$1" = "yes" ] && ShowChanges "$Pkg" "$CurrentChrome" ""
        return 0
    fi
}

Makepkg() {
    ShowAny "$Pkg: building package ..."
    makepkg -cf
}

Gitupdate() {
    ShowAny "$Pkg: update git ..."
    git add PKGBUILD
    git commit -m "."
}

UpdatePkgbuild() {
    ShowAny "$Pkg: updating PKGBUILD ..."
    sed -i PKGBUILD \
        -e "s/^_chrome_ver=.*/_chrome_ver=${LatestChrome}/" \
        -e 's/^pkgrel=.*/pkgrel=1/'
    updpkgsums
    Verify256sum
}

Execute() {
    case "$1" in
        updtest)  UpdatePkgbuild ;;
        show)     CheckChromeChanges yes ;;
        update)   CheckChromeChanges no || UpdatePkgbuild ;;
        build)    Makepkg ;;
        git)      Gitupdate ;;
        usage)    printf2 "Usage: $progname {show|update|build|git}\n" ;;
        *) DIE "unsupported command '$1'" ;;
    esac
}

Main() {
    local op="$1"
    local progname=$(basename "$0")
    set -euo pipefail

    local ChromeChannel="$(awk -F '=' '/^_channel/{ print $2 }' PKGBUILD)"
    [ -n "$ChromeChannel" ] || DIE "no '_channel' in PKGBUILD"
    local Pkg="google-chrome-$ChromeChannel"
    local CurrentChrome="$(ChromeVersionCurrent)"
    local chromeurl=https://dl.google.com/linux/chrome/deb/dists/$ChromeChannel/main/binary-amd64/Packages
    local PkgInfo="$(curl -sSf "$chromeurl")"
    [ -n "$PkgInfo" ] || DIE "latest $Pkg info unavailable!"
    local LatestChrome="$(ChromeVersionLatest "$Pkg")"
    [ -n "$LatestChrome" ] || DIE "latest $Pkg version unavailable!"

    Execute "$op"
}

Main "$@"
