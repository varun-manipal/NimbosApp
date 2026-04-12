import SwiftUI
import Combine

@MainActor
class FamilyViewModel: ObservableObject {
    @Published var children: [ChildProgressDTO] = []
    @Published var pendingInvites: [InviteResponse] = []
    @Published var familyName: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Loads family name; creates one if it doesn't exist yet.
    func loadFamily() async {
        guard APIClient.shared.isRegistered else { return }

        if let family = try? await APIClient.shared.getFamily() {
            familyName = family.name
            return
        }

        let storedName = UserDefaults.standard.string(forKey: "nimbus_userName") ?? "My"
        if let family = try? await APIClient.shared.createFamily(name: "\(storedName)'s Family") {
            familyName = family.name
        }
    }

    // Creates an email-specific invite code for a child.
    func createInvite(email: String) async -> String? {
        do {
            let response = try await APIClient.shared.createFamilyInvite(email: email)
            errorMessage = nil
            return response.inviteCode
        } catch APIError.httpError(let code) {
            errorMessage = code == 403 ? "You must be a parent to invite children." : "Server error \(code)."
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
        return nil
    }

    func deleteInvite(inviteCode: String) async {
        try? await APIClient.shared.deleteFamilyInvite(inviteCode: inviteCode)
        pendingInvites.removeAll { $0.inviteCode == inviteCode }
    }

    func loadChildren() async {
        isLoading = true
        defer { isLoading = false }
        async let childrenResult = APIClient.shared.getChildren()
        async let invitesResult  = APIClient.shared.getPendingInvites()
        children       = (try? await childrenResult) ?? children
        pendingInvites = (try? await invitesResult)  ?? pendingInvites
    }

    func loadChild(_ childId: UUID) async {
        do {
            let updated = try await APIClient.shared.getChild(childId)
            if let idx = children.firstIndex(where: { $0.userId == childId }) {
                children[idx] = updated
            }
        } catch {}
    }

    func addTask(to childId: UUID, title: String) async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            _ = try await APIClient.shared.addTaskToChild(childId, title: title)
            await loadChild(childId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeTask(childId: UUID, taskId: UUID) async {
        do {
            try await APIClient.shared.removeTaskFromChild(childId, taskId: taskId)
            await loadChild(childId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameTask(childId: UUID, taskId: UUID, title: String) async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            _ = try await APIClient.shared.renameTaskForChild(childId, taskId: taskId, title: title)
            await loadChild(childId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
