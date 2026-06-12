import SwiftUI

@MainActor
final class PopupViewModel: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published var selectedIndex: Int?

    let items: [ClipboardItem]
    let visibleCount: Int
    private let select: (ClipboardItem) -> Void
    private let close: () -> Void

    init(
        items: [ClipboardItem],
        visibleCount: Int,
        select: @escaping (ClipboardItem) -> Void,
        close: @escaping () -> Void
    ) {
        self.items = items
        self.visibleCount = visibleCount
        self.select = select
        self.close = close
    }

    var visibleItems: [ClipboardItem] {
        Array(items.prefix(isExpanded ? items.count : visibleCount))
    }

    var canExpand: Bool {
        items.count > visibleCount
    }

    func toggleExpanded() {
        isExpanded.toggle()
        selectedIndex = selectedIndex.map { min($0, max(visibleItems.count - 1, 0)) }
    }

    func moveSelection(_ delta: Int) {
        guard !visibleItems.isEmpty else {
            return
        }

        guard let current = selectedIndex else {
            selectedIndex = delta >= 0 ? 0 : visibleItems.count - 1
            return
        }

        selectedIndex = (current + delta + visibleItems.count) % visibleItems.count
    }

    func chooseSelected() {
        // With no selection, Return pastes the most recent item.
        choose(index: selectedIndex ?? 0)
    }

    func choose(index: Int) {
        guard visibleItems.indices.contains(index) else {
            return
        }

        select(visibleItems[index])
    }
}

struct PopupView: View {
    @ObservedObject var viewModel: PopupViewModel
    @State private var appeared = false
    @Namespace private var selectionNamespace

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(viewModel.visibleItems.enumerated()), id: \.element.id) { index, item in
                Button {
                    viewModel.choose(index: index)
                } label: {
                    ClipboardRow(
                        number: index + 1,
                        item: item,
                        isSelected: index == viewModel.selectedIndex,
                        namespace: selectionNamespace
                    )
                }
                .buttonStyle(PressableRowStyle())
                .onHover { hovering in
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                        if hovering {
                            viewModel.selectedIndex = index
                        } else if viewModel.selectedIndex == index {
                            viewModel.selectedIndex = nil
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(
                    .spring(response: 0.42, dampingFraction: 0.78)
                        .delay(0.05 + Double(min(index, 8)) * 0.035),
                    value: appeared
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97, anchor: .top)),
                        removal: .opacity
                    )
                )
            }

            if viewModel.canExpand {
                Divider()
                    .opacity(0.3)
                    .padding(.horizontal, 10)
                    .padding(.top, 3)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.2), value: appeared)

                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                        viewModel.toggleExpanded()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isExpanded ? "chevron.up" : "ellipsis")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 18, height: 18)
                            .contentTransition(.symbolEffect(.replace))

                        Text(viewModel.isExpanded ? "Show less" : "More history")
                            .font(.system(size: 11, weight: .medium))

                        Spacer()

                        Text("\(viewModel.items.count - viewModel.visibleCount)")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.white.opacity(0.08)))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableRowStyle())
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.24), value: appeared)
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.8), value: viewModel.selectedIndex)
        .padding(8)
        .frame(width: 520, alignment: .topLeading)
        .veeGlass(cornerRadius: 20)
        .overlay {
            // Outer rim: bright catch-light top-left fading out bottom-right.
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.12), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .overlay {
            // Inner sheen along the top edge, like light refracting inside the glass.
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .inset(by: 1)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 1
                )
        }
        .scaleEffect(appeared ? 1 : 0.84, anchor: .top)
        .opacity(appeared ? 1 : 0)
        .blur(radius: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.74)) {
                appeared = true
            }
        }
    }
}

private struct ClipboardRow: View {
    let number: Int
    let item: ClipboardItem
    let isSelected: Bool
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 17, height: 17)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.white.opacity(isSelected ? 0.2 : 0.07))
                }

            if let icon = item.kindIcon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.8) : Color.secondary)
                    .frame(width: 16)
            }

            Text(item.preview)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background {
            if isSelected {
                // A lens of clear glass with a faint iridescent sheen,
                // not a painted fill — the row text keeps its own color.
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(0.1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.cyan.opacity(0.14),
                                        Color.purple.opacity(0.12),
                                        Color.pink.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.06)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: .white.opacity(0.12), radius: 8, y: 2)
                    .matchedGeometryEffect(id: "selection", in: namespace)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private extension View {
    @ViewBuilder
    func veeGlass(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *) {
            self
                .glassEffect(.regular, in: shape)
        } else {
            self
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(
                            LinearGradient(
                                colors: [.white.opacity(0.13), .white.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
        }
    }
}
