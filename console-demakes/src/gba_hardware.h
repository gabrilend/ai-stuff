/*
 * Game Boy Advance Hardware Definitions
 * Memory-mapped I/O registers and constants for GBA development
 */

#ifndef GBA_HARDWARE_H
#define GBA_HARDWARE_H

#include <stdint.h>

// ============================================================================
// MEMORY MAP
// ============================================================================

// System ROM
#define BIOS_ROM_START          0x00000000
#define BIOS_ROM_SIZE           0x00004000      // 16KB

// External Work RAM
#define EWRAM_START             0x02000000      
#define EWRAM_SIZE              0x00040000      // 256KB

// Internal Work RAM  
#define IWRAM_START             0x03000000
#define IWRAM_SIZE              0x00008000      // 32KB

// I/O Registers
#define IO_REGISTERS_START      0x04000000
#define IO_REGISTERS_SIZE       0x00000400      // 1KB

// Palette RAM
#define PALETTE_RAM_START       0x05000000
#define PALETTE_RAM_SIZE        0x00000400      // 1KB

// Video RAM
#define VRAM_START              0x06000000
#define VRAM_SIZE               0x00018000      // 96KB

// Object Attribute Memory (OAM)
#define OAM_START               0x07000000
#define OAM_SIZE                0x00000400      // 1KB

// Game ROM
#define ROM_START               0x08000000
#define ROM_SIZE                0x02000000      // 32MB max

// ============================================================================
// DISPLAY CONTROL REGISTERS
// ============================================================================

// Display Control Register (REG_DISPCNT)
#define REG_DISPCNT             (*(volatile uint16_t*)0x04000000)

// Display Control Flags
#define DISPCNT_MODE_0          0x0000          // Tile mode
#define DISPCNT_MODE_1          0x0001          // Tile mode with rotation
#define DISPCNT_MODE_2          0x0002          // Tile mode with rotation
#define DISPCNT_MODE_3          0x0003          // Bitmap mode 240x160, 16bpp
#define DISPCNT_MODE_4          0x0004          // Bitmap mode 240x160, 8bpp
#define DISPCNT_MODE_5          0x0005          // Bitmap mode 160x128, 16bpp

#define DISPCNT_GB_MODE         0x0008          // Game Boy mode
#define DISPCNT_PAGE_SELECT     0x0010          // Page select (Mode 4/5)
#define DISPCNT_OAM_HBL_FREE    0x0020          // Allow access to OAM in H-Blank
#define DISPCNT_OBJ_1D_MAP      0x0040          // OBJ 1D mapping
#define DISPCNT_FORCE_BLANK     0x0080          // Force screen blank
#define DISPCNT_BG0_ON          0x0100          // Background 0 enable
#define DISPCNT_BG1_ON          0x0200          // Background 1 enable  
#define DISPCNT_BG2_ON          0x0400          // Background 2 enable
#define DISPCNT_BG3_ON          0x0800          // Background 3 enable
#define DISPCNT_OBJ_ON          0x1000          // Sprites enable
#define DISPCNT_WIN0_ON         0x2000          // Window 0 enable
#define DISPCNT_WIN1_ON         0x4000          // Window 1 enable
#define DISPCNT_WINOBJ_ON       0x8000          // Object window enable

// Display Status Register
#define REG_DISPSTAT            (*(volatile uint16_t*)0x04000004)

// V-Counter Register (current scanline)
#define REG_VCOUNT              (*(volatile uint16_t*)0x04000006)

// ============================================================================
// BACKGROUND CONTROL REGISTERS
// ============================================================================

#define REG_BG0CNT              (*(volatile uint16_t*)0x04000008)
#define REG_BG1CNT              (*(volatile uint16_t*)0x0400000A)
#define REG_BG2CNT              (*(volatile uint16_t*)0x0400000C)
#define REG_BG3CNT              (*(volatile uint16_t*)0x0400000E)

// Background Control Flags
#define BGCNT_PRIORITY_0        0x0000
#define BGCNT_PRIORITY_1        0x0001
#define BGCNT_PRIORITY_2        0x0002
#define BGCNT_PRIORITY_3        0x0003
#define BGCNT_CHARBASE(n)       ((n) << 2)      // Character base block (0-3)
#define BGCNT_MOSAIC            0x0040           // Mosaic enable
#define BGCNT_16COLOR           0x0000           // 16 color mode (4bpp)
#define BGCNT_256COLOR          0x0080           // 256 color mode (8bpp)
#define BGCNT_SCREENBASE(n)     ((n) << 8)      // Screen base block (0-31)
#define BGCNT_WRAP              0x2000           // Wraparound enable (BG2/3)

// Background size settings
#define BGCNT_SIZE_0            0x0000           // 256x256
#define BGCNT_SIZE_1            0x4000           // 512x256
#define BGCNT_SIZE_2            0x8000           // 256x512
#define BGCNT_SIZE_3            0xC000           // 512x512

// ============================================================================
// BACKGROUND SCROLL REGISTERS
// ============================================================================

#define REG_BG0HOFS             (*(volatile uint16_t*)0x04000010)
#define REG_BG0VOFS             (*(volatile uint16_t*)0x04000012)
#define REG_BG1HOFS             (*(volatile uint16_t*)0x04000014)
#define REG_BG1VOFS             (*(volatile uint16_t*)0x04000016)
#define REG_BG2HOFS             (*(volatile uint16_t*)0x04000018)
#define REG_BG2VOFS             (*(volatile uint16_t*)0x0400001A)
#define REG_BG3HOFS             (*(volatile uint16_t*)0x0400001C)
#define REG_BG3VOFS             (*(volatile uint16_t*)0x0400001E)

