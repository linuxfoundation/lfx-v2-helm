# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT

MEGALINTER_IMAGE := ghcr.io/oxsecurity/megalinter-documentation@sha256:ca4a68b4758b55dd34e2206911a9400023b250978174ea147068d9e959054e12  # v10.2.0

.PHONY: megalinter
megalinter:
	docker pull $(MEGALINTER_IMAGE)
	docker run --rm --platform linux/amd64 -e GITHUB_TOKEN -v '$(CURDIR):/tmp/lint:rw' $(MEGALINTER_IMAGE)
