@call vars.bat
@nasm ../src/boot.asm -f bin -o ../build/boot.img
@nasm ../src/kernel.asm -f bin -o ../build/kernel.img
@cd ../build
@copy /y /b boot.img + kernel.img retros.img
@rm boot.img
@rm kernel.img
@cd ../scripts
