# By default, let's print out some help
.PHONY: usage
usage:
	@echo "$$(tput bold)haha todo$$(tput sgr0)"

ifdef FEATURES
features=--features=$(FEATURES)
endif

ifndef DEBUG
release=--release
endif

.PHONY: setup
setup: cargo install elf2tab
	cargo install stack-sizes
	cargo miri setup
	rustup target add --toolchain stable thumbv7em-none-eabi

# Prints out the sizes of the example binaries.
.PHONY: print-sizes
print-sizes: examples
	cargo run --release -p print_sizes


# Arguments to pass to cargo to exclude crates that require a Tock runtime.
# This is largely libtock_runtime and crates that depend on libtock_runtime.
# Used when we need to build a crate for the host OS, as libtock_runtime only
# supports running on Tock.
EXCLUDE_RUNTIME := --exclude libtock --exclude libtock_runtime \
	--exclude libtock_debug_panic --exclude libtock_small_panic

# Arguments to pass to cargo to exclude crates that cannot be tested by Miri. In
# addition to excluding libtock_runtime, Miri also cannot test proc macro crates
# (and in fact will generate broken data that causes cargo test to fail).
EXCLUDE_MIRI := $(EXCLUDE_RUNTIME) --exclude ufmt-macros

# Arguments to pass to cargo to exclude `std` and crates that depend on it. Used
# when we build a crate for an embedded target, as those targets lack `std`.
EXCLUDE_STD := --exclude libtock_unittest --exclude print_sizes \
               --exclude runner --exclude syscalls_tests

# Currently, all of our crates should build with a stable toolchain. This
# verifies our crates don't depend on unstable features by using cargo check. We
# specify a different target directory so this doesn't flush the cargo cache of
# the primary toolchain.
.PHONY: test-stable
test-stable:
	CARGO_TARGET_DIR="target/stable-toolchain" cargo +stable check --workspace \
		$(EXCLUDE_RUNTIME)
	CARGO_TARGET_DIR="target/stable-toolchain" LIBTOCK_PLATFORM=nrf52 cargo \
		+stable check $(EXCLUDE_STD) --target=thumbv7em-none-eabi --workspace

.PHONY: test
test: examples test-stable
	cargo test $(EXCLUDE_RUNTIME) --workspace
	LIBTOCK_PLATFORM=nrf52 cargo fmt --all -- --check
	cargo clippy --all-targets $(EXCLUDE_RUNTIME) --workspace
	LIBTOCK_PLATFORM=nrf52 cargo clippy $(EXCLUDE_STD) \
		--target=thumbv7em-none-eabi --workspace
	LIBTOCK_PLATFORM=hifive1 cargo clippy $(EXCLUDE_STD) \
		--target=riscv32imac-unknown-none-elf --workspace
	MIRIFLAGS="-Zmiri-strict-provenance -Zmiri-symbolic-alignment-check" \
		cargo miri test $(EXCLUDE_MIRI) --workspace
	echo '[ SUCCESS ] libtock-rs tests pass'

.PHONY: analyse-stack-sizes
analyse-stack-sizes:
	cargo stack-sizes $(release) --example $(EXAMPLE) $(features) -- -Z emit-stack-sizes

.PHONY: audio
audio:
	LIBTOCK_PLATFORM=nrf52840 cargo run --bin audio $(features) \
		--target=thumbv7em-none-eabi $(release)
	mkdir -p target/tbf/nrf52840
	cp target/thumbv7em-none-eabi/release/audio.tab \
		target/thumbv7em-none-eabi/release/audio.tbf \
		target/tbf/nrf52840

.PHONY: ui
ui:
	LIBTOCK_PLATFORM=nrf52840 cargo run --bin ui $(features) \
		--target=thumbv7em-none-eabi $(release)
	mkdir -p target/tbf/nrf52840
	cp target/thumbv7em-none-eabi/release/ui.tab \
		target/thumbv7em-none-eabi/release/ui.tbf \
		target/tbf/nrf52840

.PHONY: ble
ble:
	LIBTOCK_PLATFORM=nrf52840 cargo run --bin ble $(features) \
		--target=thumbv7em-none-eabi $(release)
	mkdir -p target/tbf/nrf52840
	cp target/thumbv7em-none-eabi/release/ble.tab \
		target/thumbv7em-none-eabi/release/ble.tbf \
		target/tbf/nrf52840

.PHONY: flash-nrf52840
flash-nrf52840:
	LIBTOCK_PLATFORM=nrf52840 cargo run --example $(EXAMPLE) $(features) \
		--target=thumbv7em-none-eabi $(release) -- --deploy=tockloader

.PHONY: clean
clean:
	cargo clean
	$(MAKE) -C tock clean
