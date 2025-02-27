#!/usr/bin/env bash

set -eu
shopt -s nullglob

CODE_SIGNING_KEY_FINGERPRINT="A1198702FC3E0A09A9AE5B75D5A1D4F266DE8DDF"
UPLOAD_SERVER="releases.mullvad.net"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UPLOAD_DIR="$SCRIPT_DIR/upload"

cd "$UPLOAD_DIR"

while true; do
    sleep 10
    for checksums_path in *.sha256; do
        sleep 1

        # Strip everything from the last "+" in the file name to only keep the version and tag (if
        # present).
        version="${checksums_path%+*}"
        if ! sha256sum --quiet -c "$checksums_path"; then
            echo "Failed to verify checksums for $version"
            continue
        fi

        if [[ $version == *"-dev-"* ]]; then
            upload_path="builds"
        else
            upload_path="releases"
        fi

        files=$(awk '{print $2}' < "$checksums_path")
        for file in $files; do
            file_upload_dir="$upload_path/$version"
            if [[ ! $file == MullvadVPN-* ]]; then
                file_upload_dir="$file_upload_dir/additional-files"
            fi

            rsync -av --rsh='ssh -p 1122' "$file" "build@$UPLOAD_SERVER:$file_upload_dir/" || continue

            if [[ $file == MullvadVPN-* ]]; then
                rm -f "$file.asc"
                gpg -u $CODE_SIGNING_KEY_FINGERPRINT --pinentry-mode loopback --sign --armor --detach-sign "$file"
                rsync -av --rsh='ssh -p 1122' "$file.asc" "build@$UPLOAD_SERVER:$file_upload_dir/" || continue
                rm -f "$file.asc"
            fi

            # shellcheck disable=SC2216
            yes | rm "$file"
        done

        # shellcheck disable=SC2216
        yes | rm "$checksums_path"
    done
done
