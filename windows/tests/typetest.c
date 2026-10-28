/*
 * Types every case from cases.h through the installed layout with ToUnicodeEx and checks the result.
 * Usage: typetest <KLID>, e.g. typetest a0000443. Exits non-zero on any mismatch.
 */

#include <windows.h>
#include <stdio.h>

#include "case.h"
#include "cases.h"

static void set_state(BYTE *state, UINT modifiers)
{
    ZeroMemory(state, 256);
    if (modifiers & 1) state[VK_SHIFT] = state[VK_LSHIFT] = 0x80;
    if (modifiers & 2) state[VK_CONTROL] = state[VK_LCONTROL] = 0x80;
    if (modifiers & 4) state[VK_MENU] = state[VK_RMENU] = 0x80;
    if (modifiers & CAPS) state[VK_CAPITAL] = 0x01;
}

int wmain(int argc, wchar_t **argv)
{
    HKL hkl;
    BYTE state[256];
    WCHAR typed[8];
    size_t i, failures = 0;
    const size_t count = sizeof(kCases) / sizeof(kCases[0]);

    if (argc != 2) {
        fwprintf(stderr, L"usage: typetest <KLID>\n");
        return 2;
    }
    hkl = LoadKeyboardLayoutW(argv[1], KLF_NOTELLSHELL);
    /* A layout that fails to load falls back to another one silently, so check it is Uzbek. */
    if (hkl == NULL || LOWORD((ULONG_PTR)hkl) != 0x0443) {
        fwprintf(stderr, L"layout %ls did not load (got %p)\n", argv[1], (void *)hkl);
        return 1;
    }
    for (i = 0; i < count; i++) {
        const struct Case *c = &kCases[i];
        UINT scan = MapVirtualKeyExW(c->vk, MAPVK_VK_TO_VSC, hkl);
        int n;
        set_state(state, c->modifiers);
        /* Flag 4 leaves the kernel's keyboard state alone between calls. */
        n = ToUnicodeEx(c->vk, scan, state, typed, 8, 4, hkl);
        if (n != 1 || typed[0] != c->expected[0]) {
            fwprintf(stderr, L"vk 0x%02x mods 0x%03x: expected U+%04X, got %d chars U+%04X\n",
                     c->vk, c->modifiers, c->expected[0], n, n > 0 ? typed[0] : 0);
            failures++;
        }
    }
    wprintf(L"%zu cases, %zu failures\n", count, failures);
    return failures == 0 ? 0 : 1;
}
