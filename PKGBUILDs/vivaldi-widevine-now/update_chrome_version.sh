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
    local new="$3"
    ShowAny "$(printf "%-20s: %s --> %s" "$pkg" "$current" "$new")"
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

CheckWidevineChanges2() {
    UpdatePkgbuild
    source PKGBUILD
    bsdtar -xf $_chrome_bin data.tar.xz
    prepare
    pkgver
    rm -rf WidevineCdm
    rm -f data.tar.xz $_chrome_bin
}

CheckWidevineChanges() {
    local current=$(grep "^pkgver=" PKGBUILD | cut -d '=' -f 2)
    local new=$(CheckWidevineChanges2)

    if [ "$new" != "$current" ] ; then
        sed -i PKGBUILD \
            -e "s/^pkgver=.*/pkgver=${new}/"
        ShowChanges "$Pkgname" "$current" "$new"
    fi
}

CheckChromeChanges() {
    if [ "$LatestChrome" != "$CurrentChrome" ] ; then
        should_update_git=yes
        [ "$1" = "yes" ] && ShowChanges "$ChromePkg" "$CurrentChrome" "$LatestChrome"
        CheckWidevineChanges
    fi
}

Makepkg() {
    ShowAny "$ChromePkg: building package ..."
    makepkg -cf
}

Gitupdate() {
    if [ "$should_update_git" = "yes" ] ; then
       ShowAny ": update git ..."
       git add PKGBUILD
       git commit -m "."
    fi
}

UpdatePkgbuild() {
    #ShowAny "$ChromePkg: updating PKGBUILD ..."
    sed -i PKGBUILD \
        -e "s/^_chrome_ver=.*/_chrome_ver=${LatestChrome}/" \
        -e 's/^pkgrel=.*/pkgrel=1/'
    updpkgsums 2>/dev/null
    Verify256sum
}

Execute() {
    case "$1" in
        updtest)  UpdatePkgbuild ;;
        show)     CheckChromeChanges yes ;;
        update)   CheckChromeChanges no ;;
        build)    Makepkg ;;
        git)      Gitupdate ;;
        usage)    printf2 "Usage: $progname {show|update|build|git}\n" ;;
        *) DIE "unsupported command '$1'" ;;
    esac
}

Main() {
    local op="$1"
    local progname=$(basename "$0")
    local Pkgname=vivaldi-widevine-now
    local should_update_git=no
    set -euo pipefail

    local ChromeChannel="$(awk -F '=' '/^_channel/{ print $2 }' PKGBUILD)"
    [ -n "$ChromeChannel" ] || DIE "no '_channel' in PKGBUILD"
    local ChromePkg="google-chrome-$ChromeChannel"
    local CurrentChrome="$(ChromeVersionCurrent)"
    local chromeurl=https://dl.google.com/linux/chrome/deb/dists/$ChromeChannel/main/binary-amd64/Packages
    local PkgInfo="$(curl -sSf "$chromeurl")"
    [ -n "$PkgInfo" ] || DIE "latest $ChromePkg info unavailable!"
    local LatestChrome="$(ChromeVersionLatest "$ChromePkg")"
    [ -n "$LatestChrome" ] || DIE "latest $ChromePkg version unavailable!"

    Execute "$op"
}

Main "$@"
