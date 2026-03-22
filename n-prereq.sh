#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  sudo_cmd="sudo "
fi

declare -A -r APT_CMD=(
    ["update"]="${sudo_cmd}apt update"
    ["install"]="${sudo_cmd}apt install -y"
)

declare -A -r DNF_CMD=(
    ["update"]="${sudo_cmd}dnf update -y"
    ["install"]="${sudo_cmd}dnf install -y"
)

declare -A -r ZYPPER_CMD=(
    ["update"]="${sudo_cmd}zypper refresh"
    ["install"]="${sudo_cmd}zypper install -y"
)

declare -A -r BREW_CMD=(
    ["update"]="${sudo_cmd}brew update"
    ["install"]="${sudo_cmd}brew install"
)

declare -A -r PACMAN_CMD=(
    ["update"]="${sudo_cmd}pacman -Sy"
    ["install"]="${sudo_cmd}pacman -Sy --noconfirm"
)

readonly YT_DLP_PATH="$HOME/.local/bin/yt-dlp"

####
# Identify the system's distribution, version, and architecture.
#
# NOTE:
#   The 'os-release' file is used to determine the distribution and version. This file
#   is present on almost every distributions running systemd.
#
# NEW GLOBALS:
#   - DISTRO: The distribution name.
#   - VER: The distribution version.
#   - SVER: The distribution version without the minor version.
#   - ARCH: The system architecture.
#   - BITS: The system architecture in bits.
detect_sys_info() {
    if [[ $(uname -s) == "Darwin" ]]; then
        DISTRO="darwin"
        VER=$(sw_vers -productVersion)
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO="$ID"
        VER="$VERSION_ID"  # Version: x.x.x...
        SVER=${VER//.*/}  # Version: x
    else
        DISTRO=$(uname -s)
        VER=$(uname -r)
    fi

    case $(uname -m) in
        x86_64)  BITS="64"; ARCH="x64" ;;
        aarch64) BITS="64"; ARCH="arm64" ;;
        armv*)   BITS="32"; ARCH="arm32" ;;  # Generic ARM 32-bit.
        i*86)    BITS="32"; ARCH="x86" ;;
        *)       BITS="?";  ARCH="$(uname -m)" ;;  # Fallback to uname output.
    esac
}

####
# Install 'yt-dlp' at '~/.local/bin/yt-dlp'.
#
# EXITS:
#   - 1: Failed to download 'yt-dlp'.
install_yt_dlp() {

    if command -v yt-dlp &>/dev/null; then
        echo "${BLUE}Updating 'yt-dlp'...${NC}"
        yt-dlp -U || {
            echo "${RED}Failed to update 'yt-dlp'${NC}" >&2
        }
    else
        # get correct yt-dlp based on os and arch
        if [[ "$DISTRO" == "darwin" ]]; then
            local yt_dlp_url="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
        else
            local yt_dlp_url="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux"
            case $ARCH in
                x64) ;;
                arm64) yt_dlp_url="${yt_dlp_url}_aarch64" ;;
                arm32) yt_dlp_url="${yt_dlp_url}_armv7l" ;;
                *) echo "${RED}Unsupported architecture: $ARCH${NC}" >&2; return 1 ;;
            esac
        fi

        [[ ! -d "$HOME/.local/bin" ]] && mkdir -p "$HOME/.local/bin"

        if [[ ! -f $YT_DLP_PATH ]]; then
            echo "${BLUE}Installing 'yt-dlp'...${NC}"
            curl -L "$yt_dlp_url" -o "$YT_DLP_PATH" || {
                echo "${RED}Failed to download 'yt-dlp'${NC}" >&2
                return 1
            }
        fi

        echo "${BLUE}Modifying permissions for 'yt-dlp'...${NC}"
        chmod a+rx "$YT_DLP_PATH"
    fi

    if command -v deno &>/dev/null || command -v node &>/dev/null || command -v bun &>/dev/null; then
        echo "${BLUE}A JavaScript runtime is already installed.${NC}"
    else
        echo "${BLUE}Installing Deno (required by yt-dlp)...${NC}"
        curl -fsSL https://deno.land/install.sh | DENO_INSTALL="$HOME/.deno" sh || {
            echo "${RED}Failed to install Deno${NC}" >&2
            return 1
        }
        export DENO_INSTALL="$HOME/.deno"
        export PATH="$DENO_INSTALL/bin:$PATH"
        echo "${GREEN}Deno installed successfully.${NC}"
    fi
}

