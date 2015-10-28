# RetrOS
_Because 640k should be enough for anybody_

## Overview

This is a toy. This is only a toy. 

RetrOS is a minimalist 16-bit OS, written basically for my own amusement and
education. Although it uses x86 assembler, it is restricted to 16 bits, and
never switches to 32-bit.

Because it stays in 16-bit, it can use the standard BIOS interrupt routines,
and is restricted to 1Mb of memory (effectively only 640k because of the BIOS
itself).

Because it is basically a personal project I probably won't accept pull
requests -- if you are intrigued by the project then I suggest you fork it
and work on your own version.

## Requirements

The code itself has no dependencies, but there are specific tools that you
will need to compile and run the system.

* [qemu](http://wiki.qemu.org/Main_Page), for running RetrOS as a Virtual Machine
* [nasm](http://www.nasm.us), for compiling the assembly-language files

Both of these should be painless to acquire and install.

## Compiling and Running

In the scripts folder are build.bat (for compiling on Windows) and build.sh
(for compiling on *nix systems), along with run.bat and run.sh for actually
running the OS (as a Virtual Machine).

Note that the OS is compiled into the build folder, as retros.img.

The build.bat and run.bat files call vars.bat to set up the paths for nasm and
qemu. This is only required if these programs are not already in your Windows
path (I have them installed portably, so they aren't in my path). You can
eliminate this call if those programs are already in your path.

For *nix, the build.sh assumes that nasm and qemu are in the system path.

## Resources

Resources for writing a 16-bit OS are rather sparse, because most people
prefer to move quickly on to protected-mode. However, I found a few useful
web-sites, which I'm listing here.

* [Ralf Brown's Interrupt List](http://www.ctyme.com/rbrown.htm)
-- A dauntingly extensive list of the known interrupts. It's an invaluable
resource, but it helps to know in advance which interrupts you want
information on -- just scanning through the pages of available commands
is likely to be confusing and offputting.

* [x86 OS Development](http://inglorion.net/documents/tutorials/x86ostut/)
-- A nice, but regrettably incomplete tutorial.

* [MikeOS - simple x86 assembly language operating system](http://mikeos.sourceforge.net)
-- It seems that at least one other person (or possibly team) has done what I am
trying to do! This is an excellent starting-point, and full of information
about How To Do It, and is a lot more advanced than RetrOS.
