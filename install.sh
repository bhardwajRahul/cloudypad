#/usr/env/bin bash

set -e

# Installation arguments
# Override by setting related environment variable
CLOUDYPAD_HOME=${CLOUDYPAD_HOME:-"$HOME/.cloudypad"}

# TODO use tagged/fixed version
CLOUDYPAD_SCRIPT_URL="https://raw.githubusercontent.com/PierreBeucher/cloudypad/fixes-and-improvements/cloudypad.sh"
# ===

# Constants, do not override
INSTALL_DIR="$CLOUDYPAD_HOME/bin"
SCRIPT_NAME="cloudypad"
SCRIPT_PATH="$INSTALL_DIR/cloudypad"

# Check if cloudypad is already in PATH
if [ -n "$(which cloudypad)" ]; then
  CURRENT_PATH=$(which cloudypad)
  read -p "cloudypad is already installed at ${CURRENT_CLOUDYPAD}. Do you want to overwrite it? (y/n): " CONFIRM
  if [[ "$CONFIRM" != "y" ]]; then
    echo "Installation aborted."
    exit 1
  fi
fi

echo "Downloading Cloudy Pad CLI..."

# Create secure directory for Cloudy Pad home as it may contain sensitive data
mkdir -p "$CLOUDYPAD_HOME"
chmod 0700 $CLOUDYPAD_HOME

mkdir -p "$INSTALL_DIR"

if command -v curl >/dev/null 2>&1; then
  curl -sSL -o "$SCRIPT_PATH" "$CLOUDYPAD_SCRIPT_URL"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$SCRIPT_PATH" "$CLOUDYPAD_SCRIPT_URL"
else
  echo "Error: Neither curl nor wget is available to download Cloudy Pad. Please install wget or curl and try again."
  exit 1
fi

chmod +x "$SCRIPT_PATH"

echo "Downloading Cloudy Pad container images..."
$SCRIPT_PATH download-container-images

# Identify shell to update *.rc file with PATh update
SHELL_NAME=$(basename "${SHELL}")
STARTUP_FILE=""

case "${SHELL_NAME}" in
    "bash")
        # Terminal.app on macOS prefers .bash_profile to .bashrc, so we prefer that
        # file when trying to put our export into a profile. On *NIX, .bashrc is
        # preferred as it is sourced for new interactive shells.
        if [ "$(uname)" != "Darwin" ]; then
            if [ -e "${HOME}/.bashrc" ]; then
                STARTUP_FILE="${HOME}/.bashrc"
            elif [ -e "${HOME}/.bash_profile" ]; then
                STARTUP_FILE="${HOME}/.bash_profile"
            fi
        else
            if [ -e "${HOME}/.bash_profile" ]; then
                STARTUP_FILE="${HOME}/.bash_profile"
            elif [ -e "${HOME}/.bashrc" ]; then
                STARTUP_FILE="${HOME}/.bashrc"
            fi
        fi
        ;;
    "zsh")
        STARTUP_FILE="${ZDOTDIR:-$HOME}/.zshrc"
        ;;
    *)
        echo
        echo "WARNING: Couldn't identiy startup file to use (such as .bashrc or .zshrc) for your current shell."
        echo "         To finalize installation please ensure $INSTALL_DIR is on your \$PATH."
        echo "         If you think this is a bug, please create an issue: https://github.com/PierreBeucher/cloudypad/issues"
        ;;
esac

if [ -n "${STARTUP_FILE}" ]; then
    # Create startup file if it does not exists. Rare situation but may happen
    touch "${STARTUP_FILE}"

    LINE_TO_ADD="export PATH=\$PATH:${INSTALL_DIR}"
    if ! grep -q "# add CloudyPad CLI PATH" "${STARTUP_FILE}"; then
        echo "Adding ${INSTALL_DIR} to \$PATH in ${STARTUP_FILE}"
        printf "\\n# add CloudyPad CLI PATH\\n%s\\necho "SOURCED"\\n" "${LINE_TO_ADD}" >> "${STARTUP_FILE}"
    fi
fi

echo "Successfully installed Cloudy Pad "

echo
echo "Restart your shell to add cloudypad on your PATH or run:"
echo
echo "  source $STARTUP_FILE"
echo
echo "Get started by creating a Cloudy Pad instance:"
echo
echo "  cloudypad create"
echo 
echo "If you enjoy Cloudy Pad, please star us ⭐ https://github.com/PierreBeucher/cloudypad"
echo "🐛 Found a bug? Create an issue: https://github.com/PierreBeucher/cloudypad/issues"
echo