import 'package:flutter/foundation.dart';

import 'is_desktop.dart';

/// 手机 / 平板（Android、iOS），不含 Web。
bool get isMobile => !kIsWeb && !isDesktop;
