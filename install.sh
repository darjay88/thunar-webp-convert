#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE_SCRIPT="${SCRIPT_DIR}/convert-to-webp.sh"
INSTALL_NAME="convert-to-webp"
ACTION_ID="thunar-webp-convert"
ACTION_NAME="Convert to WebP"
ACTION_DESCRIPTION="Convert selected image files to WebP using your config settings."
ACTION_ICON="image-x-generic"
THUNAR_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Thunar"
THUNAR_UCA_FILE="${THUNAR_CONFIG_DIR}/uca.xml"
WEBP_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/webp-convert"
WEBP_CONFIG_FILE="${WEBP_CONFIG_DIR}/config.toml"

DEFAULT_WEBP_CONFIG_CONTENT=$(cat <<'EOF'
target_width = 800
quality = 85
output_suffix = ""
EOF
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [--system] [--bin-dir DIR]

Installs the converter command and registers a Thunar right-click action.

Options:
  --system       Install to /usr/local/bin instead of ~/.local/bin.
  --bin-dir DIR  Install to a specific bin directory.
  -h, --help     Show this help text.
EOF
}

xml_escape() {
    sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' <<<"$1"
}

remove_existing_action() {
    local input_file=$1
    local output_file=$2

    awk -v action_id="$ACTION_ID" '
        function flush_action() {
            if (buffer != "" && !drop_buffer) {
                printf "%s", buffer
            }
            buffer = ""
            drop_buffer = 0
            in_action = 0
        }

        BEGIN {
            in_action = 0
            buffer = ""
            drop_buffer = 0
        }

        !in_action {
            if ($0 ~ /<action>/) {
                in_action = 1
                buffer = $0 ORS
            } else {
                print
            }
            next
        }

        {
            buffer = buffer $0 ORS
            if ($0 ~ ("<unique-id>" action_id "</unique-id>")) {
                drop_buffer = 1
            }
            if ($0 ~ /<\/action>/) {
                flush_action()
            }
        }

        END {
            if (in_action) {
                flush_action()
            }
        }
    ' "$input_file" > "$output_file"
}

write_uca_file() {
    local destination=$1
    local escaped_command=$2
    local escaped_description=$3
    local escaped_name=$4
    local escaped_icon=$5

    cat > "$destination" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
  <action>
    <icon>${escaped_icon}</icon>
    <name>${escaped_name}</name>
    <submenu></submenu>
    <unique-id>${ACTION_ID}</unique-id>
    <command>${escaped_command}</command>
    <description>${escaped_description}</description>
    <patterns>*</patterns>
    <startup-notify/>
    <directories/>
    <audio-files/>
    <image-files/>
    <other-files/>
    <text-files/>
    <video-files/>
  </action>
</actions>
EOF
}

update_thunar_action() {
    local installed_command=$1
    local escaped_command
    local escaped_description
    local escaped_name
    local escaped_icon
    local tmp_clean
    local tmp_final

    escaped_command=$(xml_escape "\"${installed_command}\" %F")
    escaped_description=$(xml_escape "$ACTION_DESCRIPTION")
    escaped_name=$(xml_escape "$ACTION_NAME")
    escaped_icon=$(xml_escape "$ACTION_ICON")

    install -d -m 755 "$THUNAR_CONFIG_DIR"

    if [[ ! -f "$THUNAR_UCA_FILE" ]]; then
        write_uca_file "$THUNAR_UCA_FILE" "$escaped_command" "$escaped_description" "$escaped_name" "$escaped_icon"
        chmod 644 "$THUNAR_UCA_FILE"
        return
    fi

    if ! grep -q '<actions>' "$THUNAR_UCA_FILE" || ! grep -q '</actions>' "$THUNAR_UCA_FILE"; then
        echo "ERROR: ${THUNAR_UCA_FILE} does not look like a valid Thunar custom actions file." >&2
        exit 1
    fi

    tmp_clean=$(mktemp)
    tmp_final=$(mktemp)

    remove_existing_action "$THUNAR_UCA_FILE" "$tmp_clean"

    awk \
        -v action_id="$ACTION_ID" \
        -v action_command="$escaped_command" \
        -v action_description="$escaped_description" \
        -v action_name="$escaped_name" \
        -v action_icon="$escaped_icon" '
            BEGIN {
                inserted = 0
                action_block = "  <action>\n" \
                    "    <icon>" action_icon "</icon>\n" \
                    "    <name>" action_name "</name>\n" \
                    "    <submenu></submenu>\n" \
                    "    <unique-id>" action_id "</unique-id>\n" \
                    "    <command>" action_command "</command>\n" \
                    "    <description>" action_description "</description>\n" \
                    "    <patterns>*</patterns>\n" \
                    "    <startup-notify/>\n" \
                    "    <directories/>\n" \
                    "    <audio-files/>\n" \
                    "    <image-files/>\n" \
                    "    <other-files/>\n" \
                    "    <text-files/>\n" \
                    "    <video-files/>\n" \
                    "  </action>\n"
            }

            /<\/actions>/ && !inserted {
                printf "%s", action_block
                inserted = 1
            }

            {
                print
            }

            END {
                if (!inserted) {
                    exit 1
                }
            }
        ' "$tmp_clean" > "$tmp_final"

    install -m 644 "$tmp_final" "$THUNAR_UCA_FILE"
    rm -f "$tmp_clean" "$tmp_final"
}

ensure_webp_config() {
    install -d -m 755 "$WEBP_CONFIG_DIR"

    if [[ ! -f "$WEBP_CONFIG_FILE" ]]; then
        printf '%s\n' "$DEFAULT_WEBP_CONFIG_CONTENT" > "$WEBP_CONFIG_FILE"
        chmod 644 "$WEBP_CONFIG_FILE"
        echo "Created config file: ${WEBP_CONFIG_FILE}"
    fi
}

main() {
    local system_install=0
    local bin_dir_override=
    local install_dir=
    local install_path=

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --system)
                system_install=1
                shift
                ;;
            --bin-dir)
                if [[ $# -lt 2 ]]; then
                    echo "ERROR: --bin-dir requires a value." >&2
                    exit 1
                fi
                bin_dir_override=$2
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done

    if [[ ! -f "$SOURCE_SCRIPT" ]]; then
        echo "ERROR: Could not find ${SOURCE_SCRIPT}." >&2
        exit 1
    fi

    if [[ -n "$bin_dir_override" ]]; then
        install_dir=$bin_dir_override
    elif [[ $system_install -eq 1 || $EUID -eq 0 ]]; then
        install_dir=/usr/local/bin
    else
        install_dir="${HOME}/.local/bin"
    fi

    install_path="${install_dir}/${INSTALL_NAME}"

    install -d -m 755 "$install_dir"
    install -m 755 "$SOURCE_SCRIPT" "$install_path"

    ensure_webp_config
    update_thunar_action "$install_path"

    echo "Installed command: ${install_path}"
    echo "Registered Thunar action: ${ACTION_NAME}"

    if [[ ":$PATH:" != *":${install_dir}:"* ]]; then
        echo "NOTE: ${install_dir} is not currently in PATH. Add it if you want to run ${INSTALL_NAME} from a shell."
    fi

    echo "If Thunar is already open, restart it to reload custom actions."
}

main "$@"