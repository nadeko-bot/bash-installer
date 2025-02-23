#!/bin/bash

## Colors for output.
YELLOW="$(printf '\033[0;33m')"
GREEN="$(printf '\033[0;32m')"
BLUE="$(printf '\033[0;34m')"
CYAN="$(printf '\033[0;36m')"
RED="$(printf '\033[1;31m')"
NC="$(printf '\033[0m')"
export YELLOW GREEN BLUE CYAN RED NC

## Other constants.
readonly BOT_EXECUTABLE="NadekoBot"
readonly BIN_DIR="nadeko"
readonly BACKUP_DIR="nadeko_backups"
readonly CREDS_FILE="$BIN_DIR/data/creds.yml"
readonly CREDS_EXAMPLE_FILE="$BIN_DIR/data/creds_example.yml"

####
# Identify the system architecture and OS, and return a string that represents it.
#
# RETURNS:
#   - linux-x64: For Linux x86_64.
#   - linux-arm64: For Linux aarch64 or arm64.
#   - osx-x64: For macOS x86_64.
#   - osx-arm64: For macOS arm64.
#   - unsupported: For all other architectures or operating systems.
get_arch() {
    local os
    os=$(uname -s)
    local arch
    arch=$(uname -m)

    case "$os" in
    Linux)
        case "$arch" in
        x86_64) echo "linux-x64" ;;
        aarch64 | arm64) echo "linux-arm64" ;;
        *) echo "unsupported" ;;
        esac
        ;;
    Darwin)
        case "$arch" in
        x86_64) echo "osx-x64" ;;
        arm64) echo "osx-arm64" ;;
        *) echo "unsupported" ;;
        esac
        ;;
    *)
        echo "unsupported"
        ;;
    esac
}

backup_bot() {
    if [ -d $BIN_DIR/data/ ]; then
        if [ ! -d $BACKUP_DIR/ ]; then
            mkdir $BACKUP_DIR
        fi

        date_now=$(date +%s)
        cp -r $BIN_DIR/data "$BACKUP_DIR/$date_now-data"

        echo "${BLUE}Your current data "
    fi
}

# TODO: Still needs to move data from the old directory to the new one.
####
# Downloads the latest release, extracts it, and sets up NadekoBot's directory. If
# the directory already exists, it will be renamed to `nadeko.old`. If
# `nadeko.old` already exists, it will be deleted.
#
# PARAMETERS:
#   - $1: version (Required)
#       - The release version to download.
#
# RETURNS:
#   - 1: On failure of some operation.
install_bot() {
    local version="$1"
    local arch
    arch=$(get_arch)
    local output="nadeko-new"

    local tar_url="https://github.com/nadeko-bot/nadekobot/releases/download/${version}/nadeko-${arch}.tar.gz"
    if [[ $arch == "unsupported" ]]; then
        echo "${RED}ERROR: Unsupported architecture${NC}" >&2
        return 1
    fi

    echo "${BLUE}Downloading '${version}' for '${arch}'...${NC}"

    if [[ -d $output ]]; then
        rm -r ./$output
    fi

    mkdir ./$output

    if ! curl -L "$tar_url" | tar -xzf - -C ./$output --strip-components=1; then
        echo "${RED}ERROR: Failed to download or extract the archive${NC}" >&2
        rm -r ./$output
        return 1
    fi


    if [[ ! -d $BIN_DIR ]]; then
        echo "${BLUE}NadekoBot not installed. Installing for the first time.${NC}"
    else
        backup_bot
        mv "$BIN_DIR" "${BIN_DIR}-old"
    fi

    mv ./$output $BIN_DIR

    if [[ -d "${BIN_DIR}-old" ]]; then
        echo "${BLUE}Copying over data folder...${NC}"
        if [[ -d "${BIN_DIR}-old/data/" ]]; then
            cp -rf "${BIN_DIR}-old/data/"* "$BIN_DIR/data/"
        fi
        rm -r "${BIN_DIR}-old"
    fi

    chmod +x "${BIN_DIR}/${BOT_EXECUTABLE}"
    
    echo "${GREEN}Installation complete!${NC}"
}

# TODO: Somehow get the bot version, and
#       paint available versions with color
#       RED: older (downgrade), not recommended
#       GREEN: newer (upgrade)
#       BLUE: same (reinstall)

