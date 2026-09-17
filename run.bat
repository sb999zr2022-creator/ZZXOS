
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin

cmd /c "copy /b boot.bin + kernel.bin + desktop.bin os.img"


qemu-system-i386 -fda os.img