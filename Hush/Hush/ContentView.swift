import SwiftUI

// Colors derived from current color scheme so the light/dark toggle works.
private func pal(_ isDark: Bool) -> (
    surface: Color, text: Color, textMute: Color, textDim: Color,
    hairline: Color, hairline2: Color, accent: Color, accentText: Color,
    rowSel: Color, rowHover: Color, trackBg: Color, playBg: Color,
    playingBlue: Color
) {
    let d = isDark
    return (
        surface:     d ? .black : Color(red: 0.925, green: 0.925, blue: 0.933),
        text:        d ? .white.opacity(0.96) : .black.opacity(0.85),
        textMute:    d ? .white.opacity(0.55) : .black.opacity(0.50),
        textDim:     d ? .white.opacity(0.32) : .black.opacity(0.42),
        hairline:    d ? .white.opacity(0.07) : .black.opacity(0.07),
        hairline2:   d ? .white.opacity(0.12) : .black.opacity(0.12),
        accent:      d ? .white : .black,
        accentText:  d ? .black : .white,
        rowSel:      d ? .white.opacity(0.05) : .black.opacity(0.05),
        rowHover:    d ? .white.opacity(0.04) : .black.opacity(0.04),
        trackBg:     d ? .white.opacity(0.08) : .black.opacity(0.08),
        playBg:      d ? .white.opacity(0.06) : .black.opacity(0.06),
        playingBlue: Color(red: 0.10, green: 0.51, blue: 1.0)
    )
}

struct ContentView: View {
    @ObservedObject var audioEngine: AudioEngine
    @AppStorage("selectedNoiseType") private var selectedNoiseType = "White"
    @AppStorage("savedVolume") private var savedVolume = 0.5
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        let c = pal(isDarkMode)
        VStack(spacing: 14) {
            HeaderView(isPlaying: audioEngine.isPlaying)

            NoiseSection(
                selected: audioEngine.noiseType,
                isPlaying: audioEngine.isPlaying,
                onSelect: { audioEngine.noiseType = $0 }
            )

            Hairline()

            if audioEngine.noiseType == .brown {
                ParamHero(sub: "Brown noise",
                          label: "Low-pass cutoff",
                          value: "\(Int(audioEngine.brownCutoff))",
                          unit: "Hz")
                SliderRow(
                    leading: { Text("20").sliderEndStyle() },
                    trailing: { Text("500").sliderEndStyle() },
                    value: Binding(
                        get: { Double(audioEngine.brownCutoff) },
                        set: { audioEngine.brownCutoff = Float($0) }
                    ),
                    range: 20...500
                )
                Hairline()
            }

            ParamHero(sub: "Master",
                      label: "Volume",
                      value: "\(Int(audioEngine.volume * 100))",
                      unit: "%")
            SliderRow(
                leading: {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(c.textDim)
                        .font(.system(size: 11))
                },
                trailing: {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(c.textDim)
                        .font(.system(size: 12))
                },
                value: Binding(
                    get: { Double(audioEngine.volume) },
                    set: {
                        audioEngine.volume = Float($0)
                        savedVolume = $0
                    }
                ),
                range: 0...1
            )

            Hairline()

            PlayButton(isPlaying: audioEngine.isPlaying) {
                audioEngine.toggle()
            }
            .keyboardShortcut(.space, modifiers: [])

            HStack(spacing: 8) {
                Image(systemName: "computermouse")
                    .foregroundColor(c.textDim)
                    .font(.system(size: 12))
                Text("Right-click the menu bar icon to toggle")
                    .font(.system(size: 11.5))
                    .foregroundColor(c.textMute)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)

            Hairline()

            FooterToolbar(isDarkMode: $isDarkMode)
        }
        .padding(EdgeInsets(top: 18, leading: 18, bottom: 12, trailing: 18))
        .frame(width: 360)
        .background(c.surface)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            if let type = NoiseType(rawValue: selectedNoiseType) {
                audioEngine.noiseType = type
            }
            audioEngine.volume = Float(savedVolume)
        }
        .onChange(of: audioEngine.noiseType) { newType in
            selectedNoiseType = newType.rawValue
        }
    }
}

