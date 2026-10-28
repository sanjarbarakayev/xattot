/*
 * Özbekça Tugmali (Xattot) keyboard layout. The scan code, modifier and key name tables are the
 * US layout's (Microsoft's kbdus sample); the characters come from chars.h, generated from uzkbd/.
 */

#define KBD_TYPE 4

#include <windows.h>
#include <kbd.h>

#pragma data_seg(".data")
#define ALLOC_SECTION_LDATA

static ALLOC_SECTION_LDATA USHORT ausVK[] = {
    T00, T01, T02, T03, T04, T05, T06, T07,
    T08, T09, T0A, T0B, T0C, T0D, T0E, T0F,
    T10, T11, T12, T13, T14, T15, T16, T17,
    T18, T19, T1A, T1B, T1C, T1D, T1E, T1F,
    T20, T21, T22, T23, T24, T25, T26, T27,
    T28, T29, T2A, T2B, T2C, T2D, T2E, T2F,
    T30, T31, T32, T33, T34, T35,
    T36 | KBDEXT,
    T37 | KBDMULTIVK,
    T38, T39, T3A, T3B, T3C, T3D, T3E,
    T3F, T40, T41, T42, T43, T44,
    T45 | KBDEXT | KBDMULTIVK,
    T46 | KBDMULTIVK,
    T47 | KBDNUMPAD | KBDSPECIAL,
    T48 | KBDNUMPAD | KBDSPECIAL,
    T49 | KBDNUMPAD | KBDSPECIAL,
    T4A,
    T4B | KBDNUMPAD | KBDSPECIAL,
    T4C | KBDNUMPAD | KBDSPECIAL,
    T4D | KBDNUMPAD | KBDSPECIAL,
    T4E,
    T4F | KBDNUMPAD | KBDSPECIAL,
    T50 | KBDNUMPAD | KBDSPECIAL,
    T51 | KBDNUMPAD | KBDSPECIAL,
    T52 | KBDNUMPAD | KBDSPECIAL,
    T53 | KBDNUMPAD | KBDSPECIAL,
    T54, T55, T56, T57, T58, T59, T5A, T5B,
    T5C, T5D, T5E, T5F, T60, T61, T62, T63,
    T64, T65, T66, T67, T68, T69, T6A, T6B,
    T6C, T6D, T6E, T6F, T70, T71, T72, T73,
    T74, T75, T76, T77, T78, T79, T7A, T7B,
    T7C, T7D, T7E
};

static ALLOC_SECTION_LDATA VSC_VK aE0VscToVk[] = {
    { 0x10, X10 | KBDEXT }, { 0x19, X19 | KBDEXT }, { 0x1D, X1D | KBDEXT },
    { 0x20, X20 | KBDEXT }, { 0x21, X21 | KBDEXT }, { 0x22, X22 | KBDEXT },
    { 0x24, X24 | KBDEXT }, { 0x2E, X2E | KBDEXT }, { 0x30, X30 | KBDEXT },
    { 0x32, X32 | KBDEXT }, { 0x35, X35 | KBDEXT }, { 0x37, X37 | KBDEXT },
    { 0x38, X38 | KBDEXT }, { 0x47, X47 | KBDEXT }, { 0x48, X48 | KBDEXT },
    { 0x49, X49 | KBDEXT }, { 0x4B, X4B | KBDEXT }, { 0x4D, X4D | KBDEXT },
    { 0x4F, X4F | KBDEXT }, { 0x50, X50 | KBDEXT }, { 0x51, X51 | KBDEXT },
    { 0x52, X52 | KBDEXT }, { 0x53, X53 | KBDEXT }, { 0x5B, X5B | KBDEXT },
    { 0x5C, X5C | KBDEXT }, { 0x5D, X5D | KBDEXT }, { 0x5F, X5F | KBDEXT },
    { 0x65, X65 | KBDEXT }, { 0x66, X66 | KBDEXT }, { 0x67, X67 | KBDEXT },
    { 0x68, X68 | KBDEXT }, { 0x69, X69 | KBDEXT }, { 0x6A, X6A | KBDEXT },
    { 0x6B, X6B | KBDEXT }, { 0x6C, X6C | KBDEXT }, { 0x6D, X6D | KBDEXT },
    { 0x1C, X1C | KBDEXT }, { 0x46, X46 | KBDEXT },
    { 0, 0 }
};

