FROM debian:trixie-slim AS rpm-extract-env

RUN --mount=type=bind,source=./packages,target=/packages \
	apt-get update && \
	apt-get install -y rpm2cpio cpio && \
	mkdir /libkttsproject_root && \
	cd /libkttsproject_root && \
	rpm2cpio /packages/libkttsproject-4.0-1.i386.rpm | cpio -idm


FROM debian:trixie-slim AS debian-squeeze-dev-extract-env

RUN apt-get update && \
	apt-get install -y debootstrap debian-keyring && \
	debootstrap \
		--include=libartsc0,libqt3-mt,gcc,libc6-dev \
		--arch i386 \
		--variant=minbase \
		squeeze /squeeze_root https://archive.debian.org/debian/ && \
	cd /squeeze_root/usr/lib/ && \
	ln -s libartsc.so.0 libartsc.so && \
    ln -sf ../../lib/libgcc_s.so.1 libgcc_s.so && \
    ln -sf ../../lib/libdl.so.2 libdl.so && \
    find /squeeze_root -name "crtbeginS.o" -exec cp {} . \; && \
    find /squeeze_root -name "crtendS.o" -exec cp {} . \;


FROM debian:trixie-slim AS debian-squeeze-runtime-extract-env

RUN apt-get update && \
	apt-get install -y debootstrap debian-keyring && \
	debootstrap \
		--include=libartsc0,libqt3-mt  \
		--arch i386 \
		--variant=minbase \
		squeeze /squeeze_root https://archive.debian.org/debian/


FROM rust:1.92.0-trixie AS build-env

WORKDIR /usr/src

RUN cargo new libktts-server
COPY LICENSE Cargo.toml Cargo.lock build.rs /usr/src/libktts-server/
WORKDIR /usr/src/libktts-server
ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse

RUN apt-get update && \
	apt-get install -y clang && \
	rustup target add i686-unknown-linux-gnu

RUN cargo install cargo-license && cargo license \
	--authors \
	--do-not-bundle \
	--avoid-dev-deps \
	--avoid-build-deps \
	--filter-platform i686-unknown-linux-gnu \
	> CREDITS

RUN printf '#[unsafe(no_mangle)]\npub extern "C" fn getauxval(_type: u64) -> u64 { 0 }\nfn main() {}' > src/main.rs

RUN --mount=type=bind,from=debian-squeeze-dev-extract-env,source=/squeeze_root,target=/squeeze_root \
	--mount=type=bind,from=rpm-extract-env,source=/libkttsproject_root,target=/libkttsproject_root \
    RUSTFLAGS="-C linker=clang -C link-arg=-m32 -C link-arg=--sysroot=/squeeze_root -C link-arg=-L/squeeze_root/usr/lib -C link-arg=-L/libkttsproject_root/usr/lib -C link-arg=-L/squeeze_root/usr/lib/qt-3.3/lib -C link-arg=-L/squeeze_root/usr/lib/gcc/i486-linux-gnu/4.4 -C link-arg=-Wl,-rpath=/lib" \
		cargo build --release --target i686-unknown-linux-gnu

COPY src/ /usr/src/libktts-server/src/
COPY assets/ /usr/src/libktts-server/assets/

RUN --mount=type=bind,from=debian-squeeze-dev-extract-env,source=/squeeze_root,target=/squeeze_root \
	--mount=type=bind,from=rpm-extract-env,source=/libkttsproject_root,target=/libkttsproject_root \
	touch src/* assets/* && \
    RUSTFLAGS="-C linker=clang -C link-arg=-m32 -C link-arg=--sysroot=/squeeze_root -C link-arg=-L/squeeze_root/usr/lib -C link-arg=-L/libkttsproject_root/usr/lib -C link-arg=-L/squeeze_root/usr/lib/qt-3.3/lib -C link-arg=-L/squeeze_root/usr/lib/gcc/i486-linux-gnu/4.4 -C link-arg=-Wl,-rpath=/lib" \
		cargo build --release --target i686-unknown-linux-gnu


FROM scratch

COPY --from=debian-squeeze-runtime-extract-env \
	/squeeze_root /

COPY --from=rpm-extract-env \
	/libkttsproject_root /

COPY --chown=root:root --from=build-env \
	/usr/src/libktts-server/CREDITS \
	/usr/src/libktts-server/LICENSE \
	/usr/share/licenses/libktts-server

COPY --chown=root:root --from=build-env \
	/usr/src/libktts-server/target/i686-unknown-linux-gnu/release/libktts-server \
	/usr/bin/libktts-server

CMD ["/usr/bin/libktts-server"]
