BUILD_DIR ?= build
JOBS ?=

CMAKE ?= cmake
CMAKE_CONFIGURE_ARGS ?=
CMAKE_BUILD_ARGS ?=
CMAKE_INSTALL_ARGS ?=
TARGET ?= curl-impersonate
CURL_BIN ?= $(BUILD_DIR)/deps/build/curl/src/curl-impersonate
LIBUNISTRING_VERSION ?= 1.1
LIBUNISTRING_URL ?= https://ftp.gnu.org/gnu/libunistring/libunistring-$(LIBUNISTRING_VERSION).tar.gz
LIBIDN2_VERSION ?= 2.3.7
LIBIDN2_URL ?= https://ftp.gnu.org/gnu/libidn/libidn2-$(LIBIDN2_VERSION).tar.gz
PREPARE_LIBIDN2 ?= auto

all: build checkbuild
.PHONY: all

prepare-libidn2:
	BUILD_DIR="$(BUILD_DIR)" \
	CMAKE_CONFIGURE_ARGS="$(CMAKE_CONFIGURE_ARGS)" \
	JOBS="$(JOBS)" \
	LIBUNISTRING_VERSION="$(LIBUNISTRING_VERSION)" \
	LIBUNISTRING_URL="$(LIBUNISTRING_URL)" \
	LIBIDN2_VERSION="$(LIBIDN2_VERSION)" \
	LIBIDN2_URL="$(LIBIDN2_URL)" \
	PREPARE_LIBIDN2="$(PREPARE_LIBIDN2)" \
	./scripts/build-libidn2.sh
.PHONY: prepare-libidn2

configure: prepare-libidn2
	$(CMAKE) -S . -B $(BUILD_DIR) $(CMAKE_CONFIGURE_ARGS)
.PHONY: configure

build: configure
	$(CMAKE) --build $(BUILD_DIR) $(if $(JOBS),--parallel $(JOBS),) $(CMAKE_BUILD_ARGS)
.PHONY: build

target: configure
	$(CMAKE) --build $(BUILD_DIR) --target $(TARGET) $(if $(JOBS),--parallel $(JOBS),) $(CMAKE_BUILD_ARGS)
.PHONY: target

checkbuild:
	@test -x "$(CURL_BIN)" || { echo "Missing binary: $(CURL_BIN)"; exit 1; }
	@v="$$( "$(CURL_BIN)" -V )"; \
	echo "$$v"; \
	echo "$$v" | grep -q zlib; \
	echo "$$v" | grep -q zstd; \
	echo "$$v" | grep -q brotli; \
	echo "$$v" | grep -q nghttp2; \
	echo "$$v" | grep -q BoringSSL; \
	echo "$$v" | grep -Eq "AppleIDN|libidn2"; \
	echo "Build OK"
.PHONY: checkbuild

install: configure
	$(CMAKE) --build $(BUILD_DIR) --target install-all $(if $(JOBS),--parallel $(JOBS),)
.PHONY: install

install-strip: configure
	$(CMAKE) --build $(BUILD_DIR) --target curl-install $(if $(JOBS),--parallel $(JOBS),)
	$(CMAKE) --install $(BUILD_DIR) --strip $(CMAKE_INSTALL_ARGS)
.PHONY: install-strip

uninstall:
	$(CMAKE) --build $(BUILD_DIR) --target uninstall
.PHONY: uninstall

clean:
	$(CMAKE) --build $(BUILD_DIR) --target clean
.PHONY: clean

distclean:
	rm -rf $(BUILD_DIR)
.PHONY: distclean
