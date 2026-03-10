import Foundation

@MainActor
final class SceneManager: ObservableObject {
    static let shared = SceneManager()

    private static let currentIdKey = "sceneCurrentId"

    @Published var currentSceneId: String {
        didSet { UserDefaults.standard.set(currentSceneId, forKey: Self.currentIdKey) }
    }

    let allScenes: [SceneProfile] = SceneProfile.presets

    var currentScene: SceneProfile {
        allScenes.first { $0.id == currentSceneId } ?? allScenes[0]
    }

    private init() {
        self.currentSceneId = UserDefaults.standard.string(forKey: Self.currentIdKey) ?? "none"
    }

    func select(_ scene: SceneProfile) {
        currentSceneId = scene.id
    }

    /// Thread-safe access to the current scene prompt for use in AIPolishService.
    /// Reads directly from UserDefaults + presets without MainActor isolation.
    nonisolated static var currentScenePrompt: String {
        let id = UserDefaults.standard.string(forKey: "sceneCurrentId") ?? "none"
        return SceneProfile.presets.first { $0.id == id }?.promptTemplate ?? ""
    }
}
