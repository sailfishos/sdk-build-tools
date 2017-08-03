#!/bin/bash
#
# Collects indirectly available data about packages.
#
# Copyright (C) 2017 Jolla Oy
# Contact: Martin Kampas <martin.kampas@jolla.com>
# All rights reserved.
#
# You may use this file under the terms of BSD license as follows:
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#   * Neither the name of the Jolla Ltd nor the
#     names of its contributors may be used to endorse or promote products
#     derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

set -o nounset
set -o pipefail
shopt -s extglob

OLD_LC_ALL=${LC_ALL:-}
export LC_ALL=C

SELF=$(basename "$0")
____=${SELF//?/ }

OPT_ALL=
OPT_CACHE=
OPT_DEBUG=
OPT_EXCLUDE=
OPT_HUMAN_READABLE=
OPT_INCLUDE=
OPT_MERGE=
OPT_NAMES=()
OPT_NONINTERACTIVE=
OPT_PACKAGE=
OPT_PROJECTS=
OPT_QUIET=
OPT_RPM_SHELL=eval

SEPARATOR=$'\x1f' # ASCII unit separator
read_() { IFS=$SEPARATOR read -r "$@"; }
write_() { ( IFS=$SEPARATOR; echo "$*"); }

# OSC insist being interactive, let it fail if it asks about anything
osc()
{
    command osc "$@" </dev/null
}

# Note that '--debug' is not documented here
synopsis()
{
    cat <<END
usage: $SELF [OPTIONS] {{-a|--all} | [--] NAME...}
   or: $SELF [OPTIONS] --projects {{-a|--all} | [--] NAME...}
   or: $SELF [OPTIONS] {-m|--merge} FILE...

Collects indirectly available data about packages.
END
}

brief_usage()
{
    cat <<END
$(synopsis)

Options overview:
    -c|--cache FILE, -i|--include PROJECTS, -e|--exclude PROJECTS,
    -h|--human-readable, -n|--non-interactive, -p|--package, -q|--quiet,
    -r|--rpm-shell SHELL, -t|--sb2-target TARGET

Pass '--help' for full description.
END
}

usage()
{
    cat <<END
$(synopsis)

Output fields:
    OBS PACKAGE   According to the DISTURL tag stored in the RPM package
    OBS PROJECT   According to the DISTURL tag stored in the RPM package
    VERSION       According to the VERSION tag stored in the RPM package
    SAILFISH URL  According to the _service file on OBS or the OBS package
                  itself if it contains sources directly
    UPSTREAM URL  According to the URL tag stored in the RPM package
    LICENSE       According to the LICENSE tag stored in the RPM package

Options to control mode of operation:
    By default the tool collects indirectly available data for the given (or
    all installed) packages.  Options listed below select from alternative
    modes of operation.

    -m|--merge
        Merge the output of two or more executions of this tool

    --projects
        Print just the list of projects that the packages come from

Options
    -h|--help
        Print this help

    -a|--all
        Consider all installed packages

    -c|--cache FILE
        Use FILE to cache information between executions

    -h|--human-readable
        Provide a human readable output with long lines wrapped

    -i|--include PROJECTS
    -e|--exclude PROJECTS
        By default packages from all OBS projects are included. Use one of
        these options to limit the list of OBS projects to consider. These
        options can be used multiple times. Alternatively multiple projects
        may be listed separated with spaces.

        Use --projects to query all projects of the given (or all installed)
        packages.

    -n|--non-interactive
        Do not ask anything, use default answers automatically. Implied when
        STDIN is not connected to a terminal.

    -p|--package
        Treat each NAME as a package file name

    -q|--quiet
        Do not report progress

    -r|--rpm-shell SHELL
        Use given SHELL command for 'rpm' invocation to query (installed)
        package properties.  SHELL can be an arbitrary shell expression that
        expect single argument - an arbitrary shell expression.  This is the
        behavior of e.g. 'ssh', 'bash -c' or 'su -c'. Note that 'sb2' does not
        comply with this requirement - see '--sb2-target'.

    -t|--sb2-target TARGET
        Shortcut for '--rpm-shell "sb2 -t TARGET -m sdk-install bash -c"'
        (note how 'bash -c' is used to provide the desired argument handling)

    --
        Treat everything after this option as NAME

Example
    The following example shows how to collect data about packages from
    multiple places, caching data fetched over network to speed up operation,
    and merging results into single output file.

    [mersdk@SailfishSDK ~]\$ $SELF --cache cache --all > out.sdk
    [mersdk@SailfishSDK ~]\$ $SELF --cache cache --all \\
        --sb2-target SailfishOS-i486 > out.x86
    [mersdk@SailfishSDK ~]\$ $SELF --cache cache --all \\
        --sb2-target SailfishOS-armv7hl > out.arm
    [mersdk@SailfishSDK ~]\$ $SELF --cache cache --all \\
        --rpm-shell "mb2 -d 'Sailfish OS Emulator' ssh" > out.emu

    [mersdk@SailfishSDK ~]\$ $SELF --merge out.{sdk,x86,arm,emu} > out

    # Do not actually merge, just format for human eyes
    [mersdk@SailfishSDK ~]\$ $SELF --merge out --human-readable |less

END
}

bad_usage()
{
    echo "$*"
    brief_usage
} >&2

fatal()
{
    echo "Fatal: $*" >&2
}

warning()
{
    echo "Warning: $*" >&2
}

info()
{
    if ! [[ $OPT_QUIET ]]; then
        echo "Info: $*" >&2
    fi
}

debug()
{
    if [[ $OPT_DEBUG ]]; then
        echo "Debug: $*" >&2
    fi
}

xpath()
{
    local query=$1
    local file=$2

    xmllint --xpath "$query" "$file"
}

# Prints the given message and asks for action
ask_retry_ignore_abort()
{
    local message=$1

    echo "$message" >&2

    if [[ $OPT_NONINTERACTIVE ]]; then
        echo "Retry? Ignore? Abort? [a]" >&2
        echo abort
        return
    fi

    local reply=
    while true; do
        read -p "Retry? Ignore? Abort? [a] " reply
        case "$reply" in
            [rR])    echo "retry";;
            [iI])    echo "ignore";;
            [aA]|'') echo "abort";;
            *)       continue;;
        esac
        break
    done
}