####
# Installs music prerequisites.
#
# PARAMETERS:
#   - $1: cmd_array (Required)
#       - The associative array containing the package manager commands.
#   - $2: pkg_list (Required)
#       - The array containing the list of packages to install.
install_music_prereqs() {
    local -n cmd_array="$1"
    local -n pkg_list="$2"

    echo -e "${YELLOW}About to run: ${cmd_array["update"]}${NC}"
    read -p "${CYAN}Continue? [y/N]: ${NC}" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${cmd_array["update"]} || {
            echo "${RED}Failed to update${NC}" >&2
            exit 1
        }
    else
        echo "${RED}Update skipped${NC}"
    fi


    echo -e "${YELLOW}About to run: ${cmd_array["install"]} ${pkg_list[*]}${NC}"
    read -p "${CYAN}Continue? [y/N]: ${NC}" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${cmd_array["install"]} "${pkg_list[@]}" || {
            echo "${RED}Failed to install music prerequisites${NC}" >&2
            exit 1
        }
    else
        echo "${RED}Installation cancelled${NC}"
        exit 1
    fi

    install_yt_dlp

    echo -e "\n${GREEN}Finished installing music prerequisites${NC}"
}

detect_sys_info

if [[ $BITS == "32" ]]; then
    echo "${RED}Your system is 32-bit, which is unsupported${NC}" >&2
    exit 1
fi

case "$DISTRO" in
    ubuntu)
        readonly pkgs=(ffmpeg curl)
        case "$VER" in
            22.04|24.04) install_music_prereqs APT_CMD pkgs ;;
            *) unsupported ;;
        esac
        ;;
    debian)
        readonly pkgs=(ffmpeg curl)
        case "$SVER" in
            1[1-3]) install_music_prereqs APT_CMD pkgs ;;
            *) unsupported ;;
        esac
        ;;
    linuxmint)
        readonly pkgs=(ffmpeg curl)
        case "$SVER" in
            2[0-3]) install_music_prereqs APT_CMD pkgs ;;
            *) unsupported ;;
        esac
        ;;
    fedora)
        readonly pkgs=(ffmpeg-free curl)
        case "$SVER" in
            38|39|40|41|42|43) install_music_prereqs DNF_CMD pkgs ;;
            *) unsupported ;;
        esac
        ;;
    almalinux|rocky)
        el_ver=$(rpm -E %rhel)

        # add rpm fusion repo
        repo_cmd=(
            "${sudo_cmd}dnf install -y epel-release"
            "sudo dnf install --nogpgcheck https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${el_ver}.noarch.rpm -y"
        )

        if (( el_ver == 8 )); then
            repo_cmd+=("${sudo_cmd}dnf config-manager --set-enabled powertools")
        elif (( el_ver == 9 )); then
            repo_cmd+=("${sudo_cmd}dnf config-manager --set-enabled crb")
        fi

        echo "${YELLOW}In order to install ffmpeg, you need to enable the RPM Fusion repository.${NC}"
        echo "${YELLOW}The following commands will be run:${NC}"
        for cmd in "${repo_cmd[@]}"; do
            echo "  ${YELLOW}-> $cmd${NC}"
        done

        # ask the user whether it's ok to run this command
        read -p "${CYAN}Do you want to continue with these commands? [y/N]: ${NC}" -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for cmd in "${repo_cmd[@]}"; do
                echo "${BLUE}Running: $cmd${NC}"
                $cmd || {
                    echo "${RED}Failed to run: $cmd${NC}" >&2
                    exit 1
                }
            done
        else
            echo "${RED}User opted to cancel the command execution.${NC}" >&2
            exit 1
        fi

        readonly pkgs=(ffmpeg curl)
        install_music_prereqs DNF_CMD pkgs
        ;;
    opensuse-leap)
        readonly pkgs=(ffmpeg curl)
        case "$VER" in
            15.5|15.6|15.7) install_music_prereqs ZYPPER_CMD pkgs ;;
            *) unsupported ;;
        esac
        ;;
    opensuse-tumbleweed)
        readonly pkgs=(ffmpeg curl)
        install_music_prereqs ZYPPER_CMD pkgs ;;
    arch|artix)
        readonly pkgs=(ffmpeg pipewire-jack curl)
        install_music_prereqs PACMAN_CMD pkgs
        ;;
    darwin)
        if ! command -v brew &>/dev/null; then
            echo "${RED}Homebrew is not installed. Please install Homebrew first.${NC}" >&2
            exit 1
        fi
        readonly pkgs=(ffmpeg python curl)
        install_music_prereqs BREW_CMD pkgs
        ;;
    *)
        echo "${RED}Unsupported distribution: $DISTRO${NC}" >&2
        exit 1
        ;;
esac
