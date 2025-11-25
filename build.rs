fn main() {
    println!("cargo:rustc-link-lib=dylib=KTTS");
    println!("cargo:rustc-link-lib=dylib=artsc");
}
