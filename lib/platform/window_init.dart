import 'package:flutter/material.dart';

import 'window_init_stub.dart'
    if (dart.library.io) 'window_init_io.dart' as impl;

Future<void> initWindowIfDesktop({Color? backgroundColor}) =>
    impl.initWindowIfDesktop(backgroundColor: backgroundColor);

Future<void> syncWindowBackground(Color color) =>
    impl.syncWindowBackground(color);
