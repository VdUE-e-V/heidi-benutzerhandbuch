#!/usr/bin/env bash
set -euo pipefail

output=${1:-.env}
if (( $# > 1 )); then
    printf 'Usage: bash setup-env.sh [output-file]\n' >&2
    exit 1
fi
if [[ -e $output || -L $output ]]; then
    printf 'The file %s already exists and will not be overwritten.\n' "$output" >&2
    exit 1
fi

names=()
values=()

ask() {
    local name=$1 label=$2 default=$3 value
    if [[ -n $default ]]; then
        printf '%s [%s]: ' "$label" "$default"
    else
        printf '%s [empty]: ' "$label"
    fi
    if ! IFS= read -r value; then
        printf '\nInput aborted; no file was created.\n' >&2
        exit 1
    fi
    names+=("$name")
    values+=("${value:-$default}")
}

ask_password() {
    local name=$1 label=$2 value confirmation
    while :; do
        printf '%s (may be empty): ' "$label"
        if ! IFS= read -r -s value; then
            printf '\nInput aborted; no file was created.\n' >&2
            exit 1
        fi
        printf '\nConfirm %s: ' "$label"
        if ! IFS= read -r -s confirmation; then
            printf '\nInput aborted; no file was created.\n' >&2
            exit 1
        fi
        printf '\n'
        if [[ $value == "$confirmation" ]]; then
            names+=("$name")
            values+=("$value")
            return
        fi
        printf 'The entries do not match. Please try again.\n' >&2
    done
}

printf 'Set up the HEiDi environment. Press Enter to accept the displayed default value.\n'
printf 'Passwords are entered invisibly; empty passwords are allowed.\n\n'
printf '%s\n' 'Server and uploads'
ask SERVER_PORT 'Server port' '8080'
ask TOMCAT_CONNECTION_TIMEOUT 'Tomcat connection timeout' '300'
ask TOMCAT_KEEP_ALIVE_TIMEOUT 'Tomcat keep-alive timeout' '300'
ask SERVER_COMPRESSION_ENABLED 'Compression enabled (true/false)' 'false'
ask MAX_FILE_SIZE 'Maximum file size' '100MB'
ask MAX_REQUEST_SIZE 'Maximum request size' '100MB'
printf '\n%s\n' 'Database and Hibernate'
ask MYSQL_HOST 'Database host' 'localhost'
ask MYSQL_PORT 'Database port' '3306'
ask MYSQL_DATABASE_NAME 'Database name' 'heidi'
ask MYSQL_USERNAME 'Database username' 'heidi'
ask_password DB_PASSWORD 'Database password'
ask HIBERNATE_DDL_AUTO 'Hibernate schema management' 'update'
printf '\n%s\n' 'Logging'
ask LOG_LEVEL_ATMOSPHERE 'Atmosphere log level' 'warn'
ask LOG_LEVEL_HIBERNATE_SQL 'Hibernate SQL log level' 'ERROR'
ask LOG_LEVEL_HIBERNATE_SQL_TYPE 'Hibernate SQL type log level' 'error'
ask LOG_LEVEL_HIKARI_CONFIG 'Hikari configuration log level' 'ERROR'
printf '\n%s\n' 'Administrator and storage'
ask ADMIN_INITIAL_USERNAME 'Initial administrator username' 'admin'
ask_password ADMIN_INITIAL_PASSWORD 'Initial administrator password'
ask STORAGE_PATH 'Deprecated storage path' ''
printf '\n%s\n' 'Email'
ask MAIL_USERNAME 'Email username' ''
ask_password MAIL_PASSWORD 'Email password'
ask MAIL_SERVER 'Email server' ''
ask MAIL_TRANSPORT_PROTOCOL 'Email transport protocol' ''
ask MAIL_PORT 'SMTP port' ''
ask MAIL_USE_AUTH 'SMTP authentication (true/false)' ''
ask MAIL_START_TLS_ENABLE 'SMTP STARTTLS enabled (true/false)' ''
ask MAIL_START_TLS_REQUIRED 'SMTP STARTTLS required (true/false)' ''

umask 077
if ! (set -o noclobber; : > "$output") 2>/dev/null; then
    printf 'Could not create file %s.\n' "$output" >&2
    exit 1
fi
cleanup() { rm -f -- "$output"; }
trap cleanup EXIT
for i in "${!names[@]}"; do
    printf 'export %s=%q\n' "${names[i]}" "${values[i]}" >> "$output"
done
trap - EXIT
source_path=$output
[[ $source_path == */* ]] || source_path=./$source_path
printf '\nConfiguration saved to %s. To load it: source %q\n' "$output" "$source_path"