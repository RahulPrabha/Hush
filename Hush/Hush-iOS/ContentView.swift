import SwiftUI

private func pal(_ isDark: Bool) -> (
    surface: Color, text: Color, textMute: Color, textDim: Color,
    hairline: Color, hairline2: Color, accent: Color, accentText: Color,
    rowSel: Color, trackBg: Color, playBg: Color, playingBlue: Color
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
        trackBg:     d ? .white.opacity(0.08) : .black.opacity(0.08),
        playBg:      d ? .white.opacity(0.06) : .black.opacity(0.06),
        playingBlue: Color(red: 0.10, green: 0.51, blue: 1.0)
    )
}

struct ContentView: View {
    @ObservedObject var audioEngine: AudioEngine
    @AppStorage("selectedNoiseType") private var selectedNoiseType = "Brown"
    @AppStorage("savedVolume") private var savedVolume = 0.5
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        let c = pal(isDarkMode)
        ScrollView {
            VStack(spacing: 18) {
                HeaderView(isPlaying: audioEngine.isPlaying)

                NoiseSection(
                    selected: audioEngine.noiseType,
                    animateBars: audioEngine.isPlaying,
                    onSelect: { type in
                        withAnimation(.easeInOut(duration: 0.2)) { audioEngine.noiseType = type }
                    }
                )

                Hairline()

                Group {
                    if audioEngine.noiseType == .brown {
                        VStack(spacing: 14) {
                            ParamHero(sub: "Brown noise",
                                      label: "Low-pass cutoff",
                                      value: Int(audioEngine.brownCutoff).formatted(),
                                      unit: "Hz")
                            SliderRow(
                                leading: { Text(20.formatted()).sliderEndStyle() },
                                trailing: { Text(500.formatted()).sliderEndStyle() },
                                value: Binding(
                                    get: { Double(audioEngine.brownCutoff) },
                                    set: { audioEngine.brownCutoff = Float($0) }
                                ),
                                range: 20...500
                            )
                            Hairline()
                        }
                        .transition(.opacity)
                    }
                }

                ParamHero(sub: "Master",
                          label: "Volume",
                          value: Int(audioEngine.volume * 100).formatted(),
                          unit: "%")
                SliderRow(
                    leading: {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(c.textDim)
                            .font(.system(size: 13))
                    },
                    trailing: {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(c.textDim)
                            .font(.system(size: 14))
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

                Hairline()

                FooterToolbar(isDarkMode: $isDarkMode)
            }
            .padding(EdgeInsets(top: 28, leading: 22, bottom: 28, trailing: 22))
        }
        .scrollIndicators(.hidden)
        .background(c.surface.ignoresSafeArea())
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            if let type = NoiseType(rawValue: selectedNoiseType) {
                audioEngine.noiseType = type
            } else {
                selectedNoiseType = audioEngine.noiseType.rawValue
            }
            audioEngine.volume = Float(savedVolume)
        }
        .onChange(of: audioEngine.noiseType) { _, newType in
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
            Text(verbatim: "Hush")
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.4)
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
            (isPlaying ? Text("Playing") : Text("Stopped"))
                .font(.system(size: 12, weight: .medium))
                .tracking(0.11)
                .foregroundColor(isPlaying ? c.text : c.textMute)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
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
        .onChange(of: isPlaying) { _, _ in startPulseIfNeeded() }
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
    let animateBars: Bool
    let onSelect: (NoiseType) -> Void
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        VStack(alignment: .leading, spacing: 4) {
            Text("Noise Type")
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.26)
                .foregroundColor(c.textDim)
                .padding(.bottom, 4)

            VStack(spacing: 4) {
                ForEach(NoiseType.allCases) { type in
                    NoiseRow(
                        type: type,
                        selected: type == selected,
                        playing: animateBars,
                        onSelect: { onSelect(type) }
                    )
                }
            }
        }
    }
}

