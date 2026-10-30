#pragma once

#include <windows.h>

#include <utility>

namespace xattot::tsf {

// An owning COM pointer: Release on destruction, AddRef on copy.
template <typename T>
class Com {
public:
    Com() = default;
    Com(T* p) : p_(p) {
        if (p_) p_->AddRef();
    }
    Com(const Com& other) : Com(other.p_) {}
    Com(Com&& other) noexcept : p_(std::exchange(other.p_, nullptr)) {}
    ~Com() { reset(); }

    Com& operator=(Com other) noexcept {
        std::swap(p_, other.p_);
        return *this;
    }

    // Takes over a reference the caller already owns, such as an out parameter's.
    static Com attach(T* p) {
        Com out;
        out.p_ = p;
        return out;
    }

    void reset() {
        if (p_) std::exchange(p_, nullptr)->Release();
    }

    T* get() const { return p_; }
    T* operator->() const { return p_; }
    explicit operator bool() const { return p_ != nullptr; }

    // For out parameters: releases what it holds first.
    T** put() {
        reset();
        return &p_;
    }

    template <typename U>
    Com<U> as() const {
        Com<U> out;
        if (p_) p_->QueryInterface(__uuidof(U), reinterpret_cast<void**>(out.put()));
        return out;
    }

private:
    T* p_ = nullptr;
};

}  // namespace xattot::tsf
