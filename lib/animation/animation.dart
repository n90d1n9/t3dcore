/// Animation system for tenun_3d_core.
///
/// Provides a complete animation framework with timelines, tracks,
/// keyframes, interpolators, and players - matching modern rendering
/// engine architecture.
library;

import 'dart:math' as math;

import '../scene/scene_graph.dart';

/// Abstract base for all animation interpolators.
abstract class Interpolator<T> {
  const Interpolator();

  /// Interpolates between two values at time t (0.0 to 1.0).
  T interpolate(T from, T to, double t);
}

/// Linear interpolation for numeric values.
class LinearInterpolator<T extends num> extends Interpolator<T> {
  const LinearInterpolator();

  @override
  T interpolate(T from, T to, double t) {
    if (from is double && to is double) {
      return (from + (to - from) * t) as T;
    } else if (from is int && to is int) {
      return ((from + (to - from) * t).round()) as T;
    }
    return from;
  }
}

/// Bezier curve interpolation for smooth animations.
class BezierInterpolator extends Interpolator<double> {
  const BezierInterpolator({
    this.cp1 = 0.25,
    this.cp2 = 0.75,
  });

  final double cp1; // Control point 1
  final double cp2; // Control point 2

  @override
  double interpolate(double from, double to, double t) {
    final eased = _cubicBezier(t, cp1, cp2);
    return from + (to - from) * eased;
  }

  double _cubicBezier(double t, double p1, double p2) {
    final u = 1.0 - t;
    return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t;
  }
}

/// Step interpolation for discrete value changes.
class StepInterpolator<T> extends Interpolator<T> {
  const StepInterpolator();

  @override
  T interpolate(T from, T to, double t) {
    return t < 1.0 ? from : to;
  }
}

/// Spherical linear interpolation for quaternions.
class SlerpInterpolator extends Interpolator<List<double>> {
  const SlerpInterpolator();

  @override
  List<double> interpolate(List<double> from, List<double> to, double t) {
    if (from.length != 4 || to.length != 4) {
      return from;
    }

    final dot = from[0] * to[0] + from[1] * to[1] + from[2] * to[2] + from[3] * to[3];
    final absDot = dot.abs();
    
    // If quaternions are nearly identical, use linear interpolation
    if (absDot > 0.9995) {
      return [
        from[0] + (to[0] - from[0]) * t,
        from[1] + (to[1] - from[1]) * t,
        from[2] + (to[2] - from[2]) * t,
        from[3] + (to[3] - from[3]) * t,
      ].map((v) => v / math.sqrt(from[0] * from[0] + from[1] * from[1] + 
                                   from[2] * from[2] + from[3] * from[3])).toList();
    }

    final theta = math.acos(absDot);
    final sinTheta = math.sin(theta);
    
    final a = math.sin((1.0 - t) * theta) / sinTheta;
    final b = math.sin(t * theta) / sinTheta;
    
    if (dot < 0) {
      return [
        from[0] * a - to[0] * b,
        from[1] * a - to[1] * b,
        from[2] * a - to[2] * b,
        from[3] * a - to[3] * b,
      ];
    }
    
    return [
      from[0] * a + to[0] * b,
      from[1] * a + to[1] * b,
      from[2] * a + to[2] * b,
      from[3] * a + to[3] * b,
    ];
  }
}

/// A single keyframe in an animation track.
class Keyframe<T> {
  const Keyframe({
    required this.time,
    required this.value,
    this.interpolator,
  });

  /// Time in seconds when this keyframe occurs.
  final double time;

  /// The value at this keyframe.
  final T value;

  /// Optional custom interpolator for this keyframe.
  final Interpolator<T>? interpolator;
}

/// Base class for animation tracks.
abstract class AnimationTrack<T> {
  const AnimationTrack({
    required this.targetPath,
    required this.keyframes,
  });

  /// Path to the target property (e.g., 'transform.position', 'material.opacity').
  final String targetPath;

  /// List of keyframes defining the animation.
  final List<Keyframe<T>> keyframes;

