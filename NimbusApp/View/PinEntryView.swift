import SwiftUI

struct PinEntryView: View {

    enum Mode {
        case setup                      // two-phase: create + confirm
        case verify(storedPin: String)  // single-phase: check against stored pin
    }

    let mode: Mode
    var onSuccess: (String) -> Void  // setup → new pin string; verify → called on match
    var onCancel: (() -> Void)? = nil

    @State private var entered      = ""
    @State private var firstPin     = ""        // holds first entry during setup confirm
    @State private var isConfirm    = false     // true during setup confirm phase
    @State private var errorMessage = ""
    @State private var shakeOffset: CGFloat = 0

    private let pinLength = 4

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.04, green: 0.05, blue: 0.11).ignoresSafeArea()
            Circle()
                .fill(Color.cyan.opacity(0.18))
                .blur(radius: 90)
                .offset(x: -50, y: -120)
            Circle()
                .fill(Color.purple.opacity(0.12))
                .blur(radius: 110)
                .offset(x: 80, y: 140)

            VStack(spacing: 0) {
                // Cancel button — verify mode only
                if let cancel = onCancel {
                    HStack {
                        Button("Cancel", action: cancel)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                }

                Spacer()

                // Icon + heading
                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.cyan.opacity(0.85))

                    Text(headline)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 44)
                }

                Spacer().frame(height: 44)

                // PIN dots
                HStack(spacing: 22) {
                    ForEach(0..<pinLength, id: \.self) { i in
                        Circle()
                            .fill(i < entered.count ? Color.cyan : Color.white.opacity(0.2))
                            .frame(width: 15, height: 15)
                            .scaleEffect(i < entered.count ? 1.15 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: entered.count)
                    }
                }
                .offset(x: shakeOffset)

                // Error label — always takes space so layout doesn't jump
                Text(errorMessage)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(height: 18)
                    .padding(.top, 14)

                Spacer().frame(height: 36)

                // Numpad
                numpad
                    .padding(.horizontal, 44)

                Spacer()
            }
        }
    }

    // MARK: - Numpad

    private var numpad: some View {
        let rows: [[String]] = [
            ["1","2","3"],
            ["4","5","6"],
            ["7","8","9"],
            [ "", "0","⌫"]
        ]
        return VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 18) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(width: 76, height: 76)
                        } else {
                            Button { tap(key) } label: {
                                ZStack {
                                    Circle()
                                        .fill(key == "⌫"
                                              ? Color.white.opacity(0.06)
                                              : Color.white.opacity(0.1))
                                        .frame(width: 76, height: 76)
                                    Text(key)
                                        .font(.system(size: key == "⌫" ? 20 : 28,
                                                      weight: .medium,
                                                      design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var headline: String {
        switch mode {
        case .setup:   return isConfirm ? "Confirm PIN" : "Create a Parent PIN"
        case .verify:  return "Parent PIN Required"
        }
    }

    private var subtitle: String {
        switch mode {
        case .setup:
            return isConfirm
                ? "Re-enter your 4-digit PIN to confirm"
                : "Only you can edit the habit list with this PIN"
        case .verify:
            return "Enter your PIN to edit the habit list"
        }
    }

    private func tap(_ key: String) {
        errorMessage = ""
        if key == "⌫" {
            if !entered.isEmpty { entered.removeLast() }
            return
        }
        guard entered.count < pinLength else { return }
        entered.append(key)

        if entered.count == pinLength {
            // Small delay so the last dot fills before action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { commit() }
        }
    }

    private func commit() {
        switch mode {
        case .setup:
            if !isConfirm {
                firstPin    = entered
                entered     = ""
                isConfirm   = true
            } else {
                if entered == firstPin {
                    onSuccess(entered)
                } else {
                    triggerError("PINs don't match — try again")
                    isConfirm = false
                    firstPin  = ""
                }
            }
        case .verify(let stored):
            if entered == stored {
                onSuccess(entered)
            } else {
                triggerError("Incorrect PIN")
            }
        }
    }

    private func triggerError(_ message: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        errorMessage = message
        withAnimation(.easeInOut(duration: 0.06).repeatCount(5, autoreverses: true)) {
            shakeOffset = 9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            shakeOffset = 0
            entered = ""
        }
    }
}
