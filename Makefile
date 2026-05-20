.PHONY: install update uninstall

APP_NAME   := $(shell . ./config/defaults.conf && echo $$APP_NAME)
SUMMON_CMD := $(shell . ./config/defaults.conf && echo $$SUMMON_COMMAND)

install:
	sudo ./install.sh

update:
	sudo ./install.sh --update

uninstall:
	@echo "Removing $(APP_NAME)..."
	sudo rm -f "/usr/local/bin/$(SUMMON_CMD)"
	sudo rm -rf "/usr/local/share/$(APP_NAME)"
	@echo "Done. /var/log/batchventoydeployer.log was preserved."
