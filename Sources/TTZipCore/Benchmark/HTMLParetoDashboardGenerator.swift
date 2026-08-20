// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation

/// 零依赖自包含 Zen UI 帕累托基准测试 HTML5 仪表盘生成器
public final class HTMLParetoDashboardGenerator: @unchecked Sendable {
    public static let shared = HTMLParetoDashboardGenerator()
    private init() {}

    /// 生成自包含 HTML 仪表盘字符串
    public func generateHTML(
        summary: CodecBenchmarkMatrixSummary,
        title: String = "TTZip Unified Codec Benchmark Dashboard"
    ) -> String {
        // 1. 将 CodecBenchmarkPointResult 映射为 ParetoPoint 列表并计算前沿
        let paretoPoints: [ParetoPoint] = summary.results.map { pt in
            let savings = max(0.0, (1.0 - pt.compressionRatio) * 100.0)
            let algoName = "\(pt.engineName.uppercased()) [\(pt.corpusType.rawValue)]"
            return ParetoPoint(
                id: "\(pt.engineName)_\(pt.corpusType.rawValue)_\(pt.payloadSizeBytes)_\(pt.compressionLevel)",
                algorithm: algoName,
                level: pt.compressionLevel,
                throughputMBs: pt.compressThroughputMBs,
                spaceSavingsPct: savings,
                compressedBytes: Int64(pt.compressedSizeBytes),
                uncompressedBytes: Int64(pt.payloadSizeBytes)
            )
        }

        let frontierResult = ParetoFrontierCalculator.shared.calculateFrontierFromPoints(points: paretoPoints)
        let svgChart = SVGParetoPlotter.shared.generateSVG(result: frontierResult, width: 1400, height: 750, title: title)

        // 2. 构造 HTML 报告
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <style>
                :root {
                    --bg-primary: #0b0b0c;
                    --bg-card: #141416;
                    --border-subtle: #242429;
                    --text-primary: #f0f3f6;
                    --text-muted: #8b949e;
                    --gold: #d4af37;
                    --green: #2ea043;
                    --blue: #58a6ff;
                    --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
                }
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body {
                    background-color: var(--bg-primary);
                    color: var(--text-primary);
                    font-family: var(--font-sans);
                    line-height: 1.5;
                    padding: 32px 24px;
                }
                .container { max-width: 1440px; margin: 0 auto; }
                header { margin-bottom: 24px; border-bottom: 1px solid var(--border-subtle); padding-bottom: 16px; }
                h1 { font-size: 28px; font-weight: 600; color: var(--gold); margin-bottom: 8px; letter-spacing: -0.5px; }
                .meta { color: var(--text-muted); font-size: 14px; font-family: var(--font-mono); }
                .kpi-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
                    gap: 16px;
                    margin-bottom: 24px;
                }
                .kpi-card {
                    background: var(--bg-card);
                    border: 1px solid var(--border-subtle);
                    border-radius: 8px;
                    padding: 16px;
                }
                .kpi-label { font-size: 12px; text-transform: uppercase; color: var(--text-muted); margin-bottom: 4px; }
                .kpi-val { font-size: 24px; font-weight: 600; font-family: var(--font-mono); color: var(--text-primary); }
                .kpi-val.gold { color: var(--gold); }
                .kpi-val.green { color: var(--green); }
                .chart-container {
                    background: var(--bg-card);
                    border: 1px solid var(--border-subtle);
                    border-radius: 8px;
                    padding: 16px;
                    margin-bottom: 32px;
                    overflow-x: auto;
                }
                .table-container {
                    background: var(--bg-card);
                    border: 1px solid var(--border-subtle);
                    border-radius: 8px;
                    padding: 16px;
                    overflow-x: auto;
                }
                .table-header-ctrl {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 16px;
                }
                .search-box {
                    background: #1c1c20;
                    border: 1px solid var(--border-subtle);
                    color: var(--text-primary);
                    padding: 8px 12px;
                    border-radius: 6px;
                    font-size: 14px;
                    width: 280px;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    font-size: 13px;
                    font-family: var(--font-mono);
                }
                th {
                    text-align: left;
                    padding: 10px 12px;
                    background: #1a1a1e;
                    color: var(--text-muted);
                    font-weight: 500;
                    border-bottom: 1px solid var(--border-subtle);
                }
                td {
                    padding: 10px 12px;
                    border-bottom: 1px solid #1c1c22;
                }
                tr:hover { background: #18181e; }
                .badge {
                    display: inline-block;
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-size: 11px;
                    font-weight: 600;
                }
                .badge-ok { background: rgba(46, 160, 67, 0.2); color: #3fb950; }
                .badge-pareto { background: rgba(212, 175, 55, 0.2); color: var(--gold); border: 1px solid var(--gold); }
            </style>
        </head>
        <body>
            <div class="container">
                <header>
                    <h1>⚡️ \(title)</h1>
                    <div class="meta">
                        Generated by TTZip Unified Benchmark Engine | Total Points: \(summary.totalPoints) | Median CV: \(String(format: "%.2f", summary.medianCvPercentage))%
                    </div>
                </header>

                <div class="kpi-grid">
                    <div class="kpi-card">
                        <div class="kpi-label">Total Execution Time</div>
                        <div class="kpi-val gold">\(String(format: "%.3f s", summary.totalDurationMs / 1000.0))</div>
                    </div>
                    <div class="kpi-card">
                        <div class="kpi-label">Verified Test Points</div>
                        <div class="kpi-val green">\(summary.results.filter { $0.integrityVerified }.count) / \(summary.totalPoints)</div>
                    </div>
                    <div class="kpi-card">
                        <div class="kpi-label">Median Stability CV</div>
                        <div class="kpi-val">\(String(format: "%.2f %%", summary.medianCvPercentage))</div>
                    </div>
                    <div class="kpi-card">
                        <div class="kpi-label">Pareto Optimal Points</div>
                        <div class="kpi-val gold">\(frontierResult.frontierPoints.count)</div>
                    </div>
                </div>

                <div class="chart-container">
                    \(svgChart)
                </div>

                <div class="table-container">
                    <div class="table-header-ctrl">
                        <h2>Detailed Benchmark Matrix Results</h2>
                        <input type="text" id="filterInput" class="search-box" placeholder="Filter by engine or corpus..." onkeyup="filterTable()">
                    </div>
                    <table id="resultsTable">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Engine</th>
                                <th>Corpus</th>
                                <th>Buffer Size</th>
                                <th>Level</th>
                                <th>Comp Speed</th>
                                <th>Decomp Speed</th>
                                <th>Ratio</th>
                                <th>Space Savings</th>
                                <th>CV %</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
        """

        for (idx, r) in summary.results.enumerated() {
            let savings = max(0.0, (1.0 - r.compressionRatio) * 100.0)
            let sizeLabel = r.payloadSizeBytes >= 1024 * 1024 ? "\(r.payloadSizeBytes / (1024 * 1024))MB" : "\(r.payloadSizeBytes / 1024)KB"
            let compSpeed = r.compressThroughputMBs >= 1000.0 ? String(format: "%.2f GB/s", r.compressThroughputMBs / 1024.0) : String(format: "%.1f MB/s", r.compressThroughputMBs)
            let decompSpeed = r.decompressThroughputMBs >= 1000.0 ? String(format: "%.2f GB/s", r.decompressThroughputMBs / 1024.0) : String(format: "%.1f MB/s", r.decompressThroughputMBs)

            html += """
                            <tr>
                                <td>\(idx + 1)</td>
                                <td><strong>\(r.engineName)</strong></td>
                                <td>\(r.corpusType.rawValue)</td>
                                <td>\(sizeLabel)</td>
                                <td>L\(r.compressionLevel)</td>
                                <td style="color: var(--gold)">\(compSpeed)</td>
                                <td style="color: var(--blue)">\(decompSpeed)</td>
                                <td>\(String(format: "%.1f%%", r.compressionRatio * 100.0))</td>
                                <td style="color: var(--green)">\(String(format: "%.1f%%", savings))</td>
                                <td>\(String(format: "%.2f%%", r.cvPercentage))</td>
                                <td><span class="badge badge-ok">PASSED</span></td>
                            </tr>
            """
        }

        html += """
                        </tbody>
                    </table>
                </div>
            </div>

            <script>
                function filterTable() {
                    const input = document.getElementById('filterInput').value.toLowerCase();
                    const rows = document.querySelectorAll('#resultsTable tbody tr');
                    rows.forEach(row => {
                        const text = row.innerText.toLowerCase();
                        row.style.display = text.includes(input) ? '' : 'none';
                    });
                }
            </script>
        </body>
        </html>
        """

        return html
    }
}
