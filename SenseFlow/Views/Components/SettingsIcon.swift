//
//  SettingsIcon.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-28.
//

import SwiftUI

/// A view that renders a colorful icon similar to macOS System Settings sidebar icons.
/// Displays a symbol within a rounded rectangle of a specified color.
struct SettingsIcon: View {
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Constants.SettingsIcon.cornerRadius, style: .continuous)
                .fill(color)
                .frame(width: Constants.SettingsIcon.size, height: Constants.SettingsIcon.size)
                .shadow(color: .black.opacity(Constants.opacity10), radius: Constants.SettingsIcon.shadowRadius, x: 0, y: 1)

            Image(systemName: icon)
                .font(.system(size: Constants.SettingsIcon.iconFontSize, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        HStack {
            SettingsIcon(icon: "gear", color: .gray)
            Text("General")
        }
        HStack {
            SettingsIcon(icon: "lock", color: .blue)
            Text("Privacy")
        }
        HStack {
            SettingsIcon(icon: "keyboard", color: .orange)
            Text("Keyboard")
        }
    }
    .padding()
}
