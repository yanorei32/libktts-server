use std::ffi::CString;
use std::os::fd::FromRawFd;
use std::fs::File;
use std::io::{Read, Seek};
use std::net::SocketAddr;
use std::os::fd::AsRawFd;
use std::os::fd::OwnedFd;

use clap::Parser;
use tokio::sync::{mpsc, oneshot};
use tokio::signal::unix::{signal, SignalKind};
use utf16string::{LittleEndian, WString};

mod ffi;
mod model;
mod web;

extern "C" fn empty_callback(_: i32, _: i32, _: i32, _: i32) {}

#[derive(Parser)]
struct Cli {
    #[clap(long, env, default_value = "0.0.0.0:3000")]
    listen: SocketAddr,

    #[clap(long, env, default_value = "/usr/share/apps/kttsdb/")]
    dic: String,
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    tracing_subscriber::fmt().init();

    let cli = Cli::parse();

    let ctx = unsafe { ffi::SynthInfoMalloc() };

    if ctx.is_null() {
        panic!("Error: SynthInfoMalloc failed.");
    }

    let (req_tx, mut req_rx) = mpsc::channel::<model::RequestContext>(16);
    let (shutdown_tx, mut shutdown_rx) = oneshot::channel::<Result<(), std::io::Error>>();

    let dic = CString::new(cli.dic.as_str()).unwrap();

    if unsafe { ffi::InputDic(dic.as_ptr(), empty_callback) } != 1 {
        panic!("Error: InputDic returned unexpected value.");
    }

    let listener = tokio::net::TcpListener::bind(cli.listen).await.unwrap();

    tracing::info!("Listening on: {}", listener.local_addr().unwrap());

    tokio::spawn(async move {
        shutdown_tx
            .send(web::serve(listener, req_tx).await)
            .unwrap();
    });

    let mut sigterm = signal(SignalKind::terminate()).unwrap();

    loop {
        tokio::select! {
            _ = sigterm.recv() => {
                break;
            }
            _ = tokio::signal::ctrl_c() => {
                break;
            },
            error = &mut shutdown_rx => {
                error.unwrap().unwrap();
                break;
            },
            req = req_rx.recv() => {
                let mut req = req.unwrap();

                // create temporary memfd
                let fd = unsafe { libc::syscall(356, "tts".as_ptr(), 1) as i32 };

                if fd < 0 {
                    panic!("Failed to create memfd");
                }

                let fd = unsafe { OwnedFd::from_raw_fd(fd) };

                let path = CString::new(format!("/proc/self/fd/{}", fd.as_raw_fd()) ).unwrap();

                // create NULL terminated UTF-16 buffer
                req.text.push('\0');
                let text: WString<LittleEndian> = WString::from(&req.text);

                // tts
                unsafe { ffi::TextToPcmFile(text.as_bytes().as_ptr(), path.as_ptr(), empty_callback) };

                // as file
                let mut file = File::from(fd);

                // seek to start
                file.rewind().unwrap();

                // read to buffer
                let mut bytes = vec![];
                file.read_to_end(&mut bytes).unwrap();

                // response
                req.response.send(model::ResponseContext {
                    bytes,
                }).unwrap();
            }
        }
    }
}
