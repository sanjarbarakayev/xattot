/*
 * Reads a layout DLL's tables directly and checks every case from cases.h against them.
 * typetest goes through the session's loaded layout, which a 32-bit process shares with the
 * native one, so only this catches a broken wow64 build. Build it with /DBUILD_WOW6432 for that.
 * Usage: tablecheck <path to kbduzxt.dll>
 */

#define KBD_TYPE 4

#include <windows.h>
#include <kbd.h>
#include <stdio.h>

#include "case.h"
#include "cases.h"

typedef PKBDTABLES (*Descriptor)(VOID);

static BOOL lookup(PKBDTABLES tables, UINT vk, UINT modifiers, WCHAR *out)
{
    PMODIFIERS mods = tables->pCharModifiers;
    UINT bits = modifiers & 7;
    PVK_TO_WCHAR_TABLE table;

    for (table = tables->pVkToWcharTable; table->pVkToWchars != NULL; table++) {
        BYTE KBD_LONG_POINTER *row = (BYTE KBD_LONG_POINTER *)table->pVkToWchars;
        for (; ((PVK_TO_WCHARS1)row)->VirtualKey != 0; row += table->cbSize) {
            PVK_TO_WCHARS1 entry = (PVK_TO_WCHARS1)row;
            UINT state = bits, column;
            if (entry->VirtualKey != vk) continue;
            /* Caps Lock on a CAPLOK key acts as Shift. */
            if ((modifiers & CAPS) && (entry->Attributes & CAPLOK)) state ^= 1;
            column = mods->ModNumber[state];
            if (column == SHFT_INVALID || column >= table->nModifications) return FALSE;
            *out = entry->wch[column];
            return *out != WCH_NONE;
        }
    }
    return FALSE;
}

int wmain(int argc, wchar_t **argv)
{
    HMODULE dll;
    Descriptor descriptor;
    PKBDTABLES tables;
    size_t i, failures = 0;
    const size_t count = sizeof(kCases) / sizeof(kCases[0]);

    if (argc != 2) {
        fwprintf(stderr, L"usage: tablecheck <dll>\n");
        return 2;
    }
    dll = LoadLibraryExW(argv[1], NULL, DONT_RESOLVE_DLL_REFERENCES);
    descriptor = dll ? (Descriptor)GetProcAddress(dll, "KbdLayerDescriptor") : NULL;
    if (descriptor == NULL) {
        fwprintf(stderr, L"cannot load %ls (error %lu)\n", argv[1], GetLastError());
        return 1;
    }
    tables = descriptor();
    for (i = 0; i < count; i++) {
        const struct Case *c = &kCases[i];
        WCHAR typed = 0;
        if (!lookup(tables, c->vk, c->modifiers, &typed) || typed != c->expected[0]) {
            fwprintf(stderr, L"vk 0x%02x mods 0x%03x: expected U+%04X, table has U+%04X\n",
                     c->vk, c->modifiers, c->expected[0], typed);
            failures++;
        }
    }
    wprintf(L"%ls: %zu cases, %zu failures\n", argv[1], count, failures);
    return failures == 0 ? 0 : 1;
}
