.PHONY: build test dump app run

build:
	swift build

test:
	swift test

dump:
	swift run ZulipMac --dump

app:
	./scripts/package.sh

run: app
	open dist/ZulipMac.app
