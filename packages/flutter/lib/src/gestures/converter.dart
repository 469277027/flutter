// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show PointerData, PointerChange;

import 'events.dart';

class _PointerState {
  _PointerState(this.lastPosition);

  int get pointer => _pointer; // The identifier used in PointerEvent objects.
  int _pointer;
  static int _pointerCount = 0;
  void startNewPointer() {
    _pointerCount += 1;
    _pointer = _pointerCount;
  }

  bool get down => _down;
  bool _down = false;
  void setDown() {
    assert(!_down);
    _down = true;
  }
  void setUp() {
    assert(_down);
    _down = false;
  }

  Point lastPosition;
}

/// Converts from engine pointer data to framework pointer events.
class PointerEventConverter {
  // Map from platform pointer identifiers to PointerEvent pointer identifiers.
  static Map<int, _PointerState> _pointers = <int, _PointerState>{};

  static _PointerState _ensureStateForPointer(ui.PointerData datum, Point position) {
    return _pointers.putIfAbsent(
      datum.device,
      () => new _PointerState(position)
    );
  }

  /// Expand the given packet of pointer data into a sequence of framework pointer events.
  static Iterable<PointerEvent> expand(Iterable<ui.PointerData> data, double devicePixelRatio) sync* {
    for (ui.PointerData datum in data) {
      final Point position = new Point(datum.physicalX, datum.physicalY) / devicePixelRatio;
      final Duration timeStamp = datum.timeStamp;
      final PointerDeviceKind kind = datum.kind;
      assert(datum.change != null);
      switch (datum.change) {
        case ui.PointerChange.add:
          assert(!_pointers.containsKey(datum.device));
          _PointerState state = _ensureStateForPointer(datum, position);
          assert(state.lastPosition == position);
          yield new PointerAddedEvent(
            timeStamp: timeStamp,
            kind: kind,
            device: datum.device,
            position: position,
            obscured: datum.obscured,
            pressureMin: datum.pressureMin,
            pressureMax: datum.pressureMax,
            distance: datum.distance,
            distanceMax: datum.distanceMax,
            radiusMin: datum.radiusMin,
            radiusMax: datum.radiusMax,
            orientation: datum.orientation,
            tilt: datum.tilt
          );
          break;
        case ui.PointerChange.hover:
          final bool alreadyAdded = _pointers.containsKey(datum.device);
          _PointerState state = _ensureStateForPointer(datum, position);
          assert(!state.down);
          if (!alreadyAdded) {
            assert(state.lastPosition == position);
            yield new PointerAddedEvent(
              timeStamp: timeStamp,
              kind: kind,
              device: datum.device,
              position: position,
              obscured: datum.obscured,
              pressureMin: datum.pressureMin,
              pressureMax: datum.pressureMax,
              distance: datum.distance,
              distanceMax: datum.distanceMax,
              radiusMin: datum.radiusMin,
              radiusMax: datum.radiusMax,
              orientation: datum.orientation,
              tilt: datum.tilt
            );
          }
          Offset offset = position - state.lastPosition;
          state.lastPosition = position;
          yield new PointerHoverEvent(
            timeStamp: timeStamp,
            kind: kind,
            device: datum.device,
            position: position,
            delta: offset,
            buttons: datum.buttons,
            obscured: datum.obscured,
            pressureMin: datum.pressureMin,
            pressureMax: datum.pressureMax,
            distance: datum.distance,
            distanceMax: datum.distanceMax,
            radiusMajor: datum.radiusMajor,
            radiusMinor: datum.radiusMajor,
            radiusMin: datum.radiusMin,
            radiusMax: datum.radiusMax,
            orientation: datum.orientation,
            tilt: datum.tilt
          );
          state.lastPosition = position;
          break;
        case ui.PointerChange.down:
          final bool alreadyAdded = _pointers.containsKey(datum.device);
          _PointerState state = _ensureStateForPointer(datum, position);
          assert(!state.down);
          if (!alreadyAdded) {
            assert(state.lastPosition == position);
            yield new PointerAddedEvent(
              timeStamp: timeStamp,
              kind: kind,
              device: datum.device,
              position: position,
              obscured: datum.obscured,
              pressureMin: datum.pressureMin,
              pressureMax: datum.pressureMax,
              distance: datum.distance,
              distanceMax: datum.distanceMax,
              radiusMin: datum.radiusMin,
              radiusMax: datum.radiusMax,
              orientation: datum.orientation,
              tilt: datum.tilt
            );
          }
          if (state.lastPosition != position) {
            // Not all sources of pointer packets respect the invariant that
            // they hover the pointer to the down location before sending the
            // down event. We restore the invariant here for our clients.
            Offset offset = position - state.lastPosition;
            state.lastPosition = position;
            yield new PointerHoverEvent(
              timeStamp: timeStamp,
              kind: kind,
              device: datum.device,
              position: position,
              delta: offset,
              buttons: datum.buttons,
              obscured: datum.obscured,
              pressureMin: datum.pressureMin,
              pressureMax: datum.pressureMax,
              distance: datum.distance,
              distanceMax: datum.distanceMax,
              radiusMajor: datum.radiusMajor,
              radiusMinor: datum.radiusMajor,
              radiusMin: datum.radiusMin,
              radiusMax: datum.radiusMax,
              orientation: datum.orientation,
              tilt: datum.tilt
            );
            state.lastPosition = position;
          }
          state.startNewPointer();
          state.setDown();
          yield new PointerDownEvent(
            timeStamp: timeStamp,
            pointer: state.pointer,
            kind: kind,
            device: datum.device,
            position: position,
            buttons: datum.buttons,
            obscured: datum.obscured,
            pressure: datum.pressure,
            pressureMin: datum.pressureMin,
            pressureMax: datum.pressureMax,
            distanceMax: datum.distanceMax,
            radiusMajor: datum.radiusMajor,
            radiusMinor: datum.radiusMajor,
            radiusMin: datum.radiusMin,
            radiusMax: datum.radiusMax,
            orientation: datum.orientation,
            tilt: datum.tilt
          );
          break;
        case ui.PointerChange.move:
          // If the service starts supporting hover pointers, then it must also
          // start sending us ADDED and REMOVED data points.
          // See also: https://github.com/flutter/flutter/issues/720
          assert(_pointers.containsKey(datum.device));
          _PointerState state = _pointers[datum.device];
          assert(state.down);
          Offset offset = position - state.lastPosition;
          state.lastPosition = position;
          yield new PointerMoveEvent(
            timeStamp: timeStamp,
            pointer: state.pointer,
            kind: kind,
            device: datum.device,
            position: position,
            delta: offset,
            buttons: datum.buttons,
            obscured: datum.obscured,
            pressure: datum.pressure,
            pressureMin: datum.pressureMin,
            pressureMax: datum.pressureMax,
            distanceMax: datum.distanceMax,
            radiusMajor: datum.radiusMajor,
            radiusMinor: datum.radiusMajor,
            radiusMin: datum.radiusMin,
            radiusMax: datum.radiusMax,
            orientation: datum.orientation,
            tilt: datum.tilt
          );
          break;
        case ui.PointerChange.up:
        case ui.PointerChange.cancel:
          assert(_pointers.containsKey(datum.device));
          _PointerState state = _pointers[datum.device];
          assert(state.down);
          if (position != state.lastPosition) {
            // Not all sources of pointer packets respect the invariant that
            // they move the pointer to the up location before sending the up
            // event. For example, in the iOS simulator, of you drag outside the
            // window, you'll get a stream of pointers that violates that
            // invariant. We restore the invariant here for our clients.
            Offset offset = position - state.lastPosition;
            state.lastPosition = position;
            yield new PointerMoveEvent(
              timeStamp: timeStamp,
              pointer: state.pointer,
              kind: kind,
              device: datum.device,
              position: position,
              delta: offset,
              buttons: datum.buttons,
              obscured: datum.obscured,
              pressure: datum.pressure,
              pressureMin: datum.pressureMin,
              pressureMax: datum.pressureMax,
              distanceMax: datum.distanceMax,
              radiusMajor: datum.radiusMajor,
              radiusMinor: datum.radiusMajor,
              radiusMin: datum.radiusMin,
              radiusMax: datum.radiusMax,
              orientation: datum.orientation,
              tilt: datum.tilt
            );
            state.lastPosition = position;
          }
          assert(position == state.lastPosition);
          state.setUp();
          if (datum.change == ui.PointerChange.up) {
            yield new PointerUpEvent(
              timeStamp: timeStamp,
              pointer: state.pointer,
              kind: kind,
              device: datum.device,
              position: position,
              buttons: datum.buttons,
              obscured: datum.obscured,
              pressureMax: datum.pressureMax,
              distance: datum.distance,
              distanceMax: datum.distanceMax,
              radiusMin: datum.radiusMin,
              radiusMax: datum.radiusMax,
              orientation: datum.orientation,
              tilt: datum.tilt
            );
          } else {
            yield new PointerCancelEvent(
              timeStamp: timeStamp,
              pointer: state.pointer,
              kind: kind,
              device: datum.device,
              position: position,
              buttons: datum.buttons,
              obscured: datum.obscured,
              pressureMin: datum.pressureMin,
              pressureMax: datum.pressureMax,
              distance: datum.distance,
              distanceMax: datum.distanceMax,
              radiusMin: datum.radiusMin,
              radiusMax: datum.radiusMax,
              orientation: datum.orientation,
              tilt: datum.tilt
            );
          }
          break;
        case ui.PointerChange.remove:
          assert(_pointers.containsKey(datum.device));
          _PointerState state = _pointers[datum.device];
          if (state.down) {
            yield new PointerCancelEvent(
              timeStamp: timeStamp,
              pointer: state.pointer,
              kind: kind,
              device: datum.device,
              position: position,
              buttons: datum.buttons,
              obscured: datum.obscured,
              pressureMin: datum.pressureMin,
              pressureMax: datum.pressureMax,
              distance: datum.distance,
              distanceMax: datum.distanceMax,
              radiusMin: datum.radiusMin,
              radiusMax: datum.radiusMax,
              orientation: datum.orientation,
              tilt: datum.tilt
            );
          }
          _pointers.remove(datum.device);
          yield new PointerRemovedEvent(
            timeStamp: timeStamp,
            kind: kind,
            device: datum.device,
            obscured: datum.obscured,
            pressureMin: datum.pressureMin,
            pressureMax: datum.pressureMax,
            distanceMax: datum.distanceMax,
            radiusMin: datum.radiusMin,
            radiusMax: datum.radiusMax
          );
          break;
      }
    }
  }
}
