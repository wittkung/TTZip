// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Fritsch-Carlson Monotone Cubic Hermite Spline Interpolation.
//!
//! Generates strictly monotonic C1-continuous smooth interpolation curves and
//! converts them directly into exact SVG cubic Bézier path commands without oscillations.

const EPSILON: f64 = 1e-9;

/// 2D coordinate point for spline interpolation.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct SplinePoint {
    pub x: f64,
    pub y: f64,
}

impl SplinePoint {
    pub fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }
}

/// Fritsch-Carlson Monotone Cubic Hermite Spline Curve.
#[derive(Debug, Clone, PartialEq)]
pub struct FritschCarlsonSpline {
    points: Vec<SplinePoint>,
    tangents: Vec<f64>,
}

impl FritschCarlsonSpline {
    /// Builds a Fritsch-Carlson spline from a sequence of 2D points.
    /// Sorts points by X ascending and eliminates duplicate X coordinates.
    pub fn new(mut input_points: Vec<SplinePoint>) -> Option<Self> {
        if input_points.len() < 2 {
            return None;
        }

        // 1. Sort by X ascending
        input_points.sort_by(|a, b| a.x.partial_cmp(&b.x).unwrap_or(std::cmp::Ordering::Equal));

        // 2. Filter out duplicate X points
        let mut points: Vec<SplinePoint> = Vec::with_capacity(input_points.len());
        for p in input_points {
            if let Some(last) = points.last() {
                if (p.x - last.x).abs() <= EPSILON {
                    continue;
                }
            }
            points.push(p);
        }

        let n = points.len();
        if n < 2 {
            return None;
        }

        // 3. Compute secant slopes: delta_k = (y_{k+1} - y_k) / (x_{k+1} - x_k)
        let mut deltas = Vec::with_capacity(n - 1);
        for k in 0..(n - 1) {
            let dx = points[k + 1].x - points[k].x;
            let dy = points[k + 1].y - points[k].y;
            deltas.push(dy / dx);
        }

        // 4. Initial tangents: central differences for interior, one-sided for endpoints
        let mut tangents = vec![0.0; n];
        tangents[0] = deltas[0];
        tangents[n - 1] = deltas[n - 2];
        for k in 1..(n - 1) {
            tangents[k] = (deltas[k - 1] + deltas[k]) * 0.5;
        }

        // 5. Fritsch-Carlson Monotonicity Adjustment Pass
        for k in 0..(n - 1) {
            let delta = deltas[k];
            if delta.abs() < EPSILON {
                tangents[k] = 0.0;
                tangents[k + 1] = 0.0;
                continue;
            }

            let alpha = tangents[k] / delta;
            let beta = tangents[k + 1] / delta;

            if alpha < 0.0 {
                tangents[k] = 0.0;
            }
            if beta < 0.0 {
                tangents[k + 1] = 0.0;
            }

            // Circle condition check: alpha^2 + beta^2 <= 9
            let hyp = alpha * alpha + beta * beta;
            if hyp > 9.0 {
                let tau = 3.0 / hyp.sqrt();
                tangents[k] = tau * alpha * delta;
                tangents[k + 1] = tau * beta * delta;
            }
        }

        Some(Self { points, tangents })
    }

    /// Evaluates interpolated Y value for any X inside or near the domain.
    pub fn interpolate(&self, x: f64) -> f64 {
        let n = self.points.len();
        if x <= self.points[0].x {
            return self.points[0].y;
        }
        if x >= self.points[n - 1].x {
            return self.points[n - 1].y;
        }

        // Binary search for interval
        let mut low = 0;
        let mut high = n - 1;
        while low < high - 1 {
            let mid = (low + high) / 2;
            if self.points[mid].x <= x {
                low = mid;
            } else {
                high = mid;
            }
        }

        let k = low;
        let p0 = &self.points[k];
        let p1 = &self.points[k + 1];
        let h = p1.x - p0.x;
        let t = (x - p0.x) / h;
        let t2 = t * t;
        let t3 = t2 * t;

        // Hermite basis functions
        let h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
        let h10 = t3 - 2.0 * t2 + t;
        let h01 = -2.0 * t3 + 3.0 * t2;
        let h11 = t3 - t2;

        let d0 = self.tangents[k];
        let d1 = self.tangents[k + 1];

        h00 * p0.y + h10 * h * d0 + h01 * p1.y + h11 * h * d1
    }

    /// Generates exact SVG path string using cubic Bézier segments (`C cp1_x,cp1_y cp2_x,cp2_y p2_x,p2_y`).
    /// `map_coord` maps from data space `(x, y)` to SVG pixel canvas coordinates `(px, py)`.
    pub fn to_svg_bezier_path<F>(&self, map_coord: F) -> String
    where
        F: Fn(f64, f64) -> (f64, f64),
    {
        let n = self.points.len();
        if n < 2 {
            return String::new();
        }

        let (x0, y0) = map_coord(self.points[0].x, self.points[0].y);
        let mut path = format!("M {:.2},{:.2}", x0, y0);

        for k in 0..(n - 1) {
            let p0 = &self.points[k];
            let p1 = &self.points[k + 1];
            let h = p1.x - p0.x;

            let cp1_x = p0.x + h / 3.0;
            let cp1_y = p0.y + (h / 3.0) * self.tangents[k];

            let cp2_x = p1.x - h / 3.0;
            let cp2_y = p1.y - (h / 3.0) * self.tangents[k + 1];

            let (p1_px, p1_py) = map_coord(p1.x, p1.y);
            let (cp1_px, cp1_py) = map_coord(cp1_x, cp1_y);
            let (cp2_px, cp2_py) = map_coord(cp2_x, cp2_y);

            path.push_str(&format!(
                " C {:.2},{:.2} {:.2},{:.2} {:.2},{:.2}",
                cp1_px, cp1_py, cp2_px, cp2_py, p1_px, p1_py
            ));
        }

        path
    }

    pub fn points(&self) -> &[SplinePoint] {
        &self.points
    }
}