  /// Gets the interpolated value at a specific time.
  T getValueAtTime(double time) {
    if (keyframes.isEmpty) {
      throw StateError('Cannot evaluate empty track');
    }

    // Handle edge cases
    if (time <= keyframes.first.time) {
      return keyframes.first.value;
    }
    if (time >= keyframes.last.time) {
      return keyframes.last.value;
    }

    // Find the two keyframes to interpolate between
    for (var i = 0; i < keyframes.length - 1; i++) {
      final current = keyframes[i];
      final next = keyframes[i + 1];
      
      if (time >= current.time && time < next.time) {
        final duration = next.time - current.time;
        final t = duration > 0 ? (time - current.time) / duration : 0.0;
        final interpolator = current.interpolator ?? const LinearInterpolator<num>() as Interpolator<T>;
        return interpolator.interpolate(current.value, next.value, t);
      }
    }

    return keyframes.last.value;
  }

  /// Gets the total duration of this track.
  double get duration {
    if (keyframes.isEmpty) return 0.0;
    return keyframes.last.time - keyframes.first.time;
  }
}

/// Track for animating transform properties.
class TransformTrack extends AnimationTrack<Vec3> {
  const TransformTrack({
    required super.targetPath,
    required super.keyframes,
  });
}

/// Track for animating rotation (quaternion).
class RotationTrack extends AnimationTrack<List<double>> {
  const RotationTrack({
    required super.targetPath,
    required super.keyframes,
    Interpolator<List<double>>? interpolator,
  }) : super(
         keyframes: interpolator != null 
           ? keyframes.map((k) => Keyframe(
               time: k.time,
               value: k.value,
               interpolator: interpolator,
             )).toList()
           : keyframes,
       );
}

/// Track for animating scale.
class ScaleTrack extends AnimationTrack<Vec3> {
  const ScaleTrack({
    required super.targetPath,
    required super.keyframes,
  });
}

/// Track for animating material properties.
class MaterialTrack extends AnimationTrack<double> {
  const MaterialTrack({
    required super.targetPath,
    required super.keyframes,
  });
}

/// Track for animating visibility.
class VisibilityTrack extends AnimationTrack<bool> {
  const VisibilityTrack({
    required super.targetPath,
    required super.keyframes,
  }) : super(
         keyframes: keyframes.map((k) => Keyframe(
           time: k.time,
           value: k.value,
           interpolator: const StepInterpolator<bool>(),
         )).toList(),
       );
}

/// An animation clip containing multiple tracks.
class AnimationClip {
  const AnimationClip({
    required this.name,
    required this.tracks,
    this.duration,
    this.loop = false,
  });

  /// Name of this animation clip.
  final String name;

  /// All animation tracks in this clip.
  final List<AnimationTrack> tracks;

  /// Optional explicit duration (auto-calculated if null).
  final double? duration;

  /// Whether this animation should loop.
  final bool loop;

  /// Gets the total duration of this clip.
  double get computedDuration {
    if (duration != null) return duration!;
    if (tracks.isEmpty) return 0.0;
    return tracks.map((t) => t.duration).reduce((a, b) => a > b ? a : b);
  }

  /// Evaluates all tracks at a specific time and returns the results.
  Map<String, dynamic> evaluate(double time) {
    final result = <String, dynamic>{};
    for (final track in tracks) {
      // Use reflection-like approach via targetPath
      result[track.targetPath] = _evaluateTrack(track, time);
    }
    return result;
  }

  dynamic _evaluateTrack(AnimationTrack track, double time) {
    // This would be implemented with proper type handling
    // For now, delegate to the track's method
    return track.getValueAtTime(time);
  }
}

/// Animation player for controlling playback.
class AnimationPlayer {
  AnimationPlayer({
    this.autoPlay = false,
    this.speed = 1.0,
  }) {
    if (autoPlay) {
      play();
    }
  }

  /// Current animation clip being played.
  AnimationClip? _currentClip;

  /// Current playback time in seconds.
  double _currentTime = 0.0;

  /// Playback state.
  bool _isPlaying = false;

  /// Whether to auto-play when a clip is set.
  final bool autoPlay;

  /// Playback speed multiplier (1.0 = normal speed).
  final double speed;

  /// Callback fired when animation completes.
  VoidCallback? onComplete;

  /// Callback fired on each frame update.
  void Function(double time)? onUpdate;

  /// Gets the currently playing clip.
  AnimationClip? get currentClip => _currentClip;

  /// Gets whether the animation is currently playing.
  bool get isPlaying => _isPlaying;

  /// Gets the current playback time.
  double get currentTime => _currentTime;

