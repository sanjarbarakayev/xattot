#include "Utf16Text.h"

#include <algorithm>

namespace xattot {

namespace utf16 {

std::optional<Suffix> suffix(size_t count, const Reader& read) {
    if (count == 0) return Suffix{};
    size_t window = std::min(count * 2 + 2, maxWindow);
    while (true) {
        const auto units = read(window);
        if (!units || units->size() > window) return std::nullopt;
        const Text text = fromUtf16(*units);
        // The window may start inside a surrogate pair, so its first code point only counts at the very start.
        const bool atStart = units->size() < window;
        if (text.size() > count || atStart) {
            Suffix found;
            found.text = text.substr(text.size() - std::min(count, text.size()));
            found.units = utf16Length(found.text);
            return found;
        }
        if (window == maxWindow) return std::nullopt;
        window = std::min(window * 2, maxWindow);
    }
}

}  // namespace utf16

bool CaretTracker::sync(std::optional<Selection> reported) {
    if (location_ && reported && beforeEdits_ && *reported == Selection{*beforeEdits_, 0}) {
        beforeEdits_ = location_;
        return false;
    }
    const bool moved = reported && location_ && !(*reported == Selection{*location_, 0});
    location_ = reported && reported->length == 0 ? std::optional<long>(reported->start) : std::nullopt;
    beforeEdits_ = location_;
    return moved;
}

void CaretTracker::insert(const Text& text) {
    if (location_) *location_ = *location_ - static_cast<long>(markedUnits_) + static_cast<long>(utf16Length(text));
    markedUnits_ = 0;
}

void CaretTracker::setMarked(const Text& text) {
    insert(text);
    markedUnits_ = utf16Length(text);
}

void CaretTracker::replace(size_t units, const Text& text) {
    if (location_) *location_ = *location_ - static_cast<long>(units) + static_cast<long>(utf16Length(text));
}

void CaretTracker::passed(const std::optional<Text>& typed) {
    if (!typed || markedUnits_ != 0) {
        location_.reset();
        return;
    }
    if (location_) *location_ += static_cast<long>(utf16Length(*typed));
}

}  // namespace xattot
