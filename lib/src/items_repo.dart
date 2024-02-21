import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tatlacas_flutter_core/src/models/tapped_item_kind.dart';

import 'models/section.dart';

abstract class ItemsRepo {
  const ItemsRepo();
  Future<LoadItemsResult<Section>> loadItemsFromLocalStorage({
    required ThemeData theme,
    required Function(String url, TappedItemKind kind) onTapUrl,
  }) async =>
      LoadItemsResult<Section>.empty();

  Future<LoadItemsResult<Section>> loadItemsFromCloud({
    required ThemeData theme,
    required Function(String url, TappedItemKind kind) onTapUrl,
  }) async =>
      LoadItemsResult<Section>.empty();
  int get pageSize => 20;
}
