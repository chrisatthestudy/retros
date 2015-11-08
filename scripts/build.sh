if [ ! -d ../build ]; then
    mkdir ../build
fi
nasm ../src/boot.asm -f bin -o ../build/boot.img
nasm ../src/kernel.asm -f bin -o ../build/kernel.img
cat ../build/boot.img ../build/kernel.img > ../build/retros.img

