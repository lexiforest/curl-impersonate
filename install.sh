#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipelines return the exit status of the last command to exit with a non-zero status,
# or zero if all commands exit successfully.
set -o pipefail

# --- Configuration ---
OWNER="lexiforest"
REPO="curl-impersonate"
# Default installation directory. Requires sudo privileges.
# Change to something like "$HOME/.local/bin" for user-local install
# (ensure this directory exists and is in your $PATH).
INSTALL_DIR="/usr/local/bin"
BASE_URL="https://github.com/${OWNER}/${REPO}/releases/download"
API_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases"
# --- End Configuration ---

# Check for required commands
command -v uname >/dev/null 2>&1 || { echo >&2 "Error: 'uname' command not found."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "Error: 'curl' command not found."; exit 1; }
command -v tar >/dev/null 2>&1 || { echo >&2 "Error: 'tar' command not found."; exit 1; }
command -v mktemp >/dev/null 2>&1 || { echo >&2 "Error: 'mktemp' command not found."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "Error: 'jq' command not found. Please install jq (e.g., 'sudo apt install jq', 'brew install jq')."; exit 1; }
command -v find >/dev/null 2>&1 || { echo >&2 "Error: 'find' command not found."; exit 1; }
command -v basename >/dev/null 2>&1 || { echo >&2 "Error: 'basename' command not found."; exit 1; }
# Function to get the latest stable release tag from GitHub API
get_latest_stable_release() {
    # Fetch releases, filter out pre-releases, get the first one (latest), extract tag_name
    local latest_tag=$(curl --silent --fail "$API_URL" | jq -r 'map(select(.prerelease == false and (.tag_name | contains("rc") | not))) | .[0].tag_name')

    if [ -z "$latest_tag" ] || [ "$latest_tag" == "null" ]; then
        latest_tag="v0.9.5"
    fi
    # Return tag_name without leading 'v'
    latest_tag=${latest_tag#v}
    echo "$latest_tag"
}

# --- Version Detection ---
VERSION=$(get_latest_stable_release)
echo "Latest stable version found: $VERSION"

read -p "Use the latest stable version (${VERSION})? [Y/n]: " version_choice
case "$version_choice" in
    [nN]|[nN][oO])
        read -p "Enter the desired version: " user_version
        if [[ -n "$user_version" ]]; then
            VERSION="$user_version"
        else
            echo "No version entered. Using the latest stable version: $VERSION"
        fi
        ;;
    *)
        echo "Using the latest stable version: $VERSION"
        ;;
esac

# Ensure version doesn't start with 'v', we add it where needed
if [[ "$VERSION" == v* ]]; then
    VERSION="${VERSION#v}"
fi
VERSION_TAG="v${VERSION}" # Tag name for URL usually starts with 'v'
FILENAME_VERSION="v${VERSION}" # Filename also seems to start with 'v'


# --- Detect OS and Architecture ---
OS_KERNEL=$(uname -s)
ARCH=$(uname -m)

OS_ARCH_SUFFIX=""

case "$OS_KERNEL" in
    Linux)
        OS_NAME="linux"
        # Default to gnu libc suffix
        LIBC_SUFFIX="gnu"
        case "$ARCH" in
            x86_64)     ARCH_SUFFIX="x86_64-${OS_NAME}-${LIBC_SUFFIX}" ;;
            aarch64)    ARCH_SUFFIX="aarch64-${OS_NAME}-${LIBC_SUFFIX}" ;;
            armv7l|armhf) ARCH_SUFFIX="arm-${OS_NAME}-gnueabihf" ;;
            i386|i686)  ARCH_SUFFIX="i386-${OS_NAME}-${LIBC_SUFFIX}" ;;
            riscv64)    ARCH_SUFFIX="riscv64-${OS_NAME}-${LIBC_SUFFIX}" ;;
            *)          echo >&2 "Error: Unsupported Linux architecture: $ARCH"; exit 1 ;;
        esac
        # Allow overriding libc via environment variable
        if [[ -n "${LIBC-}" && "$LIBC" == "musl" ]]; then
             if [[ "$ARCH" == "x86_64" || "$ARCH" == "aarch64" ]]; then
                ARCH_SUFFIX="${ARCH}-${OS_NAME}-musl"
                echo "Using specified musl build for $ARCH."
             else
                echo >&2 "Warning: LIBC=musl specified, but no known musl build for $ARCH. Using default gnu."
             fi
        fi
        ;;
    Darwin)
        OS_NAME="macos"
        case "$ARCH" in
            x86_64)     ARCH_SUFFIX="x86_64-${OS_NAME}" ;;
            arm64)      ARCH_SUFFIX="arm64-${OS_NAME}" ;; # macOS uses arm64
            *)          echo >&2 "Error: Unsupported macOS architecture: $ARCH"; exit 1 ;;
        esac
        ;;
    *)
        echo >&2 "Error: Unsupported operating system: $OS_KERNEL"
        exit 1
        ;;
