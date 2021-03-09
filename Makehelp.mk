#!/usr/bin/env make

.DEFAULT_GOAL := help

# COLORS
GREEN  := $(shell printf "\e[1;32m" )
YELLOW := $(shell printf "\e[1;33m" )
WHITE  := $(shell printf "\e[1;37m" )
RED    := $(shell printf "\e[1;31m" )
CYAN   := $(shell printf "\e[1;34m" )
RESET  := $(shell printf "\e[0m" )

TARGET_MAX_CHAR_NUM := 20

###Help
## Show help
help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/(^[a-zA-Z\-\.\_0-9]+:)|(^###[a-zA-Z]+)/ { \
		header = match($$1, /^###(.*)/); \
		if (header) { \
			title = substr($$1, 4, length($$1)); \
			printf "${CYAN}%s${RESET}\n", title; \
		} \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)


