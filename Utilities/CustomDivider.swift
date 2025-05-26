//
//  CustomDivider.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 21/02/25.
//

import SwiftUI

struct CustomDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3)) // Subtle gray color
            .frame(height: 1) // Thin line
            .padding(.vertical, 4) // Add some padding around the divider
    }
}
