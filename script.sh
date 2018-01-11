#!/usr/bin/env bash

# constants from environent, or use default values

[[ "${DOWNLOAD_QT_PATH}" ]]       || DOWNLOAD_QT_PATH="${HOME}/Qt"
[[ "${DOWNLOAD_QT_VERSION}" ]]    || DOWNLOAD_QT_VERSION="5.*" # latest
[[ "${DOWNLOAD_QT_COMPONENTS}" ]] || DOWNLOAD_QT_COMPONENTS="*gcc*"
# to download multiple components, separate with '\n'

function fatal_error() {
  echo >&2 "$0: Error: $1"
  exit 1
}

function get_os_and_ext() {
  case "${OSTYPE}" in
    darwin* )           readonly os="mac"     extension="dmg" ;;
    win*|cygwin|msys )  readonly os="windows" extension="exe" ;;
    linux* )            readonly os="linux"   extension="run" ;;
    * )         fatal_error "unrecognised OSTYPE '${OSTYPE}'" ;;
  esac
}

function get_arch() {
  # must call `get_os_and_ext` first to set ${os}
  case "${os}" in
    mac )     readonly arch="x64" ;;
    windows ) readonly arch="x86" ;;
    linux )
      case "${HOSTTYPE}" in
        x86_64 )  readonly arch="x64" ;;
        i*86 )    readonly arch="x86" ;;
        * ) fatal_error "unrecognised HOSTTYPE '${HOSTTYPE}'" ;;
      esac
      ;;
    * ) fatal_error "unrecognised OS '${os}'" ;;
  esac
}

function download_file() {
  file="$1"
  if which wget &>/dev/null; then
    wget "${file}"
  elif which curl &>/dev/null; then
    curl "${file}" -O
  else
    fatal_error "no download tool available."
  fi
  (($? == 0)) || fatal_error "unable to download file '${file}'"
}

function download_online_installer() {
  local -r installer="$1"
  local -r url_base="http://download.qt.io/official_releases/online_installers"
  download_file "${url_base}/${installer}"
  chmod +x "${installer}"
}

function ldtp_launch() {
  # launch Qt app with QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 so ldtp can see it
  QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 python \
    -c "import ldtp; ldtp.launchapp('$1'); ldtp.waittillguiexist('$2')"
}

function ldtp_wait_for_obj() {
  local -r obj="$1" timeout="${2:-5.0}" delay="${3:-0.5}"
  python -c "
import ldtp

obj='${obj}'
timeout=${timeout}
delay=${delay}

while (timeout > 0.0):
    ldtp.wait(delay)
    if ldtp.stateenabled('${gui}', obj):
        exit(0)
    if not ldtp.guiexist('${gui}'):
        exit(2)
    timeout-=delay

exit(1)
" || case $? in
    1 ) fatal_error "Timeout waiting for '${obj}'" ;;
    2 ) fatal_error "Window does not exist '${gui}'" ;;
  esac
}

function ooldtp() {
  local -r method="$1"
  python -c "
import ldtp, ooldtp
frm = ooldtp.context('${gui}')
frm.${method}" || fatal_error "Problem with ooldtp method '${method}'"
}

function ldtp() {
  local -r statement="$1"
  python -c "import ldtp; ${statement}" \
   || fatal_error "Problem with python statement '${statement}'"
}

function select_qt_component() {
  local -r component="$1"
  sleep 0.5 # allow GUI to update
  ooldtp "doubleclickrow('tree0', '${component}') # highlight component" \
    || fatal_error "Component not found '${component}'"
  echo >&2 "Found component '${component}'. Marking for installation."
  sleep 0.5 # allow GUI to update
  ldtp "ldtp.generatekeyevent('<space>')" # mark checkbox for component
  sleep 0.5 # allow GUI to update
}

function run_cmd_on_list() {
  local cmd="$1" list="$2" separator="${3:-$'\n'}" # newline or $3
  while [[ "${list}" ]]; do
    item="${list%%${separator}*}" # get first item
    if [[ "${item}" ]]; then
      "${cmd}" "${item}" # run cmd with item as argument
    fi
    list="${list:${#item}+${#separator}}" # delete item from list
  done
}

function run_installer() {
  local -r gui="dlgQtSetup"
  ldtp_launch "$1" "${gui}"
  ldtp_wait_for_obj "btnNext*"   &&  ooldtp "click('btnNext*')"
  echo >&2 "Starting Qt open source setup..."
  ldtp_wait_for_obj "btnSkip*"   &&  ooldtp "click('btnSkip*')"
  ldtp_wait_for_obj "btnNext*"  &&  ooldtp "click('btnNext*')"
  echo >&2 "Retrieving meta information from the remote repository..."
  ldtp_wait_for_obj "btnNext*"  60  1  # long wait
  echo >&2 "Setting Qt installation path to '${DOWNLOAD_QT_PATH}'..."
  ooldtp "settextvalue('txt7', '${DOWNLOAD_QT_PATH}')" # Qt install path
  ooldtp "click('btnNext*')"
  echo >&2 "Selecting Qt version ${DOWNLOAD_QT_VERSION}"
  sleep 0.5 # allow GUI to update
  ooldtp "doubleclickrow('tree0', 'Qt')"
  sleep 0.5 # allow GUI to update
  ooldtp "doubleclickrow('tree0', 'Qt ${DOWNLOAD_QT_VERSION}')"
  echo >&2 "Selecting Qt components to install...
${DOWNLOAD_QT_COMPONENTS}"
  run_cmd_on_list  select_qt_component  "${DOWNLOAD_QT_COMPONENTS}"  $'\n'
  ldtp_wait_for_obj "btnNext*"    &&  ooldtp "click('btnNext*')"
  echo >&2 "Agreeing to Qt terms..."
  sleep 0.5 # allow GUI to update
  ldtp "ldtp.generatekeyevent('<tab><tab><up><space>')" # agree to terms
  sleep 0.5 # allow GUI to update
  ldtp_wait_for_obj "btnNext*"    &&  ooldtp "click('btnNext*')"
  ldtp_wait_for_obj 'btnInstall'  &&  ooldtp "click('btnInstall')"
  echo >&2 "Downloading and installing Qt..."
  ldtp_wait_for_obj 'btnFinish'   600  5  # very long wait
  ldtp "ldtp.generatekeyevent('<tab><space>')" # Don't launch Qt Creator
  ooldtp "click('btnFinish')"
  echo >&2 "Qt successfully installed to '${DOWNLOAD_QT_PATH}'"
}

function install_qt() {
  get_os_and_ext
  get_arch
  readonly qt_installer="qt-unified-${os}-${arch}-online.${extension}"
  [[ -f "${qt_installer}" ]] || download_online_installer "${qt_installer}"
  # python run-qt-installer.py "${qt_installer}"
  run_installer "${PWD}/${qt_installer}"
}

install_qt "$@"
