import SwiftUI
import Combine

@MainActor
class FamilyViewModel: ObservableObject {
    @Published var children: [ChildProgressDTO] = []
    @Published var pendingInvites: [InviteResponse] = []
    @Published var familyName: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedChildAwards: [MilestoneAwardDTO] = []

    // Clears all in-memory state on sign-out so the next user starts fresh.
    func reset() {
        children = []
        pendingInvites = []
        familyName = ""
        errorMessage = nil
        selectedChildAwards = []
    }

    // Loads family name; creates one if the server reports none exists (404).
    // Other errors (network failure, 5xx) abort early to avoid creating a family
    // on transient failures, which could trigger the privilege-escalation path.
    func loadFamily() async {
        guard APIClient.shared.isRegistered, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let family = try await APIClient.shared.getFamily()
            familyName = family.name
            return
        } catch APIError.httpError(404) {
            // No family yet — fall through to create one
        } catch {
            // Network or server error — do not attempt creation
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

    func loadChildAwards(_ childId: UUID) async {
        do {
            let awards = try await APIClient.shared.getChildAwards(childId: childId)
            selectedChildAwards = awards
        } catch {
            // Silent failure
        }
    }

    func saveChildAward(childId: UUID, milestoneShards: Int, award1: String?, award2: String?, award3: String?) async {
        do {
            let updated = try await APIClient.shared.setChildAward(childId: childId, milestoneShards: milestoneShards, award1: award1, award2: award2, award3: award3)
            if let idx = selectedChildAwards.firstIndex(where: { $0.milestoneShards == milestoneShards }) {
                selectedChildAwards[idx] = updated
            } else {
                selectedChildAwards.append(updated)
                selectedChildAwards.sort { $0.milestoneShards < $1.milestoneShards }
            }
        } catch {
            // Silent failure
        }
    }
}
