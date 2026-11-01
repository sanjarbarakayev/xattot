#pragma once

#include <map>
#include <memory>
#include <optional>
#include <set>
#include <string>

#include "Key.h"
#include "Text.h"

namespace xattot {

// Persists the apps learned to need marked text; the host supplies the storage.
// Changes go one app at a time, so each process's `AppModes` keeps what the others stored.
class ModeStore {
public:
    virtual ~ModeStore() = default;
    virtual std::set<std::string> learnedMarkedApps() const = 0;
    virtual void learnMarkedApp(const std::string& app) = 0;
    virtual void forgetMarkedApp(const std::string& app) = 0;
};

// Which mode each client app gets: seeded Monaco editors plus apps learned at run time.
// Apps are lowercase executable names on Windows (`code.exe`).
class AppModes {
public:
    static const std::set<std::string>& seeded();

    explicit AppModes(std::shared_ptr<ModeStore> store);

    Mode mode(const std::string& app) const;

    // Reports what a replacement check found (nullopt: no text). Never call it right after a replacement:
    // Chromium updates its text asynchronously, so an early read looks stale in any app.
    // Stale text is learned and saved at once; "no text" must repeat and only lasts the session.
    // `expected` and `staleView` come from `Engine::lastReplacement()`.
    void observe(const std::string& app, const std::optional<Text>& found, const Text& expected, const Text& staleView);

    // Undoes a wrong learning. Seeded apps stay marked.
    void forget(const std::string& app);

private:
    // Consecutive "no text" reports that mark an app for this session.
    static constexpr int nilLimit = 3;

    std::shared_ptr<ModeStore> store_;
    std::set<std::string> learned_;
    std::set<std::string> sessionMarked_;
    std::map<std::string, int> nilStreak_;
};

}  // namespace xattot
