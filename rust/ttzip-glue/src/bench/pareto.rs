// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 2D Pareto non-dominated frontier and Monotone Chain upper convex hull algorithms.

const EPSILON: f64 = 1e-7;

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

/// Computes multi-tier Pareto ranks ($O(N \log K)$ via Dilworth/Patience sorting)
/// and 2D Upper Convex Hull ($O(M \log M)$ via Andrew's Monotone Chain) in-place.
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
            b.throughput_mbs.partial_cmp(&a.throughput_mbs).unwrap_or(std::cmp::Ordering::Equal)
        } else {
            b.space_savings_pct.partial_cmp(&a.space_savings_pct).unwrap_or(std::cmp::Ordering::Equal)
        }
    });

    // 2. Multi-tier Pareto Rank calculation via Dilworth's Theorem & Patience Sorting (O(N log K))
    // target_tiers[j] tracks the current maximum y coordinate (space savings) for tier j
    let mut target_tiers: Vec<f64> = Vec::new();

    for pt in points.iter_mut() {
        let cur_y = pt.space_savings_pct;

        // Binary search for smallest tier index j where cur_y > target_tiers[j] + EPSILON
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
            points[i].throughput_mbs.partial_cmp(&points[j].throughput_mbs).unwrap_or(std::cmp::Ordering::Equal)
        } else {
            points[i].space_savings_pct.partial_cmp(&points[j].space_savings_pct).unwrap_or(std::cmp::Ordering::Equal)
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

            // 2D Cross Product: (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
            let cross_product = (b.throughput_mbs - a.throughput_mbs) * (p.space_savings_pct - a.space_savings_pct)
                - (b.space_savings_pct - a.space_savings_pct) * (p.throughput_mbs - a.throughput_mbs);

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
            ParetoPointRaw::new(1, 10.0, 90.0), // extreme point A
            ParetoPointRaw::new(2, 50.0, 50.0), // concave point below line AB -> not on hull
            ParetoPointRaw::new(3, 100.0, 10.0),// extreme point B
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
}