private struct NoiseRow: View {
    let type: NoiseType
    let selected: Bool
    let playing: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        Button(action: onSelect) {
            HStack(spacing: 12) {
                RadioMark(selected: selected)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(c.text)
                    Text(type.description)
                        .font(.system(size: 13))
                        .foregroundColor(c.textMute)
                }
                Spacer(minLength: 8)
                Spectrum(shape: type.spectrumShape, active: selected, playing: playing)
                    .frame(width: 44, height: 18)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? c.rowSel : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct RadioMark: View {
    let selected: Bool
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        Canvas { ctx, size in
            let ringRect = CGRect(origin: .zero, size: size).insetBy(dx: 0.7, dy: 0.7)
            let ringColor = selected ? c.accent : c.accent.opacity(0.28)
            ctx.stroke(Circle().path(in: ringRect), with: .color(ringColor), lineWidth: 1.4)
            if selected {
                let d: CGFloat = 7
                let dotRect = CGRect(x: (size.width - d) / 2, y: (size.height - d) / 2, width: d, height: d)
                ctx.fill(Circle().path(in: dotRect), with: .color(c.accent))
            }
        }
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
        let animating = active && playing

        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animating)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(0..<barCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(tint)
                        .frame(width: barW, height: max(2, CGFloat(shape[i]) * totalHeight))
                        .scaleEffect(x: 1, y: animating ? bounce(t, i) : 1.0, anchor: .bottom)
                }
            }
            .frame(width: totalWidth, height: totalHeight, alignment: .bottom)
        }
        .frame(width: totalWidth, height: totalHeight, alignment: .bottom)
        .accessibilityHidden(true)
    }

    private func bounce(_ t: TimeInterval, _ i: Int) -> CGFloat {
        let duration = 0.55 + Double(i % 4) * 0.13
        let phase = Double(i) * 0.35
        return 0.7 + 0.3 * sin(t * .pi / duration + phase)
    }
}

// MARK: - Param hero numerals

private struct ParamHero: View {
    let sub: LocalizedStringKey
    let label: LocalizedStringKey
    let value: String
    let unit: String
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundColor(c.textMute)
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(c.text)
            }
            .padding(.bottom, 4)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(-0.9)
                    .foregroundColor(c.text)
                    .monospacedDigit()
                Text(verbatim: unit)
                    .font(.system(size: 15, weight: .medium))
                    .tracking(0.56)
                    .foregroundColor(c.textMute)
            }
        }
    }
}

// MARK: - Slider row

private extension Text {
    func sliderEndStyle() -> some View {
        self.font(.system(size: 11))
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
        HStack(spacing: 12) {
            leading()
            CustomSlider(value: $value, range: range)
            trailing()
        }
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
                    .frame(height: 4)
                Capsule()
                    .fill(c.accent)
                    .frame(width: max(0, pct * w), height: 4)
                Circle()
                    .fill(c.accent)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
                    .offset(x: pct * w - 11)
            }
            .frame(height: 44, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let p = max(0, min(1, g.location.x / w))
                        value = range.lowerBound + Double(p) * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 44)
        .accessibilityValue(Text(value, format: .number.precision(.fractionLength(0...2))))
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            switch direction {
            case .increment:
                value = min(range.upperBound, value + step)
            case .decrement:
                value = max(range.lowerBound, value - step)
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Play button

private struct PlayButton: View {
    let isPlaying: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .offset(x: isPlaying ? 0 : 2)
                (isPlaying ? Text("Stop") : Text("Play"))
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.07)
            }
            .foregroundColor(isPlaying ? c.text : c.accentText)
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isPlaying ? c.playBg : c.accent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isPlaying ? c.hairline2 : Color.clear, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? Text("Stop") : Text("Play"))
    }
}

// MARK: - Footer toolbar

private struct FooterToolbar: View {
    @Binding var isDarkMode: Bool

    var body: some View {
        HStack {
            ToolButton(
                systemName: isDarkMode ? "sun.max" : "moon",
                help: isDarkMode ? "Switch to light mode" : "Switch to dark mode"
            ) {
                isDarkMode.toggle()
            }
            Spacer()
        }
    }
}

private struct ToolButton: View {
    let systemName: String
    let help: LocalizedStringKey
    let action: () -> Void
    @Environment(\.colorScheme) private var cs

    var body: some View {
        let c = pal(cs == .dark)
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18))
                .foregroundColor(c.textMute)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(c.accent.opacity(0.06))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(help))
    }
}

// MARK: - Hairline

private struct Hairline: View {
    @Environment(\.colorScheme) private var cs

    var body: some View {
        Rectangle()
            .fill(pal(cs == .dark).hairline)
            .frame(height: 0.5)
    }
}
