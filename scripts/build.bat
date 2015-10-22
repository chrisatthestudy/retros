@call vars.bat
@nasm ../src/boot.asm -f bin -o ../build/retros.img
@nasm ../src/kernel.asm -f bin -o ../build/kernel.img