// MARK: - Header

private struct HeaderView: View {
    let isPlaying: Bool
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        HStack {
            Text("Hush")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.33)
                .foregroundColor(c.text)
            Spacer()
            StatusPill(isPlaying: isPlaying)
        }
    }
}

private struct StatusPill: View {
    let isPlaying: Bool
    @State private var pulse = false
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        HStack(spacing: 6) {
            ZStack {
                if isPlaying {
                    Circle()
                        .fill(c.playingBlue.opacity(0.18))
                        .frame(width: pulse ? 14 : 12, height: pulse ? 14 : 12)
                        .opacity(pulse ? 0.5 : 1.0)
                }
                Circle()
                    .fill(isPlaying ? c.playingBlue : c.textDim)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 14, height: 14)
            Text(isPlaying ? "Playing" : "Stopped")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.11)
                .foregroundColor(isPlaying ? c.text : c.textMute)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(c.accent.opacity(0.02)))
        .overlay(
            Capsule().stroke(
                isPlaying
                    ? (cs == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.22))
                    : c.hairline2,
                lineWidth: 0.5
            )
        )
        .onAppear { startPulseIfNeeded() }
        .onChange(of: isPlaying) { _ in startPulseIfNeeded() }
    }

    private func startPulseIfNeeded() {
        guard isPlaying else { pulse = false; return }
        pulse = false
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

// MARK: - Noise list

private struct NoiseSection: View {
    let selected: NoiseType
    let isPlaying: Bool
    let onSelect: (NoiseType) -> Void
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        VStack(alignment: .leading, spacing: 4) {
            Text("NOISE TYPE")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.26)
                .foregroundColor(c.textDim)
                .padding(.bottom, 4)

            VStack(spacing: 1) {
                ForEach(NoiseType.allCases) { type in
                    NoiseRow(
                        type: type,
                        selected: type == selected,
                        playing: isPlaying,
                        onSelect: { onSelect(type) }
                    )
                }
            }
            .padding(.horizontal, -8)
        }
    }
}

private struct NoiseRow: View {
    let type: NoiseType
    let selected: Bool
    let playing: Bool
    let onSelect: () -> Void
    @State private var hover = false
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        Button(action: onSelect) {
            HStack(spacing: 10) {
                RadioMark(selected: selected)
                    .frame(width: 16, height: 16)
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(c.text)
                Spacer(minLength: 8)
                Text(type.description)
                    .font(.system(size: 12))
                    .foregroundColor(c.textMute)
                Spectrum(shape: type.spectrumShape, active: selected, playing: playing)
                    .frame(width: 44, height: 18)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? c.rowSel : (hover ? c.rowHover : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

private struct RadioMark: View {
    let selected: Bool
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        ZStack {
            Circle()
                .stroke(selected ? c.accent : c.accent.opacity(0.28), lineWidth: 1.4)
            if selected {
                Circle()
                    .fill(c.accent)
                    .frame(width: 6.5, height: 6.5)
                    .transition(.scale)
            }
        }
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

// MARK: - Spectrum mini-EQ

private struct Spectrum: View {
    let shape: [Float]
    let active: Bool
    let playing: Bool
    @Environment(\.colorScheme) private var cs

    private let barCount = 8
    private let totalWidth: CGFloat = 44
    private let totalHeight: CGFloat = 18
    private let gap: CGFloat = 1.5

    var body: some View {
        let c = pal(cs == .dark)
        let barW = (totalWidth - gap * CGFloat(barCount - 1)) / CGFloat(barCount)
        let tint: Color = active ? c.accent : c.textDim

        HStack(alignment: .bottom, spacing: gap) {
            ForEach(0..<barCount, id: \.self) { i in
                SpectrumBar(
                    height: max(2, CGFloat(shape[i]) * totalHeight),
                    color: tint,
                    animating: active && playing,
                    delay: Double(i) * 0.05,
                    duration: 0.55 + Double(i % 4) * 0.13
                )
                .frame(width: barW)
            }
        }
        .frame(width: totalWidth, height: totalHeight, alignment: .bottom)
    }
}

private struct SpectrumBar: View {
    let height: CGFloat
    let color: Color
    let animating: Bool
    let delay: Double
    let duration: Double
    // Toggles between resting (false → scale 1.0) and compressed (true → scale 0.4).
    // repeatForever(autoreverses) bounces between the two extremes.
    @State private var compressed = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(height: height)
            .scaleEffect(x: 1, y: compressed ? 0.4 : 1.0, anchor: .bottom)
            .onAppear { update() }
            .onChange(of: animating) { _ in update() }
    }

    private func update() {
        if animating {
            // Animate compressed → true; autoreverses keeps bars within [0.4, 1.0].
            withAnimation(
                .easeInOut(duration: duration)
                    .delay(delay)
                    .repeatForever(autoreverses: true)
            ) {
                compressed = true
            }
        } else {
            // Override the repeatForever with a one-shot animation back to rest.
            withAnimation(.easeInOut(duration: 0.25)) {
                compressed = false
            }
        }
    }
}

// MARK: - Param hero numerals

private struct ParamHero: View {
    let sub: String
    let label: String
    let value: String
    let unit: String
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundColor(c.textMute)
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(c.text)
            }
            .padding(.bottom, 4)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.9)
                    .foregroundColor(c.text)
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(0.56)
                    .foregroundColor(c.textMute)
            }
        }
    }
}

