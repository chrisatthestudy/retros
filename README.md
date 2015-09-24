# Studios - a minimal OS for studying OS development

## Overview

This is a toy. This is only a toy. 

I am writing this simply for my own interest, to learn more about x86
assembly-language programming and about operating-systems.

I have no grand ideas about what it will develop into, although I would like
to stay in assembler for as long as possible, and if I move on from there it
will be via a programming-language that I will design and create for myself.

Because it is basically a personal project I probably won't accept pull
requests -- if you are intrigued by the project then I suggest you fork it
and work on your own version.

## Requirements

The code itself has no dependencies, but there are specific tools that you
will need to compile and run the system.

* qemu, for running Studios as a Virtual Machine
* nasm, for compiling the assembly-language files

Both of these should be painless to acquire and install.

## Compiling and Running

In the scripts folder are build.bat (for compiling on Windows) and build.sh
(for compiling on *nix systems), along with run.bat and run.sh for actually
running the OS (as a Virtual Machine).

Note that the OS is compiled into the build folder, as studios.img.

The build.bat and run.bat files call vars.bat to set up the paths for nasm and
qemu. This is only required if these programs are not already in your Windows
path (I have them installed portably, so they aren't in my path). You can
eliminate this call if those programs are already in your path.

For *nix, the build.sh assumes that nasm and qemu are in the system path.