static ALLOC_SECTION_LDATA VSC_VK aE1VscToVk[] = {
    { 0x1D, Y1D },
    { 0, 0 }
};

static ALLOC_SECTION_LDATA VK_TO_BIT aVkToBits[] = {
    { VK_SHIFT, KBDSHIFT },
    { VK_CONTROL, KBDCTRL },
    { VK_MENU, KBDALT },
    { 0, 0 }
};

/* Modifier bits -> column in the VK_TO_WCHARS tables: base, shift, AltGr, Ctrl, Shift+Ctrl, Shift+AltGr. */
static ALLOC_SECTION_LDATA MODIFIERS CharModifiers = {
    &aVkToBits[0],
    7,
    {
        0,            /* none */
        1,            /* Shift */
        3,            /* Ctrl */
        4,            /* Shift + Ctrl */
        SHFT_INVALID, /* Alt */
        SHFT_INVALID, /* Shift + Alt */
        2,            /* Ctrl + Alt (AltGr) */
        5             /* Shift + Ctrl + Alt */
    }
};

#include "chars.h"

static ALLOC_SECTION_LDATA VSC_LPWSTR aKeyNames[] = {
    0x01, L"Esc",         0x0e, L"Backspace",   0x0f, L"Tab",         0x1c, L"Enter",
    0x1d, L"Ctrl",        0x2a, L"Shift",       0x36, L"Right Shift", 0x37, L"Num *",
    0x38, L"Alt",         0x39, L"Space",       0x3a, L"Caps Lock",   0x3b, L"F1",
    0x3c, L"F2",          0x3d, L"F3",          0x3e, L"F4",          0x3f, L"F5",
    0x40, L"F6",          0x41, L"F7",          0x42, L"F8",          0x43, L"F9",
    0x44, L"F10",         0x45, L"Pause",       0x46, L"Scroll Lock", 0x47, L"Num 7",
    0x48, L"Num 8",       0x49, L"Num 9",       0x4a, L"Num -",       0x4b, L"Num 4",
    0x4c, L"Num 5",       0x4d, L"Num 6",       0x4e, L"Num +",       0x4f, L"Num 1",
    0x50, L"Num 2",       0x51, L"Num 3",       0x52, L"Num 0",       0x53, L"Num Del",
    0x54, L"Sys Req",     0x57, L"F11",         0x58, L"F12",         0x7c, L"F13",
    0x7d, L"F14",         0x7e, L"F15",         0x7f, L"F16",         0x80, L"F17",
    0x81, L"F18",         0x82, L"F19",         0x83, L"F20",         0x84, L"F21",
    0x85, L"F22",         0x86, L"F23",         0x87, L"F24",
    0, NULL
};

static ALLOC_SECTION_LDATA VSC_LPWSTR aKeyNamesExt[] = {
    0x1c, L"Num Enter",   0x1d, L"Right Ctrl",  0x35, L"Num /",       0x37, L"Prnt Scrn",
    0x38, L"Right Alt",   0x45, L"Num Lock",    0x46, L"Break",       0x47, L"Home",
    0x48, L"Up",          0x49, L"Page Up",     0x4b, L"Left",        0x4d, L"Right",
    0x4f, L"End",         0x50, L"Down",        0x51, L"Page Down",   0x52, L"Insert",
    0x53, L"Delete",      0x54, L"<00>",        0x56, L"Help",        0x5b, L"Left Windows",
    0x5c, L"Right Windows", 0x5d, L"Application",
    0, NULL
};

static ALLOC_SECTION_LDATA KBDTABLES KbdTables = {
    &CharModifiers,
    aVkToWcharTable,
    NULL,               /* no dead keys */
    aKeyNames,
    aKeyNamesExt,
    NULL,
    ausVK,
    sizeof(ausVK) / sizeof(ausVK[0]),
    aE0VscToVk,
    aE1VscToVk,
    MAKELONG(KLLF_ALTGR, KBD_VERSION),
    0,
    0,
    NULL                /* no ligatures */
};

PKBDTABLES KbdLayerDescriptor(VOID)
{
    return &KbdTables;
}
