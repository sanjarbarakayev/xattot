#pragma once

#include <map>
#include <optional>
#include <string>
#include <vector>

namespace xattot::test {

using JsonObject = std::map<std::string, std::string>;

// Parses a JSON array of objects whose values are all strings, the shape of
// inputmethod/Tests/parity.json and divergences.json. nullopt on anything else.
std::optional<std::vector<JsonObject>> parseObjects(const std::string& json);

std::optional<std::string> readFile(const std::string& path);

}  // namespace xattot::test
