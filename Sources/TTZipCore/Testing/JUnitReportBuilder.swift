import Foundation

/// 兼容 Jenkins / GitHub Actions / GitLab CI 的 JUnit XML 报告构建器
public enum JUnitReportBuilder {
    
    /// 将测试会话数据转换为标准 JUnit XML 字符串
    public static func buildXML(from report: TestSessionReport) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<testsuites name=\"TTZipTests\" tests=\"\(report.totalTests)\" failures=\"\(report.failedTests)\" errors=\"0\" time=\"\(String(format: "%.3f", report.totalDurationSeconds))\">\n"
        
        let groupedByClass = Dictionary(grouping: report.testCases, by: \.className)
        
        for (className, cases) in groupedByClass.sorted(by: { $0.key < $1.key }) {
            let classFailures = cases.filter { !$0.passed }.count
            let classDuration = cases.reduce(0.0) { $0 + $1.durationSeconds }
            
            xml += "  <testsuite name=\"\(escape(className))\" tests=\"\(cases.count)\" failures=\"\(classFailures)\" errors=\"0\" time=\"\(String(format: "%.3f", classDuration))\">\n"
            
            for tc in cases {
                xml += "    <testcase name=\"\(escape(tc.name))\" classname=\"\(escape(tc.className))\" time=\"\(String(format: "%.3f", tc.durationSeconds))\">\n"
                if !tc.passed {
                    let msg = escape(tc.failureMessage ?? "Assertion failure")
                    xml += "      <failure message=\"\(msg)\">\(msg)</failure>\n"
                }
                xml += "    </testcase>\n"
            }
            
            xml += "  </testsuite>\n"
        }
        
        xml += "</testsuites>\n"
        return xml
    }
    
    private static func escape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
