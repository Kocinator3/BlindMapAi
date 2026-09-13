import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/geo.dart';
import '../domain/level.dart';

enum DrawTool { navigate, draw, move, addVertex, deleteVertex }

class MapCanvas extends StatefulWidget {
  final List<List<GeoPoint>> land;
  final MapConfig config;
  final AnswerType type;
  final List<GeoPoint> points;
  final Geometry? target;
  final ValueChanged<List<GeoPoint>> onChanged;
  final bool readOnly;
  final bool czech;
  const MapCanvas({
    super.key,
    required this.land,
    required this.config,
    required this.type,
    required this.points,
    required this.onChanged,
    this.target,
    this.readOnly = false,
    this.czech = true,
  });
  static Future<List<List<GeoPoint>>> loadLand() async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/maps/countries.geojson'),
    ) as Map<String, dynamic>;
    final rings = <List<GeoPoint>>[];
    for (final f in json['features'] as List) {
      final g = f['geometry'];
      final polygons = g['type'] == 'Polygon'
          ? [g['coordinates']]
          : g['coordinates'] as List;
      for (final polygon in polygons) {
        rings.add([
          for (final p in polygon[0])
            GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ]);
      }
    }
    return rings;
  }

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> {
  DrawTool tool = DrawTool.draw;
  late GeoPoint center = widget.config.center;
  late double span = widget.config.span;
  double startSpan = 0;
  GeoPoint? gestureCenter, circleCenter;
  Offset? gestureStart;
  int? selected;
  List<GeoPoint> draft = [];
  final List<List<GeoPoint>> undo = [], redo = [];
  Size size = Size.zero;
  String tr(String cs, String en) => widget.czech ? cs : en;
  double get scale => size.width / span;
  double get latitudeScale =>
      scale / math.cos(radians(center.lat)).clamp(0.15, 1);
  GeoPoint geo(Offset p) => GeoPoint(
    (center.lon + (p.dx - size.width / 2) / scale).clamp(-180, 180),
    (center.lat - (p.dy - size.height / 2) / latitudeScale).clamp(-85, 85),
  );
  Offset screen(GeoPoint p) => Offset(
    size.width / 2 + (p.lon - center.lon) * scale,
    size.height / 2 - (p.lat - center.lat) * latitudeScale,
  );
  void change(List<GeoPoint> points) {
    undo.add(List.of(widget.points));
    if (undo.length > 100) undo.removeAt(0);
    redo.clear();
    widget.onChanged(points);
  }

  void history(bool forward) {
    final from = forward ? redo : undo, to = forward ? undo : redo;
    if (from.isEmpty || widget.readOnly) return;
    to.add(List.of(widget.points));
    widget.onChanged(from.removeLast());
  }

  int? nearest(Offset p) {
    int? result;
    var distance = 24.0;
    for (var i = 0; i < widget.points.length; i++) {
      final d = (screen(widget.points[i]) - p).distance;
      if (d < distance) {
        distance = d;
        result = i;
      }
    }
    return result;
  }

  void tap(Offset p) {
    if (widget.readOnly || tool == DrawTool.navigate) return;
    final points = List<GeoPoint>.of(widget.points);
    if (tool == DrawTool.deleteVertex) {
      final i = nearest(p);
      if (i != null) {
        points.removeAt(i);
        change(points);
      }
      return;
    }
    if (tool == DrawTool.move) {
      setState(() => selected = nearest(p));
      return;
    }
    if (tool == DrawTool.addVertex && points.length > 1) {
      var best = double.infinity, index = 1;
      for (var i = 1; i < points.length; i++) {
        final a = screen(points[i - 1]), b = screen(points[i]);
        final d = segmentDistance(
          XY(p.dx, p.dy),
          XY(a.dx, a.dy),
          XY(b.dx, b.dy),
        );
        if (d < best) {
          best = d;
          index = i;
        }
      }
      points.insert(index, geo(p));
      change(points);
      return;
    }
    if (widget.type == AnswerType.point) {
      change([geo(p)]);
    } else if (widget.type == AnswerType.multiPoint ||
        widget.type == AnswerType.polygon ||
        widget.type == AnswerType.polyline) {
      if (points.length < 500) change([...points, geo(p)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final ctrl = HardwareKeyboard.instance.isControlPressed;
        if (ctrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
          history(HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
        }
        if (ctrl && event.logicalKey == LogicalKeyboardKey.keyY) {
          history(true);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() {
            draft = [];
            tool = DrawTool.navigate;
          });
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.delete && !widget.readOnly) {
          change([]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 2,
            alignment: WrapAlignment.center,
            children: [
              for (final t in DrawTool.values)
                ChoiceChip(
                  label: Text(switch (t) {
                    DrawTool.navigate => tr('Posun', 'Navigate'),
                    DrawTool.draw => tr('Kreslit', 'Draw'),
                    DrawTool.move => tr('Přesun bodu', 'Move vertex'),
                    DrawTool.addVertex => tr('Přidat bod', 'Add vertex'),
                    DrawTool.deleteVertex => tr('Smazat bod', 'Delete vertex'),
                  }),
                  selected: tool == t,
                  onSelected: (_) => setState(() => tool = t),
                ),
              IconButton(
                tooltip: tr('Zpět (Ctrl+Z)', 'Undo (Ctrl+Z)'),
                onPressed: widget.readOnly ? null : () => history(false),
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: tr('Znovu (Ctrl+Y)', 'Redo (Ctrl+Y)'),
                onPressed: widget.readOnly ? null : () => history(true),
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                tooltip: tr('Vymazat', 'Clear'),
                onPressed: widget.readOnly ? null : () => change([]),
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton(
                tooltip: tr('Přiblížit', 'Zoom in'),
                onPressed: () =>
                    setState(() => span = (span / 1.4).clamp(0.1, 160)),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: tr('Oddálit', 'Zoom out'),
                onPressed: () =>
                    setState(() => span = (span * 1.4).clamp(0.1, 160)),
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                tooltip: tr('Výchozí pohled', 'Reset view'),
                onPressed: () => setState(() {
                  span = widget.config.span;
                  center = widget.config.center;
                }),
                icon: const Icon(Icons.center_focus_strong),
              ),
            ],
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  size = constraints.biggest;
                  return Semantics(
                    label: tr(
                      'Slepá mapa. Režim Posun umožňuje přiblížení a posun. Režim Kreslit zadává odpověď.',
                      'Blind map. Navigate mode pans and zooms; Draw mode enters an answer.',
                    ),
                    child: Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          setState(
                            () => span =
                                (span * math.exp(event.scrollDelta.dy * 0.0015))
                                    .clamp(0.1, 160),
                          );
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onSecondaryTap: () => setState(() {
                          draft = [];
                          tool = DrawTool.navigate;
                        }),
                        onTapUp: (details) => tap(details.localPosition),
                        onScaleStart: (details) {
                          gestureStart = details.localFocalPoint;
                          gestureCenter = center;
                          startSpan = span;
                          if (widget.readOnly || tool == DrawTool.navigate) {
                            return;
                          }
                          if (tool == DrawTool.move) {
                            selected = nearest(details.localFocalPoint);
                            draft = List.of(widget.points);
                          } else if (tool == DrawTool.draw) {
                            circleCenter = geo(details.localFocalPoint);
                            draft = [circleCenter!];
                          }
                        },
                        onScaleUpdate: (details) {
                          if (tool == DrawTool.navigate || widget.readOnly) {
                            setState(() {
                              span = (startSpan / details.scale).clamp(
                                0.1,
                                160,
                              );
                              final delta =
                                  details.localFocalPoint - gestureStart!;
                              center = GeoPoint(
                                (gestureCenter!.lon - delta.dx / scale).clamp(
                                  -180,
                                  180,
                                ),
                                (gestureCenter!.lat + delta.dy / latitudeScale)
                                    .clamp(-80, 80),
                              );
                            });
                            return;
                          }
                          if (details.pointerCount > 1) return;
                          final p = geo(details.localFocalPoint);
                          if (tool == DrawTool.move &&
                              selected != null &&
                              selected! < draft.length) {
                            setState(() => draft[selected!] = p);
                            return;
                          }
                          if (tool != DrawTool.draw) return;
                          if (widget.type == AnswerType.circle &&
                              circleCenter != null) {
                            final c = screen(circleCenter!),
                                r = (details.localFocalPoint - c).distance;
                            setState(
                              () => draft = [
                                for (var i = 0; i < 48; i++)
                                  geo(
                                    c +
                                        Offset(
                                          math.cos(i * math.pi / 24) * r,
                                          math.sin(i * math.pi / 24) * r,
                                        ),
                                  ),
                              ],
                            );
                          } else if (widget.type == AnswerType.polyline ||
                              widget.type == AnswerType.freehandArea) {
                            if (draft.length < 500 &&
                                (draft.isEmpty ||
                                    (screen(draft.last) -
                                                details.localFocalPoint)
                                            .distance >
                                        4)) {
                              setState(() => draft.add(p));
                            }
                          }
                        },
                        onScaleEnd: (_) {
                          if (!widget.readOnly &&
                              draft.isNotEmpty &&
                              (tool == DrawTool.move ||
                                  widget.type == AnswerType.polyline ||
                                  widget.type == AnswerType.freehandArea ||
                                  widget.type == AnswerType.circle)) {
                            change(
                              tool == DrawTool.move
                                  ? List.of(draft)
                                  : simplify(draft, toleranceKm: span * 0.035),
                            );
                          }
                          setState(() => draft = []);
                        },
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: size,
                            painter: _MapPainter(
                              land: widget.land,
                              center: center,
                              span: span,
                              points: draft.isEmpty ? widget.points : draft,
                              type: widget.type,
                              target: widget.target,
                              borders: widget.config.borders,
                              dark:
                                  Theme.of(context).brightness ==
                                  Brightness.dark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              tr(
                'Posun: táhnout / přiblížit • Kreslit: bod nebo tah • Natural Earth',
                'Navigate: pan / pinch • Draw: tap or trace • Natural Earth',
              ),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<List<GeoPoint>> land;
  final GeoPoint center;
  final double span;
  final List<GeoPoint> points;
  final AnswerType type;
  final Geometry? target;
  final bool borders, dark;
  _MapPainter({
    required this.land,
    required this.center,
    required this.span,
    required this.points,
    required this.type,
    required this.target,
    required this.borders,
    required this.dark,
  });
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(
      dark ? const Color(0xff132c3b) : const Color(0xffdcecf2),
      BlendMode.srcOver,
    );
    final sx = size.width / span,
        sy = sx / math.cos(radians(center.lat)).clamp(0.15, 1);
    Offset project(GeoPoint p) => Offset(
      size.width / 2 + (p.lon - center.lon) * sx,
      size.height / 2 - (p.lat - center.lat) * sy,
    );
    Path path(List<GeoPoint> ring, {bool close = false}) {
      final result = Path();
      for (var i = 0; i < ring.length; i++) {
        final p = project(ring[i]);
        if (i == 0) {
          result.moveTo(p.dx, p.dy);
        } else {
          result.lineTo(p.dx, p.dy);
        }
      }
      if (close) result.close();
      return result;
    }

    final fill = Paint()
      ..color = dark ? const Color(0xff304c50) : const Color(0xfff5f2e7);
    final border = Paint()
      ..color = dark ? const Color(0xff9bb4ad) : const Color(0xff829b94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final ring in land) {
      final p = path(ring, close: true);
      if (!p.getBounds().overlaps(Offset.zero & size)) continue;
      canvas.drawPath(p, fill);
      if (borders) canvas.drawPath(p, border);
    }
    void geometry(
      List<GeoPoint> coords,
      AnswerType kind,
      Color color, {
      bool reference = false,
    }) {
      final isPoint = kind == AnswerType.point || kind == AnswerType.multiPoint;
      final isArea = !isPoint && kind != AnswerType.polyline;
      if (!isPoint) {
        final p = path(coords, close: isArea);
        if (isArea) {
          canvas.drawPath(p, Paint()..color = color.withValues(alpha: 0.20));
        }
        canvas.drawPath(
          p,
          Paint()
            ..color = color
            ..strokeWidth = reference ? 4 : 3
            ..style = PaintingStyle.stroke,
        );
      }
      for (final p in coords) {
        final position = project(p);
        if (reference) {
          canvas.drawRect(
            Rect.fromCenter(center: position, width: 12, height: 12),
            Paint()..color = color,
          );
        } else {
          canvas.drawCircle(position, isPoint ? 8 : 4, Paint()..color = color);
          canvas.drawCircle(
            position,
            isPoint ? 8 : 4,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }

    if (target != null) {
      for (final part in target!.parts) {
        geometry(part, type, const Color(0xffdf8a1b), reference: true);
      }
    }
    geometry(
      points,
      type,
      dark ? const Color(0xff67dbed) : const Color(0xff006b94),
    );
    if (target != null && type == AnswerType.point && points.isNotEmpty) {
      canvas.drawLine(
        project(points.first),
        project(target!.points.first),
        Paint()
          ..color = const Color(0xffdf8a1b)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
