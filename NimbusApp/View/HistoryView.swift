import SwiftUI

struct HistoryView: View {
    let totalStarsLit: Int
    @StateObject private var vm = HistoryViewModel()

    private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ZStack {
            // Background — crossfades to selected day's Nimbos stage
            GeometryReader { geo in
                Image(backgroundImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .animation(.easeInOut(duration: 0.6), value: backgroundImageName)
            }
            .ignoresSafeArea()

            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 20) {
                // Month navigation
                HStack {
                    Button { vm.previousMonth() } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(10)
                    }

                    Spacer()

                    Text(vm.monthTitle)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Spacer()

                    Button { vm.nextMonth() } label: {
                        Image(systemName: "chevron.right")
                            .foregroundColor(vm.canGoNext ? .white : .white.opacity(0.3))
                            .padding(10)
                    }
                    .disabled(!vm.canGoNext)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Weekday headers
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(weekdayLabels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)

                // Day grid
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(vm.monthDays.enumerated()), id: \.offset) { _, date in
                        if let date {
                            DayCell(
                                date: date,
                                snapshot: vm.snapshot(for: date),
                                isFuture: vm.isFuture(date),
                                isToday: vm.isToday(date),
                                isSelected: vm.selectedSnapshot.map {
                                    Calendar.current.isDate($0.date, inSameDayAs: date)
                                } ?? false
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if let snap = vm.snapshot(for: date) {
                                        vm.selectedSnapshot = (vm.selectedSnapshot.map {
                                            Calendar.current.isDate($0.date, inSameDayAs: date)
                                        } ?? false) ? nil : snap
                                    } else {
                                        vm.selectedSnapshot = nil
                                    }
                                }
                            }
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Selected day detail
                if let snap = vm.selectedSnapshot {
                    DayDetailCard(snapshot: snap)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
        }
        .onAppear { vm.reload() }
    }

    private var backgroundImageName: String {
        if let snap = vm.selectedSnapshot {
            return vm.backgroundImage(for: snap)
        }
        return "Nimbos Stage 1"
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let snapshot: DailySnapshot?
    let isFuture: Bool
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Selection ring
                if isSelected {
                    Circle()
                        .stroke(Color.cyan, lineWidth: 2)
                        .frame(width: 38, height: 38)
                }

                // Day indicator
                Circle()
                    .fill(cellBackground)
                    .frame(width: 34, height: 34)
                    .overlay(cellContent)
                    .overlay(
                        // Aurora ring for perfect days
                        Group {
                            if snapshot?.completionPercentage == 1.0 {
                                Circle()
                                    .stroke(
                                        AngularGradient(colors: [.cyan, .purple, .cyan], center: .center),
                                        lineWidth: 2
                                    )
                                    .frame(width: 38, height: 38)
                                    .blur(radius: 1)
                            }
                        }
                    )
            }

            Text(dayNumber)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(isFuture ? .white.opacity(0.2) : .white.opacity(0.7))
        }
    }

    private var cellBackground: Color {
        guard let snap = snapshot else {
            return isFuture ? .white.opacity(0.03) : .white.opacity(0.08)
        }
        switch snap.completionPercentage {
        case 1.0:    return .cyan.opacity(0.35)
        case 0.5...: return .blue.opacity(0.3)
        case 0.01...: return .white.opacity(0.15)
        default:     return .white.opacity(0.06)
        }
    }

    @ViewBuilder
    private var cellContent: some View {
        if let snap = snapshot {
            switch snap.completionPercentage {
            case 1.0:
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.cyan)
            case 0.5...:
                Image(systemName: "cloud.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            case 0.01...:
                Image(systemName: "cloud")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            default:
                Image(systemName: "cloud.fog")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.2))
            }
        } else if isToday {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 6, height: 6)
        }
    }

    private var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
}

// MARK: - Day Detail Card

private struct DayDetailCard: View {
    let snapshot: DailySnapshot

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Text(completionLabel)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(snapshot.starsLit)")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Text("stars lit")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.4))
        .cornerRadius(16)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: snapshot.date)
    }

    private var completionLabel: String {
        let pct = Int(snapshot.completionPercentage * 100)
        switch snapshot.completionPercentage {
        case 1.0:    return "Perfect day ✦"
        case 0.5...: return "\(pct)% — strong"
        case 0.01...: return "\(pct)% — some sparks"
        default:     return "Fog day"
        }
    }
}
