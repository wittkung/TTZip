// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 2D Pareto non-dominated frontier and Andrew's Monotone Chain upper convex hull algorithms.

use std::ffi::CStr;
use std::os::raw::c_char;

const EPSILON: f64 = 1e-7;

/// 2D Pareto and Upper Convex Hull point representation for compression codecs.
#[derive(Debug, Clone, PartialEq)]
pub struct ParetoCodecPoint {
    pub codec_name: String,
    pub compression_ratio: f64,
    pub speed_mb_s: f64,
    pub memory_mb: f64,
    pub pareto_rank: u32,
    pub is_pareto_optimal: bool,
    pub is_on_convex_hull: bool,
}

impl ParetoCodecPoint {
    pub fn new(
        codec_name: impl Into<String>,
        compression_ratio: f64,
        speed_mb_s: f64,
        memory_mb: f64,
    ) -> Self {
        Self {
            codec_name: codec_name.into(),
            compression_ratio,
            speed_mb_s,
            memory_mb,
            pareto_rank: 1,
            is_pareto_optimal: false,
            is_on_convex_hull: false,
        }
    }
}

/// Raw C-ABI compatible Pareto codec point for zero-copy FFI bridging.
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TTZipParetoCodecPointRaw {
    pub codec_name: [c_char; 64],
    pub compression_ratio: f64,
    pub speed_mb_s: f64,
    pub memory_mb: f64,
    pub pareto_rank: u32,
    pub is_pareto_optimal: bool,
    pub is_on_convex_hull: bool,
}

impl TTZipParetoCodecPointRaw {
    pub fn new(codec_name_str: &str, compression_ratio: f64, speed_mb_s: f64, memory_mb: f64) -> Self {
        let mut name_buf = [0 as c_char; 64];
        let bytes = codec_name_str.as_bytes();
        let copy_len = bytes.len().min(63);
        for i in 0..copy_len {
            name_buf[i] = bytes[i] as c_char;
        }
        Self {
            codec_name: name_buf,
            compression_ratio,
            speed_mb_s,
            memory_mb,
            pareto_rank: 1,
            is_pareto_optimal: false,
            is_on_convex_hull: false,
        }
    }

    pub fn name_as_str(&self) -> &str {
        unsafe {
            CStr::from_ptr(self.codec_name.as_ptr())
                .to_str()
                .unwrap_or("")
        }
    }
}

/// Raw C-ABI compatible Pareto point structure for high-performance zero-copy bridging.
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ParetoPointRaw {
    pub tag: u64,
    pub throughput_mbs: f64,
    pub space_savings_pct: f64,
    pub pareto_rank: u32,
    pub is_pareto_optimal: bool,
    pub is_on_convex_envelope: bool,
}

impl ParetoPointRaw {
    pub fn new(tag: u64, throughput_mbs: f64, space_savings_pct: f64) -> Self {
        Self {
            tag,
            throughput_mbs,
            space_savings_pct,
            pareto_rank: 1,
            is_pareto_optimal: false,
            is_on_convex_envelope: false,
        }
    }
}

