# Xattot

[English](README.md)

Xattot yangi özbek lotin alifbosida (OʻRQ-1184) yoziş uçun: `ch` bosasiz, `ç` çiqadi.
Mac va Windows'da işlaydi, bepul va kodi oçiq.

Ikki variant bor:

- **Özbekça (Xattot)**, input method. Odatdagidek `ch`, `sh`, `o'`, `g'` deb yozasiz, u butun
  sözni körib harfni almaştiradi. `change`, `push`, `shop` kabi inglizça sözlarni buzmaydi.
- **Özbekça Tugmali (Xattot)**, layout. Har bir yangi harf öz tugmasida: `[` → `ö`, `]` → `ğ`,
  `;` → `ş`, `'` → `ç`. Bu dastur emas, faqat harflar jadvali.

## Qanday yoziladi

- `ch` → `ç`, `sh` → `ş`, `o'` → `ö`, `g'` → `ğ` (`'` örniga `` ` `` ham böladi)
- Katta harf: `Ch`, `CH` → `Ç`, `O'` → `Ö` va hokazo
- Söz içidagi `'` tutuq böladi: `san'at` → `sanʼat`. Söz boşi va oxiridagi qöştirnoq özgarmaydi
- Mac'da `Option+C/S/G/O` harfni birdan yozadi, `Option+H` esa birikmaydigan `h` beradi:
  `p u s Option+H` → `push`
- Parol maydonlarida hech narsa almaşmaydi

## Örnatiş

**Mac (macOS 13 va yangisi).** [Releases](https://github.com/sanjarbarakayev/xattot/releases/latest)
sahifasidan `Xattot.dmg` ni yuklab, ilovani Applications'ga sudrang. Ilova Apple'da röyxatdan
ötmagan, şuning uçun birinçi marta System Settings > Privacy & Security > Open Anyway orqali
oçiladi. Keyin menyu satridagi Ö belgisidan yoqasiz yoki ⌃⌥O bosasiz.

**Windows 10 va 11 (64-bit).** Releases'dan `Xattot-Setup.exe` ni yuklab işga tuşiring.
Installer imzolanmagan, SmartScreen ogohlantirsa: More info > Run anyway. Özbekça (Xattot) Uzbek (Latin)
tili röyxatida birinçi turadi, şuning uçun odatiy klaviatura böladi. `Win+Space` bilan
almaştirasiz.

Batafsil yöriqnoma DMG içida, [`assets/Ornatish.txt`](assets/Ornatish.txt) faylida.

## Xavfsizlik

Input method siz yozayotgan sözni köradi, şuning uçun uning nima qilişini özingiz tekşira
olasiz:

- Ilova ham, input method ham internetga ulanmaydi. Ularda tarmoq kodi yöq, buni har bir
  build'da skript tekşiradi. Yuklab olgan nusxangizni ham tekşirsa böladi:
  `scripts/check_no_network.sh "/Applications/Xattot.app"`
- Input method faqat kursordan oldingi sözni öqiydi va faqat özi yozgan harfni almaştiradi
- Release'ni GitHub Actions şu kodning özidan yiğadi. Yuklab olingan faylni
  `gh attestation verify Xattot.dmg --repo sanjarbarakayev/xattot` bilan tekşirasiz

Tafsilotlar inglizça README'ning
[Privacy](README.md#privacy-and-how-to-check-it-yourself) bölimida.

## Hissa qöşiş

Xato topsangiz yoki ğoyangiz bölsa, [issue](https://github.com/sanjarbarakayev/xattot/issues)
oçing, özbekça yozsangiz ham böladi. Kod bilan yordam bermoqçi bölsangiz,
[CONTRIBUTING.md](CONTRIBUTING.md) ni öqing. Xavfsizlik muammosi haqida
[SECURITY.md](SECURITY.md) dagi yöl bilan yozing.

## Litsenziya

MIT
