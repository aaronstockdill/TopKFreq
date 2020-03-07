ASM=nasm
ASMFLAGS=-f macho64 -w-macro-defaults -w-macro-params -g

LD=ld
LDFLAGS=-macosx_version_min 10.13.0 -lSystem

topk: topk.o
	$(LD) $(LDFLAGS) -o $@ $<

%.o: %.asm
	$(ASM) $(ASMFLAGS) $<

.PHONY: clean
clean:
	rm *.o
