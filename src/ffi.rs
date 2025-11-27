use std::ffi::c_char;
use std::ffi::c_void;

#[link(name = "KTTS")]
#[link(name = "artsc")]
#[link(name = "m")]
unsafe extern "C" {
    pub fn SynthInfoMalloc() -> *mut c_void;
    pub fn InputDic(path: *const c_char, callback: unsafe extern "C" fn(i32, i32, i32, i32)) -> i32;
    pub fn TextToPcmFile(
        text: *const u8,
        outfile: *const c_char,
        callback: unsafe extern "C" fn(i32, i32, i32, i32),
    ) -> i32;
}

// Dummy getauxval for ancient glibc (2.11)
#[unsafe(no_mangle)]
pub extern "C" fn getauxval(_type: u64) -> u64 {
    0
}
