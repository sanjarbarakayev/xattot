#include "AppModes.h"

namespace xattot {

const std::set<std::string>& AppModes::seeded() {
    static const std::set<std::string> apps = {"code.exe", "code - insiders.exe", "cursor.exe", "windsurf.exe"};
    return apps;
}

AppModes::AppModes(std::shared_ptr<ModeStore> store) : store_(std::move(store)), learned_(store_->learnedMarkedApps()) {}

Mode AppModes::mode(const std::string& app) const {
    const bool marked = seeded().count(app) || learned_.count(app) || sessionMarked_.count(app);
    return marked ? Mode::marked : Mode::eager;
}

void AppModes::observe(const std::string& app, const std::optional<Text>& found, const Text& expected,
                       const Text& staleView) {
    if (mode(app) != Mode::eager) return;
    if (!found) {
        const int streak = ++nilStreak_[app];
        if (streak >= nilLimit) sessionMarked_.insert(app);
        return;
    }
    nilStreak_.erase(app);
    if (*found != staleView || *found == expected) return;
    learned_.insert(app);
    store_->learnMarkedApp(app);
}

void AppModes::forget(const std::string& app) {
    sessionMarked_.erase(app);
    nilStreak_.erase(app);
    if (learned_.erase(app) > 0) store_->forgetMarkedApp(app);
}

}  // namespace xattot
