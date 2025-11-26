FROM debian:trixie-slim AS rpm-extract-env

RUN --mount=type=bind,source=./packages,target=/packages \
	apt-get update && \
	apt-get install -y rpm2cpio cpio && \
	mkdir /libkttsproject_root && \
	cd /libkttsproject_root && \
	rpm2cpio /packages/libkttsproject-4.0-1.i386.rpm | cpio -idm


FROM debian:trixie-slim AS debian-squeeze-extract-env

RUN apt-get update && \
	apt-get install -y debootstrap debian-keyring && \
	debootstrap \
		--include=libartsc0,libqt3-mt,libxext6,libx11-6 \
		--arch i386 \
		--variant=minbase \
		squeeze /squeeze_root https://archive.debian.org/debian/ && \
	cd /squeeze_root/usr/lib/ && \
	ln -s libartsc.so.0 libartsc.so


FROM rust:1.91.1-trixie AS build-env

WORKDIR /usr/src

RUN cargo new libktts-server
COPY LICENSE Cargo.toml Cargo.lock build.rs /usr/src/libktts-server/
WORKDIR /usr/src/libktts-server
ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse

RUN apt-get update && \
	apt-get install -y libc6-dev-i386 && \
	rustup target add i686-unknown-linux-gnu

RUN cargo install cargo-license && cargo license \
	--authors \
	--do-not-bundle \
	--avoid-dev-deps \
	--avoid-build-deps \
	--filter-platform i686-unknown-linux-gnu \
	> CREDITS

RUN --mount=type=bind,from=debian-squeeze-extract-env,source=/squeeze_root,target=/squeeze_root \
	--mount=type=bind,from=rpm-extract-env,source=/libkttsproject_root,target=/libkttsproject_root \
	RUSTFLAGS="-L /libkttsproject_root/usr/lib/ -L /squeeze_root/usr/lib/" \
		cargo build --release --target i686-unknown-linux-gnu

COPY src/ /usr/src/libktts-server/src/
COPY assets/ /usr/src/libktts-server/assets/

RUN --mount=type=bind,from=debian-squeeze-extract-env,source=/squeeze_root,target=/squeeze_root \
	--mount=type=bind,from=rpm-extract-env,source=/libkttsproject_root,target=/libkttsproject_root \
	touch src/* assets/* && \
	RUSTFLAGS="-L /libkttsproject_root/usr/lib/ -L /squeeze_root/usr/lib/" \
		cargo build --release --target i686-unknown-linux-gnu


FROM debian:trixie-slim

RUN apt-get update && apt-get install -y libc6-i386

COPY --from=debian-squeeze-extract-env \
	/squeeze_root /squeeze_root

COPY --from=rpm-extract-env \
	/libkttsproject_root /libkttsproject_root

COPY --chown=root:root --from=build-env \
	/usr/src/libktts-server/CREDITS \
	/usr/src/libktts-server/LICENSE \
	/usr/share/licenses/libktts-server

COPY --chown=root:root --from=build-env \
	/usr/src/libktts-server/target/i686-unknown-linux-gnu/release/libktts-server \
	/usr/bin/libktts-server

ENV LD_LIBRARY_PATH=/usr/lib32/:/libkttsproject_root/usr/lib/:/squeeze_root/lib:/squeeze_root/usr/lib
ENV DIC=/libkttsproject_root/usr/share/apps/kttsdb/

CMD ["/usr/bin/libktts-server"]
