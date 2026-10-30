#pragma once

#include "../engine/AppModes.h"

namespace xattot::tsf {

// Learned marked-text apps in HKCU\Software\Xattot\InputMethod, value LearnedMarkedApps (REG_MULTI_SZ).
// Every process has its own `AppModes`, so each change reads the stored set first.
// Store apps run without access to it: they read nothing and their writes fail, which costs only learning.
class RegistryModeStore final : public ModeStore {
public:
    std::set<std::string> learnedMarkedApps() const override;
    void learnMarkedApp(const std::string& app) override;
    void forgetMarkedApp(const std::string& app) override;

private:
    void save(const std::set<std::string>& apps) const;
};

}  // namespace xattot::tsf