/// Calculates 2D Pareto frontier and Andrew's Monotone Chain Upper Convex Hull on `ParetoCodecPoint` slice.
pub fn calculate_pareto_frontier(points: &mut [ParetoCodecPoint]) {
    if points.is_empty() {
        return;
    }

    if points.len() == 1 {
        points[0].pareto_rank = 1;
        points[0].is_pareto_optimal = true;
        points[0].is_on_convex_hull = true;
        return;
    }

    // 1. Sort points by speed descending (x desc), compression ratio descending (y desc)
    points.sort_by(|a, b| {
        let diff_x = a.speed_mb_s - b.speed_mb_s;
        if diff_x.abs() > EPSILON {
            b.speed_mb_s
                .partial_cmp(&a.speed_mb_s)
                .unwrap_or(std::cmp::Ordering::Equal)
        } else {
            b.compression_ratio
                .partial_cmp(&a.compression_ratio)
                .unwrap_or(std::cmp::Ordering::Equal)
        }
    });

    // 2. Multi-tier Pareto Rank calculation via Dilworth's Theorem & Patience Sorting (O(N log K))
    let mut target_tiers: Vec<f64> = Vec::new();

    for pt in points.iter_mut() {
        let cur_y = pt.compression_ratio;

        let mut left = 0;
        let mut right = target_tiers.len();
        while left < right {
            let mid = (left + right) / 2;
            if cur_y > target_tiers[mid] + EPSILON {
                right = mid;
            } else {
                left = mid + 1;
            }
        }

        if left < target_tiers.len() {
            pt.pareto_rank = (left + 1) as u32;
            target_tiers[left] = cur_y;
        } else {
            target_tiers.push(cur_y);
            pt.pareto_rank = target_tiers.len() as u32;
        }

        pt.is_pareto_optimal = pt.pareto_rank == 1;
        pt.is_on_convex_hull = false;
    }

    // 3. Extract Rank 1 frontier indices and sort by speed ascending (x asc)
    let mut frontier_indices: Vec<usize> = points
        .iter()
        .enumerate()
        .filter(|(_, p)| p.is_pareto_optimal)
        .map(|(idx, _)| idx)
        .collect();

    frontier_indices.sort_by(|&i, &j| {
        let diff_x = points[i].speed_mb_s - points[j].speed_mb_s;
        if diff_x.abs() > EPSILON {
            points[i]
                .speed_mb_s
                .partial_cmp(&points[j].speed_mb_s)
                .unwrap_or(std::cmp::Ordering::Equal)
        } else {
            points[i]
                .compression_ratio
                .partial_cmp(&points[j].compression_ratio)
                .unwrap_or(std::cmp::Ordering::Equal)
        }
    });

    if frontier_indices.len() <= 2 {
        for &idx in &frontier_indices {
            points[idx].is_on_convex_hull = true;
        }
        return;
    }

    // 4. Compute 2D Upper Convex Hull via Andrew's Monotone Chain (O(M log M))
    let mut upper_hull_indices: Vec<usize> = Vec::with_capacity(frontier_indices.len());

    for &idx in &frontier_indices {
        let p = &points[idx];
        while upper_hull_indices.len() >= 2 {
            let a = &points[upper_hull_indices[upper_hull_indices.len() - 2]];
            let b = &points[upper_hull_indices[upper_hull_indices.len() - 1]];

            // 2D Cross Product: (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
            let cross_product = (b.speed_mb_s - a.speed_mb_s) * (p.compression_ratio - a.compression_ratio)
                - (b.compression_ratio - a.compression_ratio) * (p.speed_mb_s - a.speed_mb_s);

            // If cross_product >= -EPSILON (concave corner or collinear), pop redundant interior vertex
            if cross_product >= -EPSILON {
                upper_hull_indices.pop();
            } else {
                break;
            }
        }
        upper_hull_indices.push(idx);
    }

    for &idx in &upper_hull_indices {
        points[idx].is_on_convex_hull = true;
    }
}

