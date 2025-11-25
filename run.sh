#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

SQUEEZE_ROOTFS="$DIR/../squeeze_root"
LIBKTTSPROJECT_ROOT="$DIR/../libkttsproject_root"

RUSTFLAGS="-L $(pwd)/../libkttsproject_root/usr/lib/ -L $(pwd)/../squeeze_root/usr/lib/" \
	cargo build --target i686-unknown-linux-gnu

LD_LIBRARY_PATH="/usr/lib32/:$LIBKTTSPROJECT_ROOT/usr/lib/:$SQUEEZE_ROOTFS/lib:$SQUEEZE_ROOTFS/usr/lib/" \
	"$DIR/target/i686-unknown-linux-gnu/debug/libktts-server" \
		--dic "$LIBKTTSPROJECT_ROOT/usr/share/apps/kttsdb/" \
		--listen 0.0.0.0:3000
