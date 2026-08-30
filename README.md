# MSXasgard_tn20k
MSX2+ in a cartridge

![MSX_Asgard](/pics/msx_asgard.jpg)

MSX Asgard is a cartridge to turn one MSX into an MSX2+. Host MSX provides:
* Keyboard
* Joysticks

FPGA in board contains: 
* Z80
* V9958 with hdmi output
* MSX2+ BIOS
* SD Card support + Nextor 2.14
* 4MB mapper
* 2MB megaram SCC
* RTC
* PSG
* OPLL
* Kanji Level 1 & 2


## Boards

Supported boards are [MSXhdmi_tn20k](https://github.com/jabadiagm/MSXhdmi_tn20k) and [Wondertang 1.01c](https://github.com/lfantoniosi/WonderTANG).
Firmwares for the Wondertang 1.02d and 2.00b are also provided.


## Slot map

![Slot map](/pics/mapa_slots6.png)

Mapper and megaram can be relocated to slots 1 or 2 using config menu.

## Megaram + Sofarun
Megaram is detected automatically by sofarun using default settings. When using other software you may need to indicate location, Slot 3-3 by default.


## Configuration
Config menu is showed pressing 'g' during MSX logo. Menu is created by [nataliapc](https://github.com/nataliapc)

![Config](/pics/config_asgard.png)

* Enable Megaram: On by default. Disable when having compatibility issues
* Enable SD: On by default. Disable to boot directly to basic
* Mapper Slot: 3 by default. Change to 1 or 2 to get mapper in a not expanded slot
* Megaram Slot: 3 by default. Change to 1 or 2 to get megaram in a not expanded slot
* Enable Scanlines: On by default. Disable to get a clean hdmi picture
* Turbo: Off by default. Enable to use an internal high-speed clock
* Save & Exit: store new config and continue, changes in mapper settings will be effective after pressing reset
* Save & Reset: store new config and make software reset, changes will be immediate

## Known issues
* Keyboard layout may be different
* High sensitivity to dirty contacts, keep them clean


## Flashing
Programming is done in two steps:
* Flash firmware MSX_asgard.fs on MSXhdmi_tn20k or MSX_asgard_wt101c.fs on Wondertang 1.01c

![Flash1a](/pics/flashing1a.png)
![Flash1b](/pics/flashing1b.png)
* Flash bios pack. Set Operation = "exFlash C Bin Erase, Program thru GAO-Bridge" and Start Address = 0x200000  

![Flash2a](/pics/flashing2a.png)
![Flash2b](/pics/flashing2b.png)

> [!WARNING]
> Work in progress, use at your own risk
>