# ChargeNet mobile helpers. Run from chargenet-mobile/.
SHELL := /bin/bash

.PHONY: get analyze test check

## Flutter
get:
	flutter pub get

analyze:
	flutter analyze

test:
	flutter test

check: analyze test
