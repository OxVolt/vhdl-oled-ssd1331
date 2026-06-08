## oledrgb_top.xdc
## Basys 3 — Pmod OLEDrgb sur connecteur JB
##
## Pmod OLEDrgb pinout (Digilent) :
##   JB pin 1  → CS#
##   JB pin 2  → SDIN (MOSI)
##   JB pin 3  → NC
##   JB pin 4  → SCLK
##   JB pin 7  → D/C#
##   JB pin 8  → RES#
##   JB pin 9  → VCCEN
##   JB pin 10 → PMODEN

## ── Horloge 100 MHz ───────────────────────────────────────────────────
set_property PACKAGE_PIN W5  [get_ports clk_i]
set_property IOSTANDARD LVCMOS33 [get_ports clk_i]
create_clock -add -name sys_clk -period 10.000 -waveform {0 5} [get_ports clk_i]

## ── Reset : bouton BTNC (centre) ──────────────────────────────────────
set_property PACKAGE_PIN U18 [get_ports rst_i]
set_property IOSTANDARD LVCMOS33 [get_ports rst_i]

## ── Pmod JB — rangée haute (pins 1-4) ────────────────────────────────
set_property PACKAGE_PIN A14 [get_ports cs_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports cs_n_o]

set_property PACKAGE_PIN A16 [get_ports mosi_o]
set_property IOSTANDARD LVCMOS33 [get_ports mosi_o]

## JB pin 3 → NC, non connecté

set_property PACKAGE_PIN B16 [get_ports sclk_o]
set_property IOSTANDARD LVCMOS33 [get_ports sclk_o]

## ── Pmod JB — rangée basse (pins 7-10) ───────────────────────────────
set_property PACKAGE_PIN A15 [get_ports dc_o]
set_property IOSTANDARD LVCMOS33 [get_ports dc_o]

set_property PACKAGE_PIN A17 [get_ports res_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports res_n_o]

set_property PACKAGE_PIN C15 [get_ports vccen_o]
set_property IOSTANDARD LVCMOS33 [get_ports vccen_o]

set_property PACKAGE_PIN C16 [get_ports pmoden_o]
set_property IOSTANDARD LVCMOS33 [get_ports pmoden_o]
