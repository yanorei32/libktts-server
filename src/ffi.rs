use std::ffi::c_char;
use std::ffi::c_void;

unsafe extern "C" {
    pub fn SynthInfoMalloc() -> *mut c_void;
    pub fn InputDic(path: *const c_char, callback: unsafe extern "C" fn(i32, i32, i32, i32)) -> i32;
    pub fn TextToPcmFile(
        text: *const u8,
        outfile: *const c_char,
        callback: unsafe extern "C" fn(i32, i32, i32, i32),
    ) -> i32;
}