esac

# Construct filename and URL
# NOTE: The repo name seems to be just 'curl-impersonate' in the filename examples.
FILENAME="curl-impersonate-${FILENAME_VERSION}.${ARCH_SUFFIX}.tar.gz"
DOWNLOAD_URL="${BASE_URL}/${VERSION_TAG}/${FILENAME}"

echo "----------------------------------------"
echo "OS: ${OS_KERNEL} (${OS_NAME})"
echo "Arch: ${ARCH}"
echo "Suffix: ${ARCH_SUFFIX}"
echo "Version: ${VERSION}"
echo "Filename: ${FILENAME}"
echo "Download URL: ${DOWNLOAD_URL}"
echo "Install Dir: ${INSTALL_DIR}"
echo "----------------------------------------"

# Create a temporary directory for download and extraction
TMP_DIR=$(mktemp -d)
# Setup cleanup trap
trap 'echo "Cleaning up temporary directory: $TMP_DIR"; rm -rf "$TMP_DIR"' EXIT

echo "Downloading ${FILENAME} to ${TMP_DIR}..."
curl --fail --silent --show-error --location "$DOWNLOAD_URL" --output "${TMP_DIR}/${FILENAME}"
echo "Download complete."

echo "Extracting archive..."
# Extract into the temporary directory. Using --strip-components=1 might simplify
# finding files if the archive always has a single top-level dir, but finding
# is safer if the structure varies.
tar -xzf "${TMP_DIR}/${FILENAME}" -C "$TMP_DIR"
echo "Extraction complete."

# --- Find Binaries and Ask User ---
echo "Searching for executables in extracted files..."

MAIN_BINARY_NAMES=("curl-impersonate-chrome" "curl-impersonate") # Possible main executable names in the archive
MAIN_BINARY_PATH=""

# Search for the main binary specifically (check execute bit)
for binary_name in "${MAIN_BINARY_NAMES[@]}"; do
    MAIN_BINARY_PATH=$(find "$TMP_DIR" -name "${binary_name}" -type f -perm +111 | head -n 1)
    if [ -n "$MAIN_BINARY_PATH" ]; then
        MAIN_BINARY_NAME="$binary_name"
        break
    fi
done

if [ -z "$MAIN_BINARY_PATH" ]; then
    echo >&2 "Error: Could not find any main binary (${MAIN_BINARY_NAMES[*]}) in the extracted archive."
    echo >&2 "Please check the archive contents or the MAIN_BINARY_NAMES variable in the script."
    echo "Contents of ${TMP_DIR}:"
    ls -lR "$TMP_DIR"
    exit 1
fi

echo "Found main binary: $(basename ${MAIN_BINARY_PATH})"

OTHER_EXECUTABLES=() # Initialize as an empty array
OTHER_EXECUTABLES=($(find "$TMP_DIR" -type f ! -name '*.bat' ! -name '*.gz' ! -path "$MAIN_BINARY_PATH"))
OTHER_EXECUTABLES_LENGTH=${#OTHER_EXECUTABLES[@]}

INSTALL_ALL="no" # Default is NO (only main binary)
FILES_TO_INSTALL=()
FILES_TO_INSTALL+=("$MAIN_BINARY_PATH") # Always include the main binary

if [ -n "$OTHER_EXECUTABLES" ]; then
    echo -e "\nFound $OTHER_EXECUTABLES_LENGTH other executable files"
    echo
    read -p "Install ALL found executables (including wrappers like curl_<>)? [y/N]: " install_all_choice
    case "$install_all_choice" in
        [yY]|[yY][eE][sS])
            INSTALL_ALL="yes"
            echo "Okay, scheduling all found executables for installation."
            # Add other executables to the array
            for executable in "${OTHER_EXECUTABLES[@]}"; do
                FILES_TO_INSTALL+=("$executable")
            done
            ;;
        *)
            INSTALL_ALL="no" # Explicitly set back to no
            echo "Okay, scheduling only '${MAIN_BINARY_NAME}' for installation."
            ;;
    esac
else
    echo "No other executable files found to install besides ${MAIN_BINARY_NAME}."
fi