/// Calculates 2D Pareto frontier and Andrew's Monotone Chain Upper Convex Hull on raw C-ABI codec points in-place.
pub fn compute_codec_pareto_frontier_raw(points: &mut [TTZipParetoCodecPointRaw]) {
    if points.is_empty() {
        return;
    }

    if points.len() == 1 {
        points[0].pareto_rank = 1;
        points[0].is_pareto_optimal = true;
        points[0].is_on_convex_hull = true;
        return;
    }

    // 1. Sort points by speed descending (x desc), compression ratio descending (y desc)
    points.sort_by(|a, b| {
        let diff_x = a.speed_mb_s - b.speed_mb_s;
        if diff_x.abs() > EPSILON {
            b.speed_mb_s
                .partial_cmp(&a.speed_mb_s)
                .unwrap_or(std::cmp::Ordering::Equal)
        } else {
            b.compression_ratio
                .partial_cmp(&a.compression_ratio)
                .unwrap_or(std::cmp::Ordering::Equal)
        }
    });

    // 2. Multi-tier Pareto Rank calculation via Dilworth's Theorem & Patience Sorting (O(N log K))
    let mut target_tiers: Vec<f64> = Vec::new();

    for pt in points.iter_mut() {
        let cur_y = pt.compression_ratio;

        let mut left = 0;
        let mut right = target_tiers.len();
        while left < right {
            let mid = (left + right) / 2;
            if cur_y > target_tiers[mid] + EPSILON {
                right = mid;
            } else {
                left = mid + 1;
            }
        }

        if left < target_tiers.len() {
            pt.pareto_rank = (left + 1) as u32;
            target_tiers[left] = cur_y;
        } else {
            target_tiers.push(cur_y);
            pt.pareto_rank = target_tiers.len() as u32;
        }

        pt.is_pareto_optimal = pt.pareto_rank == 1;
        pt.is_on_convex_hull = false;
    }

    // 3. Extract Rank 1 frontier indices and sort by speed ascending (x asc)
    let mut frontier_indices: Vec<usize> = points
        .iter()
        .enumerate()
        .filter(|(_, p)| p.is_pareto_optimal)
        .map(|(idx, _)| idx)
        .collect();

    frontier_indices.sort_by(|&i, &j| {
        let diff_x = points[i].speed_mb_s - points[j].speed_mb_s;
        if diff_x.abs() > EPSILON {
            points[i]
                .speed_mb_s
                .partial_cmp(&points[j].speed_mb_s)
                .unwrap_or(std::cmp::Ordering::Equal)
        } else {
            points[i]
                .compression_ratio
                .partial_cmp(&points[j].compression_ratio)
                .unwrap_or(std::cmp::Ordering::Equal)
        }
    });

    if frontier_indices.len() <= 2 {
        for &idx in &frontier_indices {
            points[idx].is_on_convex_hull = true;
        }
        return;
    }

    // 4. Compute 2D Upper Convex Hull via Andrew's Monotone Chain (O(M log M))
    let mut upper_hull_indices: Vec<usize> = Vec::with_capacity(frontier_indices.len());

    for &idx in &frontier_indices {
        let p = &points[idx];
        while upper_hull_indices.len() >= 2 {
            let a = &points[upper_hull_indices[upper_hull_indices.len() - 2]];
            let b = &points[upper_hull_indices[upper_hull_indices.len() - 1]];

            let cross_product = (b.speed_mb_s - a.speed_mb_s) * (p.compression_ratio - a.compression_ratio)
                - (b.compression_ratio - a.compression_ratio) * (p.speed_mb_s - a.speed_mb_s);

            if cross_product >= -EPSILON {
                upper_hull_indices.pop();
            } else {
                break;
            }
        }
        upper_hull_indices.push(idx);
    }

    for &idx in &upper_hull_indices {
        points[idx].is_on_convex_hull = true;
    }
}

