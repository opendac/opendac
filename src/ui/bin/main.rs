#![no_main]
#![no_std]
use core::fmt::Write;
use libtock::console::Console;
use libtock::runtime::{set_main, stack_size};

set_main! {main}
stack_size! {0x100}

fn main() {
    writeln!(Console::writer(), "Hello world!").unwrap();
}
