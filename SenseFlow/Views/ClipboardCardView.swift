//
//  ClipboardCardView.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import SwiftUI

/// 剪贴板卡片视图
struct ClipboardCardView: View {

    let item: ClipboardItem
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top indicator bar (3pt height)
            Rectangle()
                .fill(colorForType(item.type))
                .frame(height: Constants.Card.indicatorHeight)

            // Content area
            VStack(alignment: .leading, spacing: Constants.Card.contentSpacing) {
                // Content preview
                contentPreview

                Spacer()

                // Metadata bar (app icon + name + timestamp)
                HStack(spacing: Constants.Card.metadataSpacing) {
                    // App icon
                    Image(nsImage: item.appIcon)
                        .resizable()
                        .frame(width: Constants.Card.iconSize, height: Constants.Card.iconSize)

                    // App name
                    Text(item.appName)
                        .font(.system(size: Constants.Card.fontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    // Time label
                    Text(item.relativeTimeString)
                        .font(.system(size: Constants.Card.fontSize))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Constants.spacing8)
                .padding(.bottom, Constants.spacing8)
            }
            .padding(.horizontal, Constants.Card.paddingHorizontal)
            .padding(.top, Constants.Card.paddingTop)
        }
        .frame(width: Constants.Card.width, height: Constants.Card.height)
        .compatibleMaterial(.thinMaterial, cornerRadius: Constants.Card.cornerRadius)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Card.cornerRadius))
        // GPU 加速：将 Material + Content 合成为单个离屏图像
        // opaque: false 确保透明度正确处理，避免窗口淡出时出现黑边
        // colorMode: .linear 使用线性颜色空间，更准确的透明度混合
        .drawingGroup(opaque: false, colorMode: .linear)
        .shadow(
            color: Constants.Shadow.color.opacity(Constants.Shadow.opacity),
            radius: Constants.Shadow.radius,
            x: Constants.Shadow.offsetX,
            y: Constants.Shadow.offsetY
        )
        // Hover animation: scale 1.0 → 1.05
        .scaleEffect(isHovered ? Constants.hoverScaleSmall : 1.0)
        .animation(.snappy(duration: Constants.snappyAnimationDuration, extraBounce: Constants.snappyAnimationBounce), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    private var contentPreview: some View {
        switch item.type {
        case .text:
            Text(item.previewText)
                .font(.system(size: Constants.Typography.caption))
                .lineLimit(8)
                .frame(maxWidth: .infinity, maxHeight: Constants.Card.textMaxHeight, alignment: .topLeading)
                .foregroundStyle(.primary)

        case .image:
            // 使用图片缓存避免重复的磁盘 I/O
            if let image = ClipboardImageCache.shared.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: Constants.Card.imageMaxHeight)
                    .cornerRadius(Constants.cornerRadiusSmall)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: ClipboardItemColors.emptyStateIconSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: Constants.Card.imageMaxHeight)
            }
        }
    }

    // MARK: - Helper Methods

    private func colorForType(_ type: ClipboardItemType) -> Color {
        switch type {
        case .text:
            return ClipboardItemColors.text
        case .image:
            return ClipboardItemColors.image
        }
    }
}