/// Computes multi-tier Pareto ranks ($O(N \log K)$ via Dilworth/Patience sorting)
/// and 2D Upper Convex Hull ($O(M \log M)$ via Andrew's Monotone Chain) on `ParetoPointRaw` in-place.
pub fn compute_pareto_frontier_raw(points: &mut [ParetoPointRaw]) {
    if points.is_empty() {
        return;
    }

    if points.len() == 1 {
        points[0].pareto_rank = 1;
        points[0].is_pareto_optimal = true;
        points[0].is_on_convex_envelope = true;
        return;
    }

    // 1. Sort points by throughput descending (x desc), space savings descending (y desc)
    points.sort_by(|a, b| {
        let diff_x = a.throughput_mbs - b.throughput_mbs;
        if diff_x.abs() > EPSILON {
            b.throughput_mbs
                .partial_cmp(&a.throughput_mbs)
                .unwrap_or(std::cmp::Ordering::Equal)
        } else {
            b.space_savings_pct
                .partial_cmp(&a.space_savings_pct)
                .unwrap_or(std::cmp::Ordering::Equal)
        }
    });

    // 2. Multi-tier Pareto Rank calculation via Dilworth's Theorem & Patience Sorting (O(N log K))
    let mut target_tiers: Vec<f64> = Vec::new();

    for pt in points.iter_mut() {
        let cur_y = pt.space_savings_pct;

        let mut left = 0;
        let mut right = target_tiers.len();
        while left < right {
            let mid = (left + right) / 2;
            if cur_y > target_tiers[mid] + EPSILON {
                right = mid;
            } else {
                left = mid + 1;
            }
        }

        if left < target_tiers.len() {
            pt.pareto_rank = (left + 1) as u32;
            target_tiers[left] = cur_y;
        } else {
            target_tiers.push(cur_y);
            pt.pareto_rank = target_tiers.len() as u32;
        }

        pt.is_pareto_optimal = pt.pareto_rank == 1;
        pt.is_on_convex_envelope = false;
    }

    // 3. Extract Rank 1 frontier indices and sort by throughput ascending (x asc)
    let mut frontier_indices: Vec<usize> = points
        .iter()
        .enumerate()
        .filter(|(_, p)| p.is_pareto_optimal)
        .map(|(idx, _)| idx)
        .collect();

    frontier_indices.sort_by(|&i, &j| {
        let diff_x = points[i].throughput_mbs - points[j].throughput_mbs;
        if diff_x.abs() > EPSILON {
            points[i]
                .throughput_mbs
                .partial_cmp(&points[j].throughput_mbs)
                .unwrap_or(std::cmp::Ordering::Equal)
        } else {
            points[i]
                .space_savings_pct
                .partial_cmp(&points[j].space_savings_pct)
                .unwrap_or(std::cmp::Ordering::Equal)
        }
    });

    if frontier_indices.len() <= 2 {
        for &idx in &frontier_indices {
            points[idx].is_on_convex_envelope = true;
        }
        return;
    }

    // 4. Compute 2D Upper Convex Hull via Andrew's Monotone Chain (O(M log M))
    let mut upper_hull_indices: Vec<usize> = Vec::with_capacity(frontier_indices.len());

    for &idx in &frontier_indices {
        let p = &points[idx];
        while upper_hull_indices.len() >= 2 {
            let a = &points[upper_hull_indices[upper_hull_indices.len() - 2]];
            let b = &points[upper_hull_indices[upper_hull_indices.len() - 1]];

            let cross_product = (b.throughput_mbs - a.throughput_mbs)
                * (p.space_savings_pct - a.space_savings_pct)
                - (b.space_savings_pct - a.space_savings_pct)
                    * (p.throughput_mbs - a.throughput_mbs);

            if cross_product >= -EPSILON {
                upper_hull_indices.pop();
            } else {
                break;
            }
        }
        upper_hull_indices.push(idx);
    }

    for &idx in &upper_hull_indices {
        points[idx].is_on_convex_envelope = true;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pareto_empty_and_single() {
        let mut empty: Vec<ParetoPointRaw> = vec![];
        compute_pareto_frontier_raw(&mut empty);
        assert!(empty.is_empty());

        let mut single = vec![ParetoPointRaw::new(1, 100.0, 50.0)];
        compute_pareto_frontier_raw(&mut single);
        assert_eq!(single[0].pareto_rank, 1);
        assert!(single[0].is_pareto_optimal);
        assert!(single[0].is_on_convex_envelope);
    }

    #[test]
    fn test_pareto_dominated_points() {
        let mut points = vec![
            ParetoPointRaw::new(1, 100.0, 50.0), // Dominated by point 2 (200, 60)
            ParetoPointRaw::new(2, 200.0, 60.0), // Dominant
            ParetoPointRaw::new(3, 50.0, 80.0),  // Dominant (higher savings, lower speed)
            ParetoPointRaw::new(4, 30.0, 40.0),  // Dominated by all
        ];

        compute_pareto_frontier_raw(&mut points);

        let p2 = points.iter().find(|p| p.tag == 2).unwrap();
        let p3 = points.iter().find(|p| p.tag == 3).unwrap();
        let p1 = points.iter().find(|p| p.tag == 1).unwrap();
        let p4 = points.iter().find(|p| p.tag == 4).unwrap();

        assert_eq!(p2.pareto_rank, 1);
        assert!(p2.is_pareto_optimal);

        assert_eq!(p3.pareto_rank, 1);
        assert!(p3.is_pareto_optimal);

        assert!(p1.pareto_rank > 1);
        assert!(!p1.is_pareto_optimal);

        assert!(p4.pareto_rank > 1);
        assert!(!p4.is_pareto_optimal);
    }

    #[test]
    fn test_upper_convex_hull_monotone_chain() {
        let mut points = vec![
            ParetoPointRaw::new(1, 10.0, 90.0),  // extreme point A
            ParetoPointRaw::new(2, 50.0, 50.0),  // concave point below line AB -> not on hull
            ParetoPointRaw::new(3, 100.0, 10.0), // extreme point B
        ];

        compute_pareto_frontier_raw(&mut points);

        let p1 = points.iter().find(|p| p.tag == 1).unwrap();
        let p2 = points.iter().find(|p| p.tag == 2).unwrap();
        let p3 = points.iter().find(|p| p.tag == 3).unwrap();

        assert!(p1.is_pareto_optimal && p1.is_on_convex_envelope);
        assert!(p3.is_pareto_optimal && p3.is_on_convex_envelope);
        assert!(p2.is_pareto_optimal);
        assert!(!p2.is_on_convex_envelope); // Concave vertex correctly excluded from upper envelope
    }

    #[test]
    fn test_codec_pareto_frontier_calculation() {
        let mut points = vec![
            ParetoCodecPoint::new("Snappy", 0.55, 2500.0, 16.0),
            ParetoCodecPoint::new("Zstd L1", 0.65, 1200.0, 32.0),
            ParetoCodecPoint::new("Zstd L3", 0.70, 800.0, 64.0),
            ParetoCodecPoint::new("LZMA2 L9", 0.82, 50.0, 128.0),
            ParetoCodecPoint::new("SlowDeflate", 0.60, 200.0, 32.0), // Dominated by Zstd L1 & L3
        ];

        calculate_pareto_frontier(&mut points);

        let snappy = points.iter().find(|p| p.codec_name == "Snappy").unwrap();
        let zstd1 = points.iter().find(|p| p.codec_name == "Zstd L1").unwrap();
        let zstd3 = points.iter().find(|p| p.codec_name == "Zstd L3").unwrap();
        let lzma9 = points.iter().find(|p| p.codec_name == "LZMA2 L9").unwrap();
        let slow = points.iter().find(|p| p.codec_name == "SlowDeflate").unwrap();

        assert!(snappy.is_pareto_optimal);
        assert!(zstd1.is_pareto_optimal);
        assert!(zstd3.is_pareto_optimal);
        assert!(lzma9.is_pareto_optimal);

        assert!(!slow.is_pareto_optimal);
        assert!(slow.pareto_rank > 1);
        assert!(!slow.is_on_convex_hull);
    }

    #[test]
    fn test_codec_raw_ffi_monotone_chain() {
        let mut raw_points = [
            TTZipParetoCodecPointRaw::new("FastLZ", 0.50, 3000.0, 8.0),
            TTZipParetoCodecPointRaw::new("MidCodec", 0.60, 1000.0, 16.0),
            TTZipParetoCodecPointRaw::new("UltraCodec", 0.85, 20.0, 256.0),
        ];

        compute_codec_pareto_frontier_raw(&mut raw_points);

        for pt in &raw_points {
            assert!(pt.is_pareto_optimal);
            assert_eq!(pt.pareto_rank, 1);
        }

        let fast = raw_points.iter().find(|p| p.name_as_str() == "FastLZ").unwrap();
        let ultra = raw_points.iter().find(|p| p.name_as_str() == "UltraCodec").unwrap();
        assert!(fast.is_on_convex_hull);
        assert!(ultra.is_on_convex_hull);
    }
}