####
# Display a list of available versions, and prompt the user to select one to install.
install_submenu() {
    local versions

    # get versions from /refs/tags github endpoint
    mapfile -t versions < <(curl -s https://api.github.com/repos/nadeko-bot/nadekobot/git/refs/tags | grep -oP '"ref": "refs/tags/\K[^"]+')

    echo "${CYAN}Select version to install:${NC}"
    select version in "${versions[@]}"; do
        if [[ -n $version ]]; then
            install_bot "$version"
            break
        else
            echo "${RED}ERROR: Invalid selection${NC}"
        fi
    done
}

####
# Determines whether the 'token' field in the credentials file is set.
#
# NOTE:
#   This is not a comprehensive check for the validity of the token; it only verifies
#   that the token field is not empty.
#
# RETURNS:
#   - 0: If the token is set.
#   - 1: If the token is not set.
is_token_set() {
    if grep -Eq '^token: '\'\''' "$CREDS_FILE"; then
        return 1
    else
        return 0
    fi
}

####
# Verify that the bot is installed, the token in the 'creds.yml' file is set, and then
# run the bot.
#
# RETURNS:
#   - 1: If the bot is not installed, the executable is not found, or the token is not
#       set.
run_bot() {
    ## Ensure that the bot is installed.
    if [[ ! -d $BIN_DIR ]]; then
        echo "${RED}ERROR: NadekoBot not installed. Please install it first.${NC}" >&2
        return 1
    fi

    ## Ensures that the executable exists.
    if [[ ! -f $BIN_DIR/$BOT_EXECUTABLE ]]; then
        echo "${RED}ERROR: NadekoBot executable not found${NC}" >&2
        return 1
    fi

    ## Create the creds file if it doesn't exist.
    if [[ ! -f $CREDS_FILE ]]; then
        if [[ ! -f $CREDS_EXAMPLE_FILE ]]; then
            echo "${RED}ERROR: 'creds_xample.yml'not found. Make sure the bot is installed${NC}" >&2
            return 1
        fi
        cp -f "$CREDS_EXAMPLE_FILE" "$CREDS_FILE"
    fi

    ## Ensure that the token is set in the creds file
    ## Or check if env var bot_token is set
    if [[ ! -f "$CREDS_FILE" ]] && [[ ! -z "${bot_token}" ]]; then
        echo "${YELLOW}WARNING: 'token' is not set in '$CREDS_FILE'. Please add your token and try again.${NC}" >&2
        return 1
    fi

    echo "${BLUE}Attempting to run NadekoBot...${NC}"
    pushd "$BIN_DIR" >/dev/null || return 1
    ./$BOT_EXECUTABLE
    popd >/dev/null || return 1
}

install_music_dependencies() {
    curl -L -o n-musicreq.sh https://raw.githubusercontent.com/nadeko-bot/bash-installer/refs/heads/v6/n-prereq.sh || {
        echo "ERROR: Failed to download the music dependencies installer"
        return 1
    }

    if [[ ! -f n-musicreq.sh ]]; then
        echo "${RED}ERROR: Failed to download the music dependencies installer${NC}" >&2
        return 1
    fi

    chmod +x n-musicreq.sh
    ./n-musicreq.sh
    rm n-musicreq.sh
}

edit_creds() {
    if [[ ! -f $CREDS_FILE ]]; then
        cp $CREDS_EXAMPLE_FILE $CREDS_FILE
    fi

    # ask the user to input the token
    echo "Please input your token: "
    echo ""
    read -r token

    # check if the token is not empty
    if [[ -z "$token" ]]; then
        echo "ERROR: Invalid token." >&2
        return 1
    fi

    # replace the token in the creds file
    # by finding a line which starts with 'token: ' and replacing it
    sed -i "s/token: .*/token: \"$token\"/" $CREDS_FILE
}

migrate_from_v5() {

    # 0. Ensure that the bot is installed
    if [[ ! -d $BIN_DIR ]]; then
        echo "${RED}ERROR: NadekoBot v6 not installed. Please install it first and then you'll be able to migrate.${NC}"
        return 1
    fi

    # 1. Check if there is a nadekobot/output folder
    if [ ! -d "nadekobot/output" ]; then
        echo "${RED}ERROR: No v5 installation found.${NC}"
        return 1
    fi

    # 2. Copy over the entirety of the data folder and overwrite
    if [ -d "nadekobot/output/data/" ]; then
        # strings are no longer there, nor do we need them
        rm -rf nadekobot/output/data/strings
        cp -rf nadekobot/output/data/* nadeko/data/

        # move the data folder to avoid double migration
        mv nadekobot/output/data nadekobot/output/data.old
    fi

    # Done
    echo "${GREEN}Migration successful! Your v6 bot is now in the 'nadeko' folder.${NC}"
    MIGRATED=1
}

####
# Display the main menu options.
display_menu() {
    clear
    echo "${BLUE}===== NadekoBot Release Installer =====${NC}"
    echo "1. Install"
    echo "2. Run"
    echo "3. Add Token"
    echo "4. Install music dependencies"
    echo "5. Exit"
    if [[ ! $MIGRATED -eq 1 ]]; then
        echo "6. Migrate v5 from-source version"
    fi
    echo -n "${CYAN}Enter your choice:${NC} "
}

MIGRATED=1
# check if there is a nadekobot/output/data folder
if [ ! -d "nadekobot/output/data" ]; then
    MIGRATED=0
fi

while true; do
    display_menu
    read -r choice
    case $choice in
    1) install_submenu ;;
    2) run_bot ;;
    3) edit_creds ;;
    4) install_music_dependencies ;;
    5)
        echo "${GREEN}Exiting...${NC}"
        exit 0
        ;;
    6)
        if [[ ! $MIGRATED -eq 1 ]]; then
            echo "${YELLOW}WARNING: You need to migrate from v5 first!${NC}" >&2
            break
        fi
        migrate_from_v5
        ;;
    *) echo "${RED}ERROR: Invalid option${NC}" ;;
    esac

    echo "${CYAN}Press [Enter] to continue${NC}"
    read -r
done
