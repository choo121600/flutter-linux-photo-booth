import 'package:flutter/widgets.dart';

/// A named colour filter for the live camera preview and the captured photo.
class CameraFilter {
  final String name;
  final ColorFilter filter;
  const CameraFilter(this.name, this.filter);
}

/// Colour-matrix filters offered on the capture screen. They are applied inside
/// the preview's RepaintBoundary, so the saved photo matches what the user saw.
/// (Trailing `//` keeps `dart format` from collapsing each 5-value row.)
const List<CameraFilter> kCameraFilters = <CameraFilter>[
  CameraFilter(
    'Normal',
    ColorFilter.matrix(<double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
  ),
  CameraFilter(
    'B&W',
    ColorFilter.matrix(<double>[
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
  ),
  CameraFilter(
    'Sepia',
    ColorFilter.matrix(<double>[
      0.393, 0.769, 0.189, 0, 0, //
      0.349, 0.686, 0.168, 0, 0, //
      0.272, 0.534, 0.131, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
  ),
  CameraFilter(
    'Warm',
    ColorFilter.matrix(<double>[
      1.06, 0, 0, 0, 15, //
      0, 1.0, 0, 0, 5, //
      0, 0, 0.94, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
  ),
  CameraFilter(
    'Cool',
    ColorFilter.matrix(<double>[
      0.94, 0, 0, 0, 0, //
      0, 1.0, 0, 0, 5, //
      0, 0, 1.08, 0, 15, //
      0, 0, 0, 1, 0,
    ]),
  ),
  CameraFilter(
    'Vivid',
    ColorFilter.matrix(<double>[
      1.276, -0.250, -0.025, 0, 0, //
      -0.074, 1.100, -0.025, 0, 0, //
      -0.074, -0.250, 1.325, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
  ),
  CameraFilter(
    'Soft',
    ColorFilter.matrix(<double>[
      1.0, 0, 0, 0, 22, //
      0, 1.0, 0, 0, 20, //
      0, 0, 1.0, 0, 14, //
      0, 0, 0, 1, 0,
    ]),
  ),
];
