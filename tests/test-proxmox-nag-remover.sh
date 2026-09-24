#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script=$root/scripts/proxmox-nag-remover
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
target=$tmp/proxmoxlib.js
backup=$target.proxmox-nag-remover.bak

write_fixture() {
    cat >"$target" <<'EOF'
const unrelated = Ext.Msg.show({ message: 'leave this alone', title: gettext('No valid subscription') });
Ext.Msg.show({
    title: gettext('No valid subscription'),
    message: gettext('Subscription required'),
    buttons: Ext.Msg.OK,
});
EOF
}

assert_contains() { grep -Fq "$2" "$1" || { echo "missing expected text: $2" >&2; exit 1; }; }
assert_not_contains() { ! grep -Fq "$2" "$1" || { echo "unexpected text: $2" >&2; exit 1; }; }

write_fixture
cp "$target" "$tmp/original"
"$script" status --target "$target" --no-restart >/dev/null && exit 1 || true
"$script" apply --target "$target" --no-restart >/dev/null
assert_contains "$target" '/* proxmox-nag-remover: subscription dialog disabled */ void ({'
assert_contains "$target" "const unrelated = Ext.Msg.show"
cmp "$backup" "$tmp/original"
"$script" apply --target "$target" --no-restart >/dev/null
"$script" restore --target "$target" --no-restart >/dev/null
cmp "$target" "$tmp/original"

# An upstream update receives a fresh backup before the newly needed patch.
printf '%s\n' "Ext.Msg.show({ title: gettext('No valid subscription'), message: 'new upstream' });" >"$target"
cp "$target" "$tmp/new-upstream"
"$script" apply --target "$target" --no-restart >/dev/null
cmp "$backup" "$tmp/new-upstream"

# Local edits made after patching must not be lost during restoration.
printf '%s\n' "const administratorChange = true;" >>"$target"
cp "$target" "$tmp/locally-modified-patch"
if "$script" restore --target "$target" --no-restart >/dev/null 2>&1; then
    echo "locally modified patched fixture was overwritten during restore" >&2
    exit 1
fi
cmp "$target" "$tmp/locally-modified-patch"

# A similarly named dialog with title not first must be rejected unchanged.
printf '%s\n' "Ext.Msg.show({ message: 'x', title: gettext('No valid subscription') });" >"$target"
if "$script" apply --target "$target" --no-restart >/dev/null 2>&1; then
    echo "unsupported fixture was patched" >&2
    exit 1
fi
assert_not_contains "$target" 'proxmox-nag-remover: subscription dialog disabled'

# Never replace an unmarked file with a stale backup.  This can happen when a
# future toolkit upgrade changes the dialog layout before package removal.
printf '%s\n' "const futureUpstreamLayout = true;" >"$target"
cp "$target" "$tmp/future-upstream"
if "$script" restore --target "$target" --no-restart >/dev/null 2>&1; then
    echo "unmarked upstream fixture was overwritten during restore" >&2
    exit 1
fi
cmp "$target" "$tmp/future-upstream"

# A stray marker string must not hide an active supported dialog.
cat >"$target" <<'EOF'
// proxmox-nag-remover: subscription dialog disabled
Ext.Msg.show({ title: gettext('No valid subscription'), message: 'active' });
EOF
"$script" apply --target "$target" --no-restart >/dev/null
assert_contains "$target" '/* proxmox-nag-remover: subscription dialog disabled */ void ({'
assert_not_contains "$target" "Ext.Msg.show({ title: gettext('No valid subscription')"

# Similar text in another identifier, a comment, or a string is not executable
# global Ext code and must be rejected without modification.
cat >"$target" <<'EOF'
MyExt.Msg.show({ title: gettext('No valid subscription'), message: 'namespace' });
// Ext.Msg.show({ title: gettext('No valid subscription'), message: 'comment' });
const sample = "Ext.Msg.show({ title: gettext('No valid subscription') })";
EOF
cp "$target" "$tmp/non-global-original"
if "$script" apply --target "$target" --no-restart >/dev/null 2>&1; then
    echo "non-global fixture was patched" >&2
    exit 1
fi
cmp "$target" "$tmp/non-global-original"

echo "proxmox-nag-remover tests: passed"