# Parse URL in format obs://API/PROJECT/PLATFORM/REVISION-PACKAGE (disturl)
parse_disturl()
{
    local url=$1

    [[ $url == obs://* ]] || return

    url=${url#obs://}
    local revision_and_package=${url##*/}
    local revision=${revision_and_package%%-*}
    local package=${revision_and_package#*-}
    url=${url%/*}
    url=${url%/*} # discard platform
    local project=${url##*/}
    url=${url%/*}
    local api=$url

    if [[ $api != @(http|https)://* ]]; then
        api=https://$api
    fi

    write_ "$api" "$project" "$revision" "$package"
}

# For some reason DISTURL contains hostname of the web UI instead of web service API
fixup_apiurl()
{
    local api=$1
    api=${api/build./api.}
    api=${api/http:/https:}

    # TODO this is a (temporary) issue with new infra iiuc
    api=${api/https:\/\/private/https:\/\/api2.jollamobile.com}

    printf "%s" "$api"
}

# Postprocess URL retrieved from tar_git service configuration
fixup_scmurl()
{
    local url=$1

    case $url in
        git://git.merproject.org/*)
            url="${url/git/https}"
            ;;
        ssh://git@git.merproject.org:2222/*)
            url="https://git.merproject.org/${url#*:2222/}"
            ;;
    esac
    url=${url%.git}

    printf "%s" "$url"
}

# Get a link to OBS web page for the given (parsed) disturl
disturl_to_obsurl()
{
    local parsed_disturl=$1

    local api= prj= rev= pkg=
    read_ api prj rev pkg <<<"$parsed_disturl" || return

    printf "%s/package/show?package=%s&project=%s" \
        "$api" "$pkg" "${prj//:/%3A}"
}

# Get a link to SCM web page from the given _service file
service_to_scmurl()
{
    local service_file=$1

    local tar_git_url=
    tar_git_url=$(xpath '//services/service[@name="tar_git"]/param[@name="url"]/text()' \
        "$service_file")
    if [[ ${tar_git_url} ]]; then
        printf "%s" "${tar_git_url}"
        return
    fi

    local gitpkg_service=
    gitpkg_service=$(xpath '//services/service[@name="gitpkg"]/param[@name="service"]/text()' \
        "$service_file")
    if [[ ${gitpkg_service} ]]; then
        local gitpkg_repo=
        gitpkg_repo=$(xpath '//services/service[@name="gitpkg"]/param[@name="repo"]/text()' \
            "$service_file")
        case $gitpkg_service in
            github)
                printf "https://github.com/%s" "$gitpkg_repo"
                ;;
            *)
                fatal "Unknown service '$gitpkg_service' in gitpkg service configuration"
                return 1
                ;;
        esac
        return
    fi

    fatal "No supported OBS service found in the _service file"
    return 1
}

# Get link to sources for the given (parsed) disturl - either SCM or OBS web page
fetch_source_url()
{
    local parsed_disturl=$1

    local service_file=

    fetch_source_url_cleanup() (
        trap 'echo cleaning up...' INT TERM HUP
        [[ -n $service_file ]] && rm -f "$service_file"
    )
    trap 'fetch_source_url_cleanup; trap - RETURN' RETURN
    trap 'return 1' INT TERM HUP

    local api= prj= rev= pkg=
    read_ api prj rev pkg <<< "$parsed_disturl" || return

    api=$(fixup_apiurl "$api") || return

    service_file=$(mktemp) || return

    while true; do
        # Quietly try all options in an EAFP way
        local stderr=
        { stderr=$({
            if osc -A "$api" cat --revision="$rev" "$prj" "$pkg" _service > "$service_file"; then
                service_to_scmurl "$service_file"
                exit
            elif osc -A "$api" ls --revision="$rev" "$prj" "$pkg" >/dev/null; then
                disturl_to_obsurl "$parsed_disturl"
                exit
            else
                exit 1
            fi
        } 3>&1 1>&2 2>&3 3>&-); } 2>&1
        if [[ $? -ne 0 ]]; then
            echo "$stderr" >&2
            case $(ask_retry_ignore_abort \
                "Failed to retrieve contents of package '$prj/$pkg' on '$api'") in
                    retry) continue;;
                    ignore) return 0;;
                    abort) abort; return 1;;
            esac
        else
            break
        fi
    done
}

include_project()
{
    local prj=$1
    [[ ! $OPT_INCLUDE || " $OPT_INCLUDE " == *" $prj "* ]]
}

exclude_project()
{
    local prj=$1
    [[ $OPT_INCLUDE && " $OPT_INCLUDE " != *" $prj "* || " $OPT_EXCLUDE " == *" $prj "* ]]
}

cache=
cache_tmp=
cache_open()
{
    if [[ $OPT_CACHE ]]; then
        cache=$OPT_CACHE
    else
        cache=$(mktemp) || return
    fi

    cache_tmp=$(mktemp) || return

    cache=$(readlink -f "$cache") || return
    : >> "$cache" || return
    head --bytes=0 "$cache" || return
}

cache_close()
{
    if [[ $cache && ! $OPT_CACHE ]]; then
        rm -f "$cache"
    fi
    if [[ $cache_tmp ]]; then
        rm -f "$cache_tmp"
    fi
}

cache_look()
{
    local key=$1
    [[ -s $cache ]] || return 0 # look is verbose about empty files
    local hit=
    hit=$(look --terminate "$SEPARATOR" "$key$SEPARATOR" "$cache")
    if ! [[ $hit ]]; then
        return 0
    fi
    if [[ $(wc -l <<< "$hit") -gt 1 ]]; then
        warning "Ignoring duplicate cache entries for '$key'"
        hit=${hit%%$'\n'*}
    fi
    local values=
    read_ key values <<< "$hit" || return
    printf "%s" "$values"
}

cache_store()
{
    local key=$1 values=(${@:2})
    # Cannot sort on first field only - this would result in different order and break look
    write_ "$key" "${values[@]}" |sort --merge "$cache" - > "$cache_tmp" || return
    cat <"$cache_tmp" >"$cache" || return
}

# Fetch local data, output fields as with 'write_', unique output by disturl
fetch_local()
{
    local disturl= name= version= license= url= garbage=
    local fields=('%{DISTURL}' '%{NAME}' '%{VERSION}' '%{LICENSE}' '%{URL}')
    local rpm_query=$(printf "%q " \
        rpm --query --queryformat "$(printf "%s$SEPARATOR" "${fields[@]}")\n" \
            ${OPT_PACKAGE:+--package} \
            ${OPT_ALL:+--all} \
            ${OPT_NAMES:+"${OPT_NAMES[@]}"})

    eval "$OPT_RPM_SHELL" "\"$rpm_query\"" \
        |while read_ disturl name version license url garbage; do
            if [[ $disturl == "package "*"is not installed" ]]; then
                fatal "$disturl"
                return 1
            fi
            if [[ $garbage ]]; then
                fatal "RPM metadata for '$name' contain \$SEPARATOR character"
                return 1
            fi
            if [[ $disturl == obs://* ]]; then
                write_ "$disturl" "$version" "$license" "$url"
            else
                warning "Ignoring package with invalid DISTURL: $name"
            fi
        done \
        |sort --unique --field-separator="$SEPARATOR" --key=1,1
}

# Fetch remote data for each local data line read from stdin - with caching
fetch_remote()
{
    fetch_cleanup()
    (
        trap 'echo cleaning up...' INT TERM HUP
        cache_close
    )
    trap 'fetch_cleanup; trap - RETURN' RETURN
    trap 'return 1' INT TERM HUP

    cache_open || return

    local disturl= version= license= url= garbage=
    while read_ -u 3 disturl version license url garbage; do
        debug "Processing '$disturl'"
        [[ ! $garbage ]] || return
        local parsed_disturl= api= prj= rev= pkg=
        parsed_disturl=$(parse_disturl "$disturl") || return
        read_ api prj rev pkg <<< "$parsed_disturl" || return

        if exclude_project "$prj"; then
            debug "Excluding '$pkg' from '$prj' on '$api'"
            continue
        fi

        local cached= source_url=
        cached=$(cache_look "$prj/$pkg") || return
        if [[ $cached ]]; then
            debug "Cache hit for '$pkg' ($cached)"
            read_ source_url foo bar <<< "$cached" || return
        else
            info "Fetching remote info for '$pkg'"
            source_url=$(fetch_source_url "$parsed_disturl") || return
            cache_store "$prj/$pkg" "$source_url" || return
        fi

        source_url=$(fixup_scmurl "$source_url")

        write_ >&4 "$pkg" "$prj" "$version" "$source_url" "$url" "$license"
    done
} 3<&0 0</dev/tty 4>&1 1>/dev/tty

sort_output()
{
    sort --field-separator "$SEPARATOR" -k 1,1
}

format()
{
    if [[ $OPT_HUMAN_READABLE ]]; then
        sed "s/$SEPARATOR/\n    /g"
    else
        tr "$SEPARATOR" '|'
    fi
}

merge()
{
    sort -u "${OPT_NAMES[@]}" |tr '|' "$SEPARATOR"
}

list_projects()
{
    local disturl= version= license= url= garbage=
    while read_ disturl version license url garbage; do
        [[ ! $garbage ]] || return
        local parsed_disturl= api= prj= rev= pkg=
        parsed_disturl=$(parse_disturl "$disturl") || return
        read_ api prj rev pkg <<< "$parsed_disturl" || return
        write_ "$api" "$prj"
    done |sort -u
}

##############################################################################
if [[ ${1:-} != --self-test ]]; then  ###  M A I N   S T A R T S   H E R E  ##
##############################################################################

while (( $# > 0 )); do
    case ${1:-} in
        --help)
            usage
            exit 0
            ;;
        -a|--all)
            OPT_ALL=1
            ;;
        -c|--cache)
            if ! [[ ${2:-} ]]; then
                bad_usage "Argument expected after '$1'"
                exit 1
            fi
            OPT_CACHE=$2
            shift
            ;;
        --debug)
            OPT_DEBUG=1
            ;;
        -e|--exclude)
            if ! [[ ${2:-} ]]; then
                bad_usage "Argument expected after '$1'"
                exit 1
            fi
            OPT_EXCLUDE=${OPT_EXCLUDE:+$OPT_EXCLUDE }$2
            shift
            ;;
        -h|--human-readable)
            OPT_HUMAN_READABLE=1
            ;;
        -i|--include)
            if ! [[ ${2:-} ]]; then
                bad_usage "Argument expected after '$1'"
                exit 1
            fi
            OPT_INCLUDE=${OPT_INCLUDE:+$OPT_INCLUDE }$2
            shift
            ;;
        -m|--merge)
            OPT_MERGE=1
            ;;
        -n|--non-interactive)
            OPT_NONINTERACTIVE=1
            ;;
        -p|--package)
            OPT_PACKAGE=1
            ;;
        --projects)
            OPT_PROJECTS=1
            ;;
        -q|--quiet)
            OPT_QUIET=1
            ;;
        -r|--rpm-shell)
            if ! [[ ${2:-} ]]; then
                bad_usage "Argument expected after '$1'"
                exit 1
            fi
            OPT_RPM_SHELL=$2
            shift
            ;;
        -t|--sb2-target)
            if ! [[ ${2:-} ]]; then
                bad_usage "Argument expected after '$1'"
                exit 1
            fi
            OPT_RPM_SHELL="sb2 -t '$2' -m sdk-install bash -c"
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            bad_usage "Unrecognized option '$1'"
            exit 1
            ;;
        *)
            OPT_NAMES=(${OPT_NAMES:+"${OPT_NAMES[@]}"} "$1")
            ;;
    esac
    shift
done

OPT_NAMES=(${OPT_NAMES:+"${OPT_NAMES[@]}"} "$@")

if [[ $OPT_MERGE && $OPT_PROJECTS ]]; then
    bad_usage "Only one of '--merge' and '--projects' may be used"
    exit 1
fi

if [[ $OPT_MERGE ]]; then
    if [[ $OPT_ALL ]]; then
        bad_usage "Cannot use '--all' with '--merge'"
        exit 1
    fi
    if [[ $OPT_PACKAGE ]]; then
        bad_usage "Cannot use '--package' with '--merge'"
        exit 1
    fi
    if [[ $OPT_INCLUDE ]]; then
        bad_usage "Cannot use '--include' with '--merge'"
        exit 1
    fi
    if [[ $OPT_EXCLUDE ]]; then
        bad_usage "Cannot use '--exclude' with '--merge'"
        exit 1
    fi
    if [[ ${#OPT_NAMES[*]} -eq 0 ]]; then
        bad_usage "FILE expected"
        exit 1
    fi
else
    if [[ ! $OPT_ALL && ${#OPT_NAMES[*]} -eq 0 ]]; then
        bad_usage "NAME expected"
        exit 1
    fi
fi

if [[ $OPT_ALL && ${#OPT_NAMES[*]} -gt 0 ]]; then
    bad_usage "Got both --all and selected names"
    exit 1
fi

if ! tty --quiet; then
    OPT_NONINTERACTIVE=1
fi

abort() { kill -INT $$; }
trap 'echo "User aborted"' INT

if [[ $OPT_MERGE ]]; then
    merge |sort_output |format
elif [[ $OPT_PROJECTS ]]; then
    fetch_local |list_projects |format
else
    fetch_local |fetch_remote |sort_output |format
fi

if [[ $? -ne 0 ]]; then
    echo "Failed"
    exit 1
fi

##############################################################################
exit; fi  ###  S E L F - T E S T   E X E C U T I O N   S T A R T S   H E R E #
##############################################################################

: ${SELF_TEST_VERBOSE:=}

################################################################################
# Test utils

tc_num=0
tc_failed_num=0

set_up_ts() {
    local ts=$1
    TS_NAME=$2
    ${ts}_ts_set_up "${@:3}"
    if [[ $? -ne 0 ]]; then
        fatal "Test suite set-up failed: $ts"
    fi
}

tear_down_ts() {
    local ts=$1
    ${ts}_ts_tear_down
    if [[ $? -ne 0 ]]; then
        fatal "Test suite tear-down failed: $ts"
    fi
    TS_NAME=
}

run_tc() {
    local tc=$1
    TC_NAME=$2
    local args=("${@:3}")

    let tc_num++
    echo "*** Executing test case: ${TS_NAME:+$TS_NAME - }$TC_NAME"

    local stderr=
    { stderr=$(${tc}_tc ${args[@]:+"${args[@]}"} 3>&1 1>&2 2>&3 3>&-); } 2>&1
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        let tc_failed_num++
    fi

    if [[ $rc -ne 0 || $SELF_TEST_VERBOSE ]]; then
        cat <<END
  ** Stderr     ** [[
$stderr
]]
END
    fi

    return $rc
}

################################################################################
# Test parse_disturl

parse_disturl_ts_set_up() {
    :
}

parse_disturl_ts_tear_down() {
    :
}

parse_disturl_tc() {
    local url=$1 expected_api=$2 expected_project=$3 expected_revision=$4 expected_package=$5

    local actual= actual_api= actual_project= actual_revision= actual_package=
    if ! actual=$(parse_disturl "$url"); then
        cat <<END
Test case failed: $TC_NAME
  ** URL ** '$url'
  ** Unexpected non-zero return code **
END
        return 1
    fi

    read_ actual_{api,project,revision,package} <<< "$actual" || return

    if [[ $actual_api != "$expected_api" ||
        $actual_project != "$expected_project" ||
        $actual_revision != "$expected_revision" ||
        $actual_package != "$expected_package" ]]; then
        cat <<END
Test case failed: $TC_NAME
  ** URL      ** '$url'
  ** Expected ** [[
$expected_api
$expected_project
$expected_revision
$expected_package
]]
  ** Actual   ** [[
$actual_api
$actual_project
$actual_revision
$actual_package
]]
END
    fi
}

set_up_ts parse_disturl "Parsing DISTURL"

run_tc parse_disturl "basic" \
    "obs://build.jollamobile.com/pj:hw:jolla:x86-emul/latest_i486/ef625908704f0217947f00e7aaa228a6-vm-configs" \
    "https://build.jollamobile.com" \
    "pj:hw:jolla:x86-emul" \
    "ef625908704f0217947f00e7aaa228a6" \
    "vm-configs"

run_tc parse_disturl "API with scheme" \
    "obs://http://build.merproject.org/mer-tools:testing/latest_i486/0a9b9f17b92f6d533349469e0a189273-isomd5sum" \
    "http://build.merproject.org" \
    "mer-tools:testing" \
    "0a9b9f17b92f6d533349469e0a189273" \
    "isomd5sum"

tear_down_ts parse_disturl

################################################################################
# Test service_to_scmurl

service_to_scmurl_ts_set_up() {
    service=$(mktemp) || return
}

service_to_scmurl_ts_tear_down() {
    rm -f "$service"
}

service_to_scmurl_tc() {
    local expected=$1

    cat >"$service" || return

    local actual=
    if ! actual=$(service_to_scmurl "$service"); then
        cat <<END
Test case failed: $TC_NAME
  ** Unexpected non-zero return code **
END
        return 1
    fi

    if [[ $actual != "$expected" ]]; then
        cat <<END
Test case failed: $TC_NAME
  ** Expected ** '$expected'
  ** Actual   ** '$actual'
END
    fi
}

set_up_ts service_to_scmurl "Parsing _service file"

run_tc service_to_scmurl "tar_git" \
    "https://git.merproject.org/mer-core/gcc.git" \
    <<END
<services>
  <service name="tar_git">
    <param name="url">https://git.merproject.org/mer-core/gcc.git</param>
    <param name="branch">master</param>
    <param name="revision">3b0cc1012688ee37393edd23791bbb679c43daa7</param>
    <param name="token"></param>
    <param name="debian"></param>
    <param name="dumb">Y</param>
  </service>
</services>
END

run_tc service_to_scmurl "gitpkg on github" \
    "https://github.com/mer-tools/git" \
    <<END
<services>
  <service name="gitpkg">
  <param name="repo">mer-tools/git</param>
  <param name="tag">9245283769eff7dafd0d8fdd721d43d948834761</param>
  <param name="service">github</param>
  </service>
</services>
END

tear_down_ts service_to_scmurl

################################################################################
# Test cache - differencies in ordering may cause issues

cache_ts_set_up() {
    cache_open || return

    cache_store foo foo_val{1,2}
    cache_store bar bar_val{1,2}
    cache_store bar2 bar2_val{1,2}
    cache_store bar-3 bar-3_val{1,2}
    cache_store bar_4 bar_4_val{1,2}
    cache_store baz baz_val{1,2}
}

cache_ts_tear_down() {
    cache_close
}

cache_tc() {
    local key=$1
    local expected=$(write_ "${@:2}")

    local actual=$(cache_look "$key")
    if [[ $actual != "$expected" ]]; then
        cat <<END
Test case failed: $TC_NAME
  ** Expected ** '${expected//$SEPARATOR/|}'
  ** Actual   ** '${actual//$SEPARATOR/|}'
END
    fi
}

set_up_ts cache "Cache"

run_tc cache "foo" foo foo_val{1,2}
run_tc cache "ba" ba # no hit
run_tc cache "bar" bar bar_val{1,2}
run_tc cache "bar2" bar2 bar2_val{1,2}
run_tc cache "bar-3" bar-3 bar-3_val{1,2}
run_tc cache "bar_4" bar_4 bar_4_val{1,2}
run_tc cache "barr" barr # no hit
run_tc cache "baz" baz baz_val{1,2}

tear_down_ts cache
