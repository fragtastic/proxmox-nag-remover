.PHONY: build test clean

build:
	dpkg-buildpackage -us -uc -b

test:
	sh tests/test-proxmox-nag-remover.sh

clean:
	dh_clean
