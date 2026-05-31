VERSION ?= $(shell cat secnpmlly/version | tr -d '[:space:]')

.PHONY: release patch minor major tag push clean version

version:
	@echo "secnpmlly $(VERSION)"

# ── Releases ──────────────────────────────────────────────────
# Usage:
#   make patch          -> 0.4.0 -> 0.4.1
#   make minor          -> 0.4.0 -> 0.5.0
#   make major          -> 0.4.0 -> 1.0.0
#   make release V=1.2.3  -> explicit version

patch:
	@bash scripts/bump.sh patch

minor:
	@bash scripts/bump.sh minor

major:
	@bash scripts/bump.sh major

release:
ifndef V
	@echo "Usage: make release V=1.2.3"
	@exit 1
endif
	@bash scripts/bump.sh "$(V)"

# ── Tag & push ────────────────────────────────────────────────

tag:
	@git tag -s "v$(VERSION)" -m "Release v$(VERSION)"
	@echo "Tagged v$(VERSION) (GPG signed)"
	@echo "Push with: make push"

push:
	@git push origin main
	@git push origin "v$(VERSION)"
	@echo "Pushed v$(VERSION) to origin"

# ── Setup ─────────────────────────────────────────────────────

setup-gpg:
	@bash setup-gpg.sh

install:
	@bash apply-protections.sh

clean:
	@rm -rf $(HOME)/.local/share/secnpmlly
	@rm -f $(HOME)/.local/bin/secnpmlly
	@echo "Removed secnpmlly installation"
