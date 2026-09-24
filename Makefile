.PHONY: all build test clean

# Debhelper invokes the default Make target through dh_auto_build.  This
# package has no compilation step; keeping the default target empty avoids
# recursively starting dpkg-buildpackage from inside dpkg-buildpackage.
all:

build:
	dpkg-buildpackage -us -uc -b

test:
	sh tests/test-proxmox-nag-remover.sh

# There are no generated upstream files to clean. Debhelper performs its own
# package-tree cleanup after this target returns.
clean:
