#include "Json.h"

#include <fstream>
#include <sstream>

#include "../engine/Text.h"

namespace xattot::test {

namespace {

class Parser {
public:
    explicit Parser(const std::string& s) : s_(s) {}

    std::optional<std::vector<JsonObject>> objects() {
        std::vector<JsonObject> out;
        if (!take('[')) return std::nullopt;
        if (take(']')) return finished(out);
        do {
            auto object = this->object();
            if (!object) return std::nullopt;
            out.push_back(std::move(*object));
        } while (take(','));
        if (!take(']')) return std::nullopt;
        return finished(out);
    }

private:
    const std::string& s_;
    size_t i_ = 0;

    std::optional<std::vector<JsonObject>> finished(std::vector<JsonObject>& out) {
        skip();
        if (i_ != s_.size()) return std::nullopt;
        return std::move(out);
    }

    void skip() {
        while (i_ < s_.size() && (s_[i_] == ' ' || s_[i_] == '\n' || s_[i_] == '\r' || s_[i_] == '\t')) ++i_;
    }

    bool take(char c) {
        skip();
        if (i_ < s_.size() && s_[i_] == c) {
            ++i_;
            return true;
        }
        return false;
    }

    std::optional<JsonObject> object() {
        JsonObject out;
        if (!take('{')) return std::nullopt;
        if (take('}')) return out;
        do {
            auto key = string();
            if (!key || !take(':')) return std::nullopt;
            auto value = string();
            if (!value) return std::nullopt;
            out[*key] = *value;
        } while (take(','));
        if (!take('}')) return std::nullopt;
        return out;
    }

    std::optional<unsigned> hex4() {
        if (i_ + 4 > s_.size()) return std::nullopt;
        unsigned value = 0;
        for (int k = 0; k < 4; ++k) {
            const char c = s_[i_++];
            value <<= 4;
            if (c >= '0' && c <= '9') value |= c - '0';
            else if (c >= 'a' && c <= 'f') value |= c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') value |= c - 'A' + 10;
            else return std::nullopt;
        }
        return value;
    }

    std::optional<std::string> string() {
        if (!take('"')) return std::nullopt;
        std::u16string units;
        std::string out;
        auto flush = [&] {
            out += toUtf8(fromUtf16(units));
            units.clear();
        };
        while (i_ < s_.size()) {
            const char c = s_[i_++];
            if (c == '"') {
                flush();
                return out;
            }
            if (c != '\\') {
                flush();
                out.push_back(c);
                continue;
            }
            if (i_ >= s_.size()) return std::nullopt;
            const char e = s_[i_++];
            if (e == 'u') {
                const auto unit = hex4();
                if (!unit) return std::nullopt;
                units.push_back(static_cast<char16_t>(*unit));
                continue;
            }
            flush();
            switch (e) {
            case '"': out.push_back('"'); break;
            case '\\': out.push_back('\\'); break;
            case '/': out.push_back('/'); break;
            case 'n': out.push_back('\n'); break;
            case 't': out.push_back('\t'); break;
            case 'r': out.push_back('\r'); break;
            case 'b': out.push_back('\b'); break;
            case 'f': out.push_back('\f'); break;
            default: return std::nullopt;
            }
        }
        return std::nullopt;
    }
};

}  // namespace

std::optional<std::vector<JsonObject>> parseObjects(const std::string& json) {
    return Parser(json).objects();
}

std::optional<std::string> readFile(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) return std::nullopt;
    std::ostringstream contents;
    contents << file.rdbuf();
    return contents.str();
}

}  // namespace xattot::test