# --- Installation ---
echo -e "\nPreparing to install the following files to ${INSTALL_DIR}:"
for file_path in "${FILES_TO_INSTALL[@]}"; do
    echo "  - $(basename "$file_path")"
done
echo

# Check if installation directory exists, create if necessary (and possible)
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Installation directory '${INSTALL_DIR}' does not exist."
    # Attempt to create only if it's within the user's home directory for safety without sudo
    if [[ "$INSTALL_DIR" == "$HOME"* ]]; then
        echo "Attempting to create user directory: ${INSTALL_DIR}"
        mkdir -p "$INSTALL_DIR"
    else
        echo "Please create it manually (you might need sudo: sudo mkdir -p '$INSTALL_DIR' && sudo chown \$USER '$INSTALL_DIR')."
        # Check if sudo exists before suggesting its use
         if command -v sudo >/dev/null 2>&1; then
             read -p "Attempt to create directory using sudo? [y/N]: " create_sudo
             case "$create_sudo" in
                 [yY]|[yY][eE][sS])
                     sudo mkdir -p "$INSTALL_DIR"
                     echo "Directory created. You may need to adjust ownership/permissions if installing as root."
                     ;;
                 *)
                     echo "Aborting installation."
                     exit 1
                     ;;
             esac
         else
            echo "sudo command not found. Cannot create system directory automatically."
            exit 1
         fi
    fi
fi


# Check write permissions for install dir or if sudo is needed ONCE
USE_SUDO=""
if [ ! -w "$INSTALL_DIR" ]; then
    echo "Write permission needed for ${INSTALL_DIR}. Using sudo."
    USE_SUDO="sudo"
    command -v sudo >/dev/null 2>&1 || { echo >&2 "Error: sudo is required to install to $INSTALL_DIR but sudo command not found."; exit 1; }
fi

# Install each file
INSTALL_COUNT=0
for source_path in "${FILES_TO_INSTALL[@]}"; do
    binary_name=$(basename "$source_path")
    target_path="${INSTALL_DIR}/${binary_name}"

    # Check if file already exists in target location
    if [ -e "$target_path" ]; then
        # Basic check: skip if source and target seem identical (simple size check)
        # A more robust check might involve checksums if needed.
        if [ "$USE_SUDO" == "sudo" ]; then
            target_size=$(sudo stat -c%s "$target_path" 2>/dev/null || echo 0)
        else
            target_size=$(stat -c%s "$target_path" 2>/dev/null || echo 0) # Linux stat, adjust for macOS if needed
        fi
        source_size=$(stat -c%s "$source_path" 2>/dev/null || echo 0)

        if [ "$target_size" -ne 0 ] && [ "$target_size" -eq "$source_size" ]; then
             echo "Skipping identical file: ${binary_name}"
             continue # Skip mv and chmod
        else
             echo "Overwriting existing file: ${binary_name}"
             # Ensure removal first if using sudo, to avoid permission issues on move
             if [ "$USE_SUDO" == "sudo" ]; then
                 $USE_SUDO rm -f "${target_path}"
             fi
        fi
    fi


    $USE_SUDO mv "${source_path}" "${target_path}"
    $USE_SUDO chmod +x "${target_path}"
    INSTALL_COUNT=$((INSTALL_COUNT + 1))
done

if [ $INSTALL_COUNT -gt 0 ]; then
    echo "${INSTALL_COUNT} file(s) installed successfully."
else
    echo "No new files were installed (they may already exist)."
fi


# --- Verification ---
# Verify installation of the main binary
MAIN_BINARY_TARGET="${INSTALL_DIR}/${MAIN_BINARY_NAME}"
echo "Verifying installation of ${MAIN_BINARY_NAME}:"
if command -v "${MAIN_BINARY_TARGET}" >/dev/null 2>&1; then
     "${MAIN_BINARY_TARGET}" --version
     echo "'${MAIN_BINARY_NAME}' is installed and should be in your PATH if '${INSTALL_DIR}' is configured correctly."
elif command -v "${MAIN_BINARY_NAME}" >/dev/null 2>&1; then
     # Check if it's findable directly in PATH (maybe INSTALL_DIR was already in PATH)
     "${MAIN_BINARY_NAME}" --version
     echo "'${MAIN_BINARY_NAME}' is installed and available in your PATH."
else
     echo >&2 "Warning: Could not verify main binary installation at ${MAIN_BINARY_TARGET} or in PATH."
     echo >&2 "Ensure '${INSTALL_DIR}' is in your \$PATH environment variable."
fi

# Cleanup is handled by the trap EXIT

echo "Installation process complete."
exit 0