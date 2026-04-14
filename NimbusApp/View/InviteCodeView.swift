import SwiftUI

struct InviteCodeView: View {
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var generatedCode: String = ""
    @State private var isGenerating = false
    @State private var copied = false

    private var emailIsValid: Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.purple)
                    .shadow(color: .purple.opacity(0.5), radius: 16)

                VStack(spacing: 12) {
                    Text("Add a Child")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)

                    Text(generatedCode.isEmpty
                         ? "Enter your child's email to generate\na unique invite code."
                         : "Share this code with your child.\nThey'll need their email to activate it.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                if generatedCode.isEmpty {
                    // Email input
                    VStack(spacing: 16) {
                        TextField("child@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.white.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(emailIsValid ? Color.purple.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 32)

                        if let err = viewModel.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        Button {
                            Task { await generate() }
                        } label: {
                            Group {
                                if isGenerating {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Generate Code")
                                        .font(.system(.body, design: .rounded).weight(.medium))
                                }
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(emailIsValid ? Color.purple : Color.gray.opacity(0.4)))
                        }
                        .disabled(!emailIsValid || isGenerating)
                        .padding(.horizontal, 32)
                    }
                } else {
                    // Generated code display
                    VStack(spacing: 20) {
                        Text(generatedCode)
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
                            .foregroundColor(.purple)
                            .tracking(8)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.purple.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.purple.opacity(0.4), lineWidth: 1.5)
                                    )
                            )

                        Text(email)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.gray)

                        Button {
                            UIPasteboard.general.string = generatedCode
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copied = false }
                            }
                        } label: {
                            Label(copied ? "Copied!" : "Copy Code", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundColor(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(copied ? Color.green : Color.purple))
                        }
                        .animation(.spring(response: 0.3), value: copied)

                        // Allow generating another invite
                        Button("Add another child") {
                            generatedCode = ""
                            email = ""
                            viewModel.errorMessage = nil
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.purple.opacity(0.7))
                    }
                }

                Spacer()

                Button("Done") { dismiss() }
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 8)
        }
        .task {
            viewModel.errorMessage = nil
        }
    }

    private func generate() async {
        isGenerating = true
        defer { isGenerating = false }
        if let code = await viewModel.createInvite(email: email.trimmingCharacters(in: .whitespaces)) {
            generatedCode = code
        }
    }
}