// MARK: - Slider row

private extension Text {
    func sliderEndStyle() -> some View {
        self.font(.system(size: 10.5))
            .monospacedDigit()
            .foregroundColor(Color.primary.opacity(0.32))
            .fixedSize()
    }
}

private struct SliderRow<L: View, T: View>: View {
    @ViewBuilder var leading: () -> L
    @ViewBuilder var trailing: () -> T
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 10) {
            leading()
            CustomSlider(value: $value, range: range)
            trailing()
        }
        .padding(.horizontal, 2)
    }
}

private struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        GeometryReader { geo in
            let pct = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(c.trackBg)
                    .frame(height: 3)
                Capsule()
                    .fill(c.accent)
                    .frame(width: max(0, pct * w), height: 3)
                Circle()
                    .fill(c.accent)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
                    .offset(x: pct * w - 7)
            }
            .frame(height: 18, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let p = max(0, min(1, g.location.x / w))
                        value = range.lowerBound + Double(p) * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 18)
    }
}

// MARK: - Play button

private struct PlayButton: View {
    let isPlaying: Bool
    let action: () -> Void
    @State private var hover = false
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(isPlaying ? "Stop" : "Play")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.07)
            }
            .foregroundColor(isPlaying ? c.text : c.accentText)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPlaying ? c.playBg : c.accent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPlaying ? c.hairline2 : Color.clear, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Footer toolbar

private struct FooterToolbar: View {
    @Binding var isDarkMode: Bool

    var body: some View {
        HStack(spacing: 4) {
            ToolButton(systemName: "info.circle", help: "About Hush") {
                NSApp.orderFrontStandardAboutPanel(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            Spacer()
            ToolButton(
                systemName: isDarkMode ? "sun.max" : "moon",
                help: isDarkMode ? "Switch to light mode" : "Switch to dark mode"
            ) {
                isDarkMode.toggle()
            }
        }
        .padding(.horizontal, 2)
    }
}

private struct ToolButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var hover = false
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundColor(hover ? c.text : c.textMute)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(hover ? c.accent.opacity(0.06) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover = $0 }
    }
}

// MARK: - Hairline

private struct Hairline: View {
    @Environment(\.colorScheme) private var cs

    var body: some View {
        Rectangle()
            .fill(pal(cs == .dark).hairline)
            .frame(height: 0.5)
            .padding(.horizontal, -2)
    }
}
