#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

SQUEEZE_ROOTFS="$DIR/../squeeze_root"
LIBKTTSPROJECT_ROOTFS="$DIR/../libkttsproject_root"

RUSTFLAGS="-L $LIBKTTSPROJECT_ROOTFS/usr/lib/ -L $SQUEEZE_ROOTFS/usr/lib/" \
	cargo build --target i686-unknown-linux-gnu

LD_LIBRARY_PATH="/usr/lib32/:$LIBKTTSPROJECT_ROOTFS/usr/lib/:$SQUEEZE_ROOTFS/lib:$SQUEEZE_ROOTFS/usr/lib/" \
	"$DIR/target/i686-unknown-linux-gnu/debug/libktts-server" \
		--dic "$LIBKTTSPROJECT_ROOTFS/usr/share/apps/kttsdb/" \
		--listen 0.0.0.0:3000
