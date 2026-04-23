// Copyright (c) 2026 InfiquiTra. All rights reserved.
// This file is part of the mimir project.

import 'dart:math';

/// Extension on [List] to provide chunking capabilities.
extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive chunks of at most [size] items.
  ///
  /// Throws an [ArgumentError] if [size] < 1.
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError('Chunk size must be at least 1. Provided: $size');
    }

    if (isEmpty) {
      return <List<T>>[];
    }

    final List<List<T>> chunks = [];
    for (var i = 0; i < length; i += size) {
      chunks.add(sublist(i, min(i + size, length)));
    }

    return chunks;
  }
}
