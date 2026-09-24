# proxmox-nag-remover

An unofficial Debian package that suppresses the Proxmox VE web UI's **“No valid
subscription”** modal.

This is a convenience customization for lab or personal systems, not a
production-supported alternative to a Proxmox subscription. Use supported
repositories and a subscription when appropriate.

## What it does

The installed `/usr/sbin/proxmox-nag-remover` locates only an `Ext.Msg.show`
call where the first object property is exactly
`title: gettext('No valid subscription')`. It changes that call to `void (...)`
with a marker comment, so the object is evaluated but no dialog is shown. It
does not use a broad text replacement.

Before each new patch it stores the current upstream file at
`/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.proxmox-nag-remover.bak`.
The package's APT `DPkg::Post-Invoke` hook reapplies after updates and always
exits successfully so it cannot break APT. `pveproxy` is restarted only if the
script actually changes file content.

On package removal (but not an upgrade), the maintainer script restores the
backup only when the installed file byte-for-byte matches the patch generated
from that backup. It will never overwrite later administrator edits or a newer,
unsupported upstream layout. Purging removes the saved backup.

## Build and test

```sh
# On Debian/Proxmox, install the standard packaging tools once:
sudo apt install build-essential debhelper

make test
make build
sudo apt install ../proxmox-nag-remover_1.0.0_all.deb
```

The package itself compiles no native code. `build-essential` is present because
Debian's standard `dpkg-buildpackage` dependency check treats it as an implicit
build dependency; it is not included in the resulting package. Install
`lintian` as well if you want to run the same package-policy checks used by CI.
The optional `dch` command shown below is provided by the `devscripts` package;
the changelog can also be edited manually.

Use `proxmox-nag-remover status`, `apply`, or `restore` to inspect or control
the patch. `--target PATH --no-restart` exists for fixture testing.

## GitHub Releases

The [build workflow](.github/workflows/build-deb.yml) runs for pushes, pull
requests, and manual `workflow_dispatch` runs. It:

1. Runs the fixture test suite.
2. Builds the binary package with `dpkg-buildpackage`.
3. Inspects the package and runs Lintian with errors treated as failures.
4. Uses a temporary workflow artifact to pass the validated package between
   jobs.
5. For a stable SemVer tag, publishes a permanent GitHub Release containing
   the `.deb` and `SHA256SUMS` with automatically generated release notes.

Release tags must have the exact form `vMAJOR.MINOR.PATCH`, such as `v1.0.1`.
The version without the `v` must exactly match the newest entry in
`debian/changelog`; mismatches and prerelease tags fail before publication.

To publish a release:

```sh
# The current tree is already version 1.0.0, so its initial release is:
git tag -a v1.0.0 -m "proxmox-nag-remover v1.0.0"
git push origin HEAD v1.0.0

# For subsequent releases, update debian/changelog first, for example:
dch --distribution unstable --newversion 1.0.1 "Describe the release."
git add debian/changelog
git commit -m "release: prepare v1.0.1"

# Create and push the matching annotated tag:
git tag -a v1.0.1 -m "proxmox-nag-remover v1.0.1"
git push origin HEAD v1.0.1
```

After the tagged workflow succeeds, download the package from the repository's
**Releases** page. Branch, pull-request, and manually dispatched builds do not
create releases.

Verify the downloaded package before installing it:

```sh
sha256sum --check SHA256SUMS
sudo apt install ./proxmox-nag-remover_1.0.1_all.deb
```
