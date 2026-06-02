// Web implementation — calls the browser reload API
import 'package:web/web.dart' as web;

void reloadWindow() {
  web.window.location.reload();
}
