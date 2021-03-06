# Change Log

All notable changes to this project will be documented in this file.

## [0.2.6] - 2015-11-08
- Fix *nix versions of scripts

## [0.2.5] - 2015-11-04
- Refactor the disk_read functions

## [0.2.4] - 2015-11-04
- Add support for far calls into kernel

## [0.2.3] - 2015-11-01
- Add routine to hex-print a double-word
- Add example function call

## [0.2.2] - 2015-10-29
- Consolidate the boot sector and kernel into a single disk image

## [0.2.1] - 2015-10-28
- Add basic disk write facility and simple test
- Tweaked the README

## [0.2.0] - 2015-10-27
- Replace OS interrupt call-handling with JMP table

## [0.1.6] - 2015-10-26
- Add dump of part of BIOS data area, for testing

## [0.1.5] - 2015-10-25
- Reorganise memory layout
- Add hex dump of stack

## [0.1.4] - 2015-10-23
- Add links in the README to other resources
- Add basic OS call handling, using a software interrupt

## [0.1.3] - 2015-10-22
- Add pixel-plot functions
- Use video mode instead of text mode (for testing only)
- Add more colour-handling

## [0.1.2] - 2015-10-21
- Add cursor-position functions
- Modify print routines to support colours
- Add basic input and screen-scrolling

## [0.1.1] - 2015-10-16
- Add simple get_char to read and echo input

## [0.1.0 - 2015-10-12
- Add and load kernel.asm
- Update build and run scripts
- Trim unused code from boot.asm

## [0.0.8] - 2015-10-06
- Add print_hex_byte routine, modify print_hex to use it
- Add hex_dump routine

## [0.0.7] - 2015-10-05
- Add disk_read routine
- Modify Qemu call to specify image as fda (floppy disk) rather than hda, as
  the disk_read fails in the latter case (this needs investigation)

## [0.0.6] - 2015-10-04
- Use LODSB for string-printing, and use appropriate registers

## [0.0.5] - 2015-10-04
- Add print_hex routine, and use local labels

## [0.0.4] - 2015-10-02
- Add simple print_string function

## [0.0.3] - 2015-10-01
- Change name to RetrOS

## [0.0.2] - 2015-09-24

### Changed
- Add clear screen and print of version number

## [0.0.1] - 2015-09-24

### Added
- Initial commit

Copyright 2015, chrisatthestudy <chris@the-study.net>

Copying and distribution of this file, with or without modification, are
permitted provided the copyright notice and this notice are preserved.
