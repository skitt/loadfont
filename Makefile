APACK = c:/etc/apack.exe
NASM = c:/nasm/nasm.exe

all: loadfont.com loadfntv.com

loadfont.com: ldfont.com
	$(APACK) ldfont.com loadfont.com

loadfntv.com: ldfntv.com
	$(APACK) ldfntv.com loadfntv.com

ldfont.com: loadfont.asm
	$(NASM) loadfont.asm -f bin -o ldfont.com

ldfntv.com: loadfont.asm
	$(NASM) -dVERBOSE loadfont.asm -f bin -o ldfntv.com
