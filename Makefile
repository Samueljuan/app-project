ENV_FILE ?= env.json

.PHONY: run build

run:
	flutter run -d chrome --dart-define-from-file=$(ENV_FILE)

build:
	flutter build web --dart-define-from-file=$(ENV_FILE)
