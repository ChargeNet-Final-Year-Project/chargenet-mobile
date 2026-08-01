import 'package:flutter/foundation.dart';

import 'package:chargenet_mobile/data/models.dart';

/// Station selected on the home map.
final ValueNotifier<Station?> selectedStationNotifier = ValueNotifier<Station?>(
  null,
);
