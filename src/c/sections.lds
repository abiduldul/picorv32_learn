ENTRY(start)
MEMORY {
	ROM (rwx) : ORIGIN = 0x00000000, LENGTH = 16M,
	RAM (rwx) : ORIGIN = 0x10000000, LENGTH = 256
}

SECTIONS {
	.text : {
		KEEP(*(.init))
		KEEP(*(.fini))
		*(.text)
		*(.text.*)
		*(.rodata)
		*(.rodata.*)
		. = ALIGN(8);
		_etext = .;
	} > ROM

	_la_data = LOADADDR(.data);

	.data : {
		_sdata = .;
		*(.data)
		*(.data.*)
	} > RAM AT> ROM

	.sdata : {
		*(.sdata*)
		//__global_pointer$ = . + 2K;
		_edata = .;
	} > RAM AT> ROM

	.bss : {
		_sbss = .;
		*(.bss)
		*(.bss.*)
		*(COMMON)
		. = ALIGN(8);
		_ebss = .;
	} > RAM

	.sbss : {
		_sbss_start = .;
		*(.sbss*)
		*(.sbss.*)
		. = ALIGN(8);
		_sbss_end = .;
	}
	
	. = ALIGN(8);
	_end = .;

	_stack_size = 128;
	_stack_top = ORIGIN(RAM) + LENGTH(RAM);
	_stack_bottom = _stack_top - _stack_size;

	ASSERT(_end <= _stack_bottom, "Error: Heap collides with stack")

}
