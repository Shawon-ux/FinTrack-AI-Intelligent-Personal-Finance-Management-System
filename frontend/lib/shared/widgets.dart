import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme.dart';

const catIcon = {
  'Food': '🍔', 'Transport': '🚕', 'Bills': '💡', 'Shopping': '🛍', 'Entertainment': '🎬', 'Health': '💊',
  'Education': '📚', 'Personal Care': '💇', 'Other': '•', 'Income': '💰', 'Transfer': '🔁',
};
const expenseCats = ['Food', 'Transport', 'Bills', 'Shopping', 'Entertainment', 'Health', 'Education', 'Personal Care', 'Other'];

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? C.mut;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: .15), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: 11, color: c)),
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton(this.label, this.onTap, {super.key, this.busy = false});
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .5 : 1,
        // own Material so the gradient Ink paints locally (not under translucent parents)
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: BoxDecoration(gradient: C.grad, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: C.p.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 6))]),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: busy ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Center(
                    child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: busy
                      ? const SizedBox(key: ValueKey('b'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : Text(label, key: ValueKey(label), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                )),
              ),
            ),
          ),
        ),
      );
}

class Pad extends StatelessWidget {
  const Pad({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(14), child: child);
}

class Bar extends StatelessWidget {
  const Bar(this.pct, {super.key, this.goal = false});
  final double pct;
  /// goal: reaching 100% is good (green), not an overspend (red).
  final bool goal;
  @override
  Widget build(BuildContext context) {
    final col = goal ? (pct >= 100 ? C.ok : C.p) : (pct >= 100 ? C.bad : pct >= 75 ? C.warn : C.p);
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: C.card2, color: col),
    );
  }
}

class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.values, required this.labels, this.height = 130});
  final List<double> values;
  final List<String> labels;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _BarPainter(values, labels)));
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.v, this.l);
  final List<double> v;
  final List<String> l;
  @override
  void paint(Canvas c, Size s) {
    final mx = v.fold<double>(1, math.max), n = v.length, bw = s.width / n, h = s.height - 18;
    for (var i = 0; i < n; i++) {
      final bh = math.max(v[i] / mx * h, 3.0);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(i * bw + bw * .2, h - bh, bw * .6, bh), const Radius.circular(5));
      c.drawRRect(r, Paint()..shader = C.grad.createShader(r.outerRect));
      final tp = TextPainter(text: TextSpan(text: l[i], style: TextStyle(color: C.mut, fontSize: 10)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(i * bw + bw / 2 - tp.width / 2, h + 4));
    }
  }

  @override
  bool shouldRepaint(_BarPainter o) => o.v != v;
}

class Donut extends StatelessWidget {
  const Donut(this.items, {super.key});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) {
    final tot = items.fold<double>(0, (a, e) => a + (e['amount'] as num)) == 0 ? 1.0 : items.fold<double>(0, (a, e) => a + (e['amount'] as num));
    final shown = items.take(7).toList();
    return Row(children: [
      SizedBox(width: 118, height: 118, child: CustomPaint(painter: _DonutPainter(shown.map((e) => (e['amount'] as num).toDouble()).toList(), tot))),
      const SizedBox(width: 12),
      Expanded(
        child: Column(children: [
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: C.palette[i % 7], borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(child: Text('${shown[i]['name']}', style: const TextStyle(fontSize: 12))),
                Text('${((shown[i]['amount'] as num) / tot * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            )
        ]),
      ),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.v, this.tot);
  final List<double> v;
  final double tot;
  @override
  void paint(Canvas c, Size s) {
    final rect = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 10);
    var a = -math.pi / 2;
    for (var i = 0; i < v.length; i++) {
      final sw = v[i] / tot * 2 * math.pi;
      c.drawArc(rect, a, math.max(sw - .03, .01), false, Paint()..style = PaintingStyle.stroke..strokeWidth = 18..color = C.palette[i % 7]);
      a += sw;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.v != v;
}

class LineChartW extends StatelessWidget {
  const LineChartW({super.key, required this.actual, required this.forecast});
  final List<double> actual, forecast;
  @override
  Widget build(BuildContext context) => SizedBox(height: 120, width: double.infinity, child: CustomPaint(painter: _LinePainter(actual, forecast)));
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.a, this.f);
  final List<double> a, f;
  @override
  void paint(Canvas c, Size s) {
    final all = [...a, ...f];
    if (all.length < 2) return;
    final mx = all.fold<double>(1, math.max), h = s.height - 16, n = all.length;
    Offset pt(double v, int i) => Offset(i / (n - 1) * s.width, h - v / mx * h);
    final pa = Path()..moveTo(pt(a[0], 0).dx, pt(a[0], 0).dy);
    for (var i = 1; i < a.length; i++) {
      pa.lineTo(pt(a[i], i).dx, pt(a[i], i).dy);
    }
    c.drawPath(pa, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = C.p2);
    final start = pt(a.last, a.length - 1);
    for (var i = 0; i < f.length; i++) {
      final p0 = i == 0 ? start : pt(f[i - 1], a.length + i - 1), p1 = pt(f[i], a.length + i);
      final d = (p1 - p0), len = d.distance;
      for (double t = 0; t < len; t += 7) {
        c.drawLine(p0 + d * (t / len), p0 + d * (math.min(t + 4, len) / len), Paint()..strokeWidth = 2..color = const Color(0xFFB86BFF));
      }
    }
    void label(String t, double x) {
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: C.mut, fontSize: 10)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(x, h + 2));
    }
    label('recent', 0);
    label('forecast 30d', s.width - 62);
  }

  @override
  bool shouldRepaint(_LinePainter o) => true;
}

class ScoreRing extends StatelessWidget {
  const ScoreRing(this.score, {super.key});
  final int score;
  @override
  Widget build(BuildContext context) {
    final col = score >= 70 ? C.ok : score >= 45 ? C.warn : C.bad;
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(width: 78, height: 78, child: CircularProgressIndicator(value: score / 100, strokeWidth: 8, backgroundColor: C.line, color: col, strokeCap: StrokeCap.round)),
        Text('$score', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

void snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

final _avatarBytes = <String, Uint8List>{};

/// Profile picture (stored as a data URL) with an initial-letter fallback.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.dataUrl, this.radius = 24});
  final String name;
  final String? dataUrl;
  final double radius;

  Uint8List? get _bytes {
    final d = dataUrl;
    if (d == null || d.isEmpty || !d.contains(',')) return null;
    return _avatarBytes.putIfAbsent(d, () {
      try {
        return base64Decode(d.substring(d.indexOf(',') + 1));
      } catch (_) {
        return Uint8List(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    final ok = b != null && b.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: C.p,
      backgroundImage: ok ? MemoryImage(b) : null,
      child: ok ? null : Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(fontSize: radius * .9, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}
