//
//  GlowEffect.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 31/01/25.
//

import SwiftUI

struct GlowEffect: View {
    @State private var gradientStops: [Gradient.Stop] = GlowEffect.generateGradientStops()
    @State private var timer: Timer? = nil

    var body: some View {
        ZStack {
            // Each effect layer is now offset differently to simulate a glowing border
            EffectNoBlur(gradientStops: gradientStops, width: 6, xOffset: 0, yOffset: 0)
            Effect(gradientStops: gradientStops, width: 9, blur: 4, xOffset: -2, yOffset: 4)
            Effect(gradientStops: gradientStops, width: 11, blur: 12, xOffset: 6, yOffset: -6)
            Effect(gradientStops: gradientStops, width: 15, blur: 15, xOffset: -8, yOffset: -8)
        }
        .onAppear {
            // Start a timer to update the gradient stops every 0.4 seconds
            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.8)) {
                    gradientStops = GlowEffect.generateGradientStops()
                }
            }
        }
        .onDisappear {
            // Invalidate the timer when the view disappears
            timer?.invalidate()
            timer = nil
        }
    }
    
    // Function to generate random gradient stops
    static func generateGradientStops() -> [Gradient.Stop] {
        [
            Gradient.Stop(color: Color(hex: "BC82F3"), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(hex: "F5B9EA"), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(hex: "8D9FFF"), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(hex: "FF6778"), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(hex: "FFBA71"), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color(hex: "C686FF"), location: Double.random(in: 0...1))
        ].sorted { $0.location < $1.location }
    }
}

struct Effect: View {
    var gradientStops: [Gradient.Stop]
    var width: CGFloat
    var blur: CGFloat
    var xOffset: CGFloat
    var yOffset: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 55)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(stops: gradientStops),
                        center: .center
                    ),
                    lineWidth: width
                )
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
                .offset(x: xOffset, y: yOffset) // Offset to simulate border thickness
                .blur(radius: blur)
        }
    }
}

struct EffectNoBlur: View {
    var gradientStops: [Gradient.Stop]
    var width: CGFloat
    var xOffset: CGFloat
    var yOffset: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 55)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(stops: gradientStops),
                        center: .center
                    ),
                    lineWidth: width
                )
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
                .offset(x: xOffset, y: yOffset) // Offset to simulate border thickness
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)
        
        let r = Double((hexNumber & 0xff0000) >> 16) / 255
        let g = Double((hexNumber & 0x00ff00) >> 8) / 255
        let b = Double(hexNumber & 0x0000ff) / 255
        
        self.init(red: r, green: g, blue: b)
    }
}