// ============================================================================
// INPUT REGISTERS
// ============================================================================

#define REG_KEYINPUT            (*(volatile uint16_t*)0x04000130)
#define REG_KEYCNT              (*(volatile uint16_t*)0x04000132)

// Key Input Flags (note: 0 = pressed, 1 = not pressed)
#define KEY_A                   0x0001
#define KEY_B                   0x0002
#define KEY_SELECT              0x0004
#define KEY_START               0x0008
#define KEY_RIGHT               0x0010
#define KEY_LEFT                0x0020
#define KEY_UP                  0x0040
#define KEY_DOWN                0x0080
#define KEY_R                   0x0100
#define KEY_L                   0x0200

// Key convenience macros
#define KEY_ANY                 0x03FF
#define KEY_MASK                0x03FF

// ============================================================================
// TIMER REGISTERS
// ============================================================================

#define REG_TM0CNT_L            (*(volatile uint16_t*)0x04000100)
#define REG_TM0CNT_H            (*(volatile uint16_t*)0x04000102)
#define REG_TM1CNT_L            (*(volatile uint16_t*)0x04000104)
#define REG_TM1CNT_H            (*(volatile uint16_t*)0x04000106)
#define REG_TM2CNT_L            (*(volatile uint16_t*)0x04000108)
#define REG_TM2CNT_H            (*(volatile uint16_t*)0x0400010A)
#define REG_TM3CNT_L            (*(volatile uint16_t*)0x0400010C)
#define REG_TM3CNT_H            (*(volatile uint16_t*)0x0400010E)

// ============================================================================
// DMA REGISTERS
// ============================================================================

#define REG_DMA0SAD             (*(volatile uint32_t*)0x040000B0)
#define REG_DMA0DAD             (*(volatile uint32_t*)0x040000B4)
#define REG_DMA0CNT_L           (*(volatile uint16_t*)0x040000B8)
#define REG_DMA0CNT_H           (*(volatile uint16_t*)0x040000BA)

// ============================================================================
// INTERRUPT REGISTERS
// ============================================================================

#define REG_IE                  (*(volatile uint16_t*)0x04000200)  // Interrupt Enable
#define REG_IF                  (*(volatile uint16_t*)0x04000202)  // Interrupt Flag
#define REG_IME                 (*(volatile uint16_t*)0x04000208)  // Interrupt Master Enable

// Interrupt flags
#define INT_VBLANK              0x0001
#define INT_HBLANK              0x0002
#define INT_VCOUNT              0x0004
#define INT_TIMER0              0x0008
#define INT_TIMER1              0x0010
#define INT_TIMER2              0x0020
#define INT_TIMER3              0x0040
#define INT_SERIAL              0x0080
#define INT_DMA0                0x0100
#define INT_DMA1                0x0200
#define INT_DMA2                0x0400
#define INT_DMA3                0x0800
#define INT_KEYPAD              0x1000
#define INT_GAMEPAK             0x2000

// ============================================================================
// VIDEO MEMORY POINTERS
// ============================================================================

// Palette Memory
#define BG_PALETTE              ((volatile uint16_t*)0x05000000)
#define OBJ_PALETTE             ((volatile uint16_t*)0x05000200)

// Video RAM
#define VRAM                    ((volatile uint16_t*)0x06000000)

// Character blocks (for tile data)
#define CHARBLOCK(n)            ((volatile uint16_t*)(0x06000000 + ((n) * 0x4000)))

// Screen blocks (for tilemap data)
#define SCREENBLOCK(n)          ((volatile uint16_t*)(0x06000000 + ((n) * 0x800)))

// Bitmap mode frame buffers
#define MODE3_FRAME             ((volatile uint16_t*)0x06000000)
#define MODE4_FRAME0            ((volatile uint16_t*)0x06000000)
#define MODE4_FRAME1            ((volatile uint16_t*)0x0600A000)
#define MODE5_FRAME0            ((volatile uint16_t*)0x06000000)
#define MODE5_FRAME1            ((volatile uint16_t*)0x0600A000)

// Object Attribute Memory
#define OAM                     ((volatile uint16_t*)0x07000000)

// ============================================================================
// SCREEN DIMENSIONS
// ============================================================================

#define SCREEN_WIDTH            240
#define SCREEN_HEIGHT           160

// ============================================================================
// COLOR MACROS
// ============================================================================

#define RGB15(r,g,b)            ((r) | ((g) << 5) | ((b) << 10))

// Common colors (15-bit RGB)
#define COLOR_BLACK             RGB15(0,0,0)
#define COLOR_WHITE             RGB15(31,31,31)
#define COLOR_RED               RGB15(31,0,0)
#define COLOR_GREEN             RGB15(0,31,0)
#define COLOR_BLUE              RGB15(0,0,31)
#define COLOR_YELLOW            RGB15(31,31,0)
#define COLOR_MAGENTA           RGB15(31,0,31)
#define COLOR_CYAN              RGB15(0,31,31)

// ============================================================================
// UTILITY MACROS
// ============================================================================

// Wait for V-Blank
#define WAIT_VBLANK()           while((REG_VCOUNT) < 160)

// Set a bit
#define BIT_SET(reg, bit)       ((reg) |= (bit))

// Clear a bit  
#define BIT_CLEAR(reg, bit)     ((reg) &= ~(bit))

// Toggle a bit
#define BIT_TOGGLE(reg, bit)    ((reg) ^= (bit))

// Test a bit
#define BIT_TEST(reg, bit)      ((reg) & (bit))

#endif // GBA_HARDWARE_H