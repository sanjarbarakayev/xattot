/* One typing case from cases.h: a key, the modifiers held, and the character it must type. */

#define CAPS 0x100

struct Case {
    UINT vk;
    UINT modifiers; /* 1 Shift, 2 Ctrl, 4 Alt, CAPS Caps Lock on */
    const wchar_t *expected;
};
