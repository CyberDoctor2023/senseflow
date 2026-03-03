//
//  SearchBarConfigurable.swift
//  SenseFlow
//
//  Created on 2026-02-10.
//

import SwiftUI

/// 搜索栏配置协议
/// 用于依赖注入和单元测试，支持自定义配置实现
protocol SearchBarConfigurable {
    // MARK: - Layout
    var height: CGFloat { get }
    var minWidth: CGFloat { get }
    var maxWidth: CGFloat { get }

    // MARK: - Spacing
    var horizontalPadding: CGFloat { get }
    var verticalPadding: CGFloat { get }
    var componentSpacing: CGFloat { get }
    var buttonSpacing: CGFloat { get }

    // MARK: - Animation
    var morphingSpacing: CGFloat { get }
    var transitionDuration: TimeInterval { get }
    var transitionAnimation: Animation { get }

    // MARK: - Style
    var material: Material { get }
    var buttonSize: CGFloat { get }
    var fontSize: CGFloat { get }
    var iconSize: CGFloat { get }
}

// MARK: - SearchBarConfig Conformance

extension SearchBarConfig: SearchBarConfigurable {}
