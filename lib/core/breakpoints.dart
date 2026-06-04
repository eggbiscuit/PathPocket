/// Responsive breakpoints used throughout the app.
enum Breakpoint { mobile, tablet, desktop }

class Breakpoints {
  Breakpoints._();
  static const double tablet = 600;
  static const double desktop = 1024;

  static Breakpoint of(double width) {
    if (width >= desktop) return Breakpoint.desktop;
    if (width >= tablet) return Breakpoint.tablet;
    return Breakpoint.mobile;
  }
}