  /// Sets and plays an animation clip.
  void setClip(AnimationClip clip) {
    _currentClip = clip;
    _currentTime = 0.0;
    if (autoPlay) {
      play();
    }
  }

  /// Starts playback.
  void play() {
    if (_currentClip == null) {
      throw StateError('No animation clip set');
    }
    _isPlaying = true;
  }

  /// Pauses playback.
  void pause() {
    _isPlaying = false;
  }

  /// Stops playback and resets time.
  void stop() {
    _isPlaying = false;
    _currentTime = 0.0;
  }

  /// Seeks to a specific time.
  void seek(double time) {
    if (_currentClip == null) return;
    _currentTime = time.clamp(0.0, _currentClip!.computedDuration);
  }

  /// Updates the animation by a delta time.
  void update(double deltaTime) {
    if (!_isPlaying || _currentClip == null) return;

    _currentTime += deltaTime * speed;
    
    final duration = _currentClip!.computedDuration;
    
    if (_currentTime >= duration) {
      if (_currentClip!.loop) {
        _currentTime = _currentTime % duration;
      } else {
        _currentTime = duration;
        _isPlaying = false;
        onComplete?.call();
      }
    }

    onUpdate?.call(_currentTime);
  }

  /// Gets the evaluated state at current time.
  Map<String, dynamic> getCurrentState() {
    if (_currentClip == null) return {};
    return _currentClip!.evaluate(_currentTime);
  }
}

/// Simple function type for callbacks without parameters.
typedef VoidCallback = void Function();

/// Timeline for managing multiple animation clips and sequences.
class Timeline {
  Timeline();

  final List<_TimelineEvent> _events = [];
  double _currentTime = 0.0;
  bool _isPlaying = false;

  /// Adds a clip to the timeline at a specific start time.
  void addClip(AnimationClip clip, {double startTime = 0.0, double weight = 1.0}) {
    _events.add(_TimelineEvent(
      clip: clip,
      startTime: startTime,
      weight: weight,
    ));
  }

  /// Adds a callback event at a specific time.
  void addEvent(double time, VoidCallback callback) {
    _events.add(_TimelineEvent(
      clip: null,
      startTime: time,
      callback: callback,
    ));
  }

  /// Starts timeline playback.
  void play() {
    _isPlaying = true;
  }

  /// Pauses timeline playback.
  void pause() {
    _isPlaying = false;
  }

  /// Stops timeline and resets time.
  void stop() {
    _isPlaying = false;
    _currentTime = 0.0;
  }

  /// Updates timeline by delta time.
  void update(double deltaTime) {
    if (!_isPlaying) return;

    _currentTime += deltaTime;

    for (final event in _events) {
      if (event.clip != null) {
        final localTime = _currentTime - event.startTime;
        if (localTime >= 0 && localTime <= event.clip!.computedDuration) {
          // Evaluate clip at local time
          event.clip!.evaluate(localTime);
        }
      } else if (event.callback != null && _currentTime >= event.startTime) {
        event.callback!();
      }
    }
  }

  /// Gets total duration of the timeline.
  double get duration {
    if (_events.isEmpty) return 0.0;
    return _events
        .where((e) => e.clip != null)
        .map((e) => e.startTime + e.clip!.computedDuration)
        .reduce((a, b) => a > b ? a : b);
  }
}

class _TimelineEvent {
  _TimelineEvent({
    required this.clip,
    required this.startTime,
    this.weight = 1.0,
    this.callback,
  });

  final AnimationClip? clip;
  final double startTime;
  final double weight;
  final VoidCallback? callback;
}

/// Pre-built animation curves for common effects.
class AnimationCurves {
  static const LinearInterpolator<double> linear = LinearInterpolator();
  static const BezierInterpolator easeIn = BezierInterpolator(cp1: 0.42, cp2: 0.0);
  static const BezierInterpolator easeOut = BezierInterpolator(cp1: 0.0, cp2: 0.58);
  static const BezierInterpolator easeInOut = BezierInterpolator(cp1: 0.42, cp2: 0.58);
  static const BezierInterpolator easeInBack = BezierInterpolator(cp1: 0.6, cp2: -0.2);
  static const BezierInterpolator easeOutBack = BezierInterpolator(cp1: 0.4, cp2: 1.4);
}
