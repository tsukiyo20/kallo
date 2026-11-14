/// What the window looks like around the app.
///
/// `mac` and `windows` both mean the system's title bar is hidden and the
/// content runs to the top edge; what differs is who draws the way out of the
/// window. On the Mac the traffic lights stay the system's and sit over the
/// sidebar, so the app only has to keep out of their way. On Windows the
/// controls are the app's own, because the system's bar is gone. It is pinned
/// rather than read from `Platform` at the point of use, so a golden can draw
/// the same window anywhere.
enum WindowChrome {
  /// The system draws a title bar above the app.
  plain,

  /// No title bar; traffic lights over the sidebar, toolbar drags the window.
  mac,

  /// No title bar; the app draws the way out over the content's top-right.
  windows,
}
