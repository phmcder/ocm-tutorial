#!/bin/sh
set -eu

system_bundle=/etc/ssl/certs/ca-certificates.crt
endpoint=https://dl.k8s.io/release/stable.txt
# Optional path that receives only the discovered issuing CA certificates.
issuing_ca_output=${1:-}
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
trap 'exit 1' HUP INT TERM
mkdir "$work_dir/empty-ca-directory"

if [ ! -s "$system_bundle" ]; then
  echo "Error: the Linux CA bundle must be nonempty." >&2
  exit 1
fi

# Trust-on-first-use discovery only; the completed bundle is verified below.
echo "Discovering peer issuing CAs without TLS verification (trust on first use)." >&2
curl --insecure --silent --show-error --fail \
  --connect-timeout 15 --max-time 45 \
  --output /dev/null --write-out '%{certs}' \
  "$endpoint" > "$work_dir/peer-chain"

# The first certificate is the site leaf, which must never become a trusted CA.
awk '
  /-----BEGIN CERTIFICATE-----/ { count++; active = 1 }
  active && count > 1 { print }
  /-----END CERTIFICATE-----/ { active = 0; complete++ }
  END {
    if (count < 2 || active || count != complete) {
      print "Error: peer did not return a complete issuing CA chain." > "/dev/stderr"
      exit 1
    }
  }
' "$work_dir/peer-chain" > "$work_dir/issuing-cas.pem"

cat "$system_bundle" > "$work_dir/bundle.pem"
printf '\n' >> "$work_dir/bundle.pem"
cat "$work_dir/issuing-cas.pem" >> "$work_dir/bundle.pem"

curl --silent --show-error --fail \
  --connect-timeout 15 --max-time 45 \
  --cacert "$work_dir/bundle.pem" --capath "$work_dir/empty-ca-directory" \
  --output /dev/null "$endpoint"

echo "Verified HTTPS with the Linux CA bundle plus discovered issuing CAs." >&2

if [ -n "$issuing_ca_output" ]; then
  cp "$work_dir/issuing-cas.pem" "$issuing_ca_output"
  echo "Wrote discovered issuing CAs to $issuing_ca_output." >&2
fi

cat "$work_dir/bundle.pem"
