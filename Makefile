GHDL     = ghdl
FLAGS    = --std=08 -fsynopsys
SIMFLAGS = --stop-time=200ms

SRC = src/spi_master.vhd \
      src/ssd1331_init.vhd \
      src/scan_controller.vhd \
      src/cat_rom.vhd \
      src/oledrgb_top.vhd

TBS = spi_master_tb \
      ssd1331_init_tb \
      scan_controller_tb

.PHONY: all analyse simulate clean wave $(TBS)

all: simulate

analyse:
	$(GHDL) -a $(FLAGS) $(SRC)
	$(GHDL) -a $(FLAGS) tb/spi_master_tb.vhd
	$(GHDL) -a $(FLAGS) tb/ssd1331_init_tb.vhd
	$(GHDL) -a $(FLAGS) tb/scan_controller_tb.vhd

simulate: analyse $(TBS)

$(TBS): %:
	$(GHDL) -e $(FLAGS) $*
	$(GHDL) -r $(FLAGS) $* $(SIMFLAGS) --fst=$*.fst 2>&1 | tee $*.log

wave:
	@echo "Usage: make wave TB=<tb_name>"
	gtkwave $(TB).fst

clean:
	rm -f *.fst *.cf *.log
