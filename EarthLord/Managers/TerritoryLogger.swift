//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地日志记录器（一楼）
//  作用：存储和管理所有圈地相关的日志，供真机测试时查看
//

import Foundation
import SwiftUI
import Combine

/// 日志类型
enum LogType {
    case info       // 普通信息
    case warning    // 警告
    case error      // 错误
    case success    // 成功

    var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .success: return "✅"
        }
    }

    var color: Color {
        switch self {
        case .info: return .white
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}

/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType

    /// 格式化的时间字符串（HH:mm:ss）
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    /// 格式化的完整日志文本
    var formattedText: String {
        return "[\(timeString)] [\(type.emoji)] \(message)"
    }
}

/// 圈地日志记录器（单例模式）
class TerritoryLogger: ObservableObject {

    // MARK: - 单例

    static let shared = TerritoryLogger()

    // MARK: - Published 属性

    /// 所有日志条目
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（供 TextEditor 直接显示）
    @Published var logText: String = ""

    /// 日志总数
    var logCount: Int {
        return logs.count
    }

    // MARK: - 私有初始化（单例模式）

    private init() {
        log("日志系统初始化完成", type: .info)
    }

    // MARK: - 公开方法

    /// 记录日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogType = .info) {
        // 创建日志条目
        let entry = LogEntry(
            timestamp: Date(),
            message: message,
            type: type
        )

        // 添加到数组
        logs.append(entry)

        // 更新格式化文本
        if !logText.isEmpty {
            logText += "\n"
        }
        logText += entry.formattedText

        // 同时打印到控制台（开发时方便查看）
        print("📝 \(entry.formattedText)")
    }

    /// 清空所有日志
    func clear() {
        logs.removeAll()
        logText = ""
        log("日志已清空", type: .info)
    }

    /// 导出日志为文本
    func exportText() -> String {
        return logText
    }

    /// 获取最近 N 条日志
    func getRecentLogs(count: Int) -> [LogEntry] {
        let startIndex = max(0, logs.count - count)
        return Array(logs[startIndex...])
    }
}
