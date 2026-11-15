#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

/// One side of the maximize button's rectangle, in device pixels. Dart sends
/// them as a map of ints; a double is answered too, because a codec is free to
/// hand a whole number back as one.
long FrameNumber(const flutter::EncodableMap& map, const char* key) {
  const auto found = map.find(flutter::EncodableValue(key));
  if (found == map.end()) {
    return 0;
  }
  const flutter::EncodableValue& value = found->second;
  if (const auto* whole = std::get_if<int32_t>(&value)) {
    return *whole;
  }
  if (const auto* large = std::get_if<int64_t>(&value)) {
    return static_cast<long>(*large);
  }
  if (const auto* fraction = std::get_if<double>(&value)) {
    return static_cast<long>(*fraction);
  }
  return 0;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // The app draws the window's controls, so it has to tell the runner where
  // the one control Windows cares about is. In return the runner tells it when
  // the pointer is over that rectangle, because the pointer stops being the
  // app's there: the system takes it for the snap layouts flyout.
  frame_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "com.kallo.app/frame",
          &flutter::StandardMethodCodec::GetInstance());
  frame_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "maximizeButton") {
          result->NotImplemented();
          return;
        }
        const flutter::EncodableValue* arguments = call.arguments();
        const auto* rectangle =
            arguments == nullptr
                ? nullptr
                : std::get_if<flutter::EncodableMap>(arguments);
        if (rectangle == nullptr) {
          result->Error("bad_arguments", "maximizeButton needs a rectangle");
          return;
        }
        RECT rect{};
        rect.left = FrameNumber(*rectangle, "left");
        rect.top = FrameNumber(*rectangle, "top");
        rect.right = rect.left + FrameNumber(*rectangle, "width");
        rect.bottom = rect.top + FrameNumber(*rectangle, "height");
        SetCaptionButton(rect);
        result->Success();
      });
  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // The window has no frame for Windows to measure, so the rectangle it hands a
  // maximized window can be the work area with a frame's worth added on every
  // side and taken back off the position: eleven pixels of the app off the left
  // and right edges of the screen at 150 %, and eleven more under the bar at
  // the top. The size is asked for here, and `Win32Window` puts the window back
  // on the work area afterwards if Windows added the frame anyway.
  //
  // This has to be answered before the plugins: window_manager fills in the
  // track sizes of this same message and returns 0, which would stop it here.
  if (message == WM_GETMINMAXINFO) {
    HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info{sizeof(MONITORINFO)};
    if (monitor != nullptr && ::GetMonitorInfo(monitor, &info)) {
      MINMAXINFO* minmax = reinterpret_cast<MINMAXINFO*>(lparam);
      minmax->ptMaxPosition.x = info.rcWork.left - info.rcMonitor.left;
      minmax->ptMaxPosition.y = info.rcWork.top - info.rcMonitor.top;
      minmax->ptMaxSize.x = info.rcWork.right - info.rcWork.left;
      minmax->ptMaxSize.y = info.rcWork.bottom - info.rcWork.top;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
