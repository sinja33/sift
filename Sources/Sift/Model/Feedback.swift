import AppKit

/// Small sounds and trackpad taps that go with swiping. Both can be turned off in Settings.
@MainActor
enum Feedback {
    enum Cue {
        /// The card crossed the point where letting go will decide it.
        case threshold
        case decision(Decision)
        case undo
        case done
        case error
    }

    private static var sounds: [String: NSSound] = [:]

    static func play(_ cue: Cue, sounds soundsOn: Bool, haptics hapticsOn: Bool) {
        if hapticsOn { tap(for: cue) }
        if soundsOn { sound(for: cue) }
    }

    private static func tap(for cue: Cue) {
        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch cue {
        case .threshold: pattern = .alignment
        case .decision(let decision): pattern = decision == .secondChance ? .generic : .levelChange
        case .undo: pattern = .alignment
        case .done: pattern = .levelChange
        case .error: pattern = .generic
        }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    private static func sound(for cue: Cue) {
        switch cue {
        case .threshold: return
        case .decision(.delete): play("Pop", volume: 0.5)
        case .decision(.keep): play("Tink", volume: 0.5)
        case .decision(.secondChance): play("Bottle", volume: 0.4)
        case .undo: play("Morse", volume: 0.3)
        case .done: play("Glass", volume: 0.35)
        case .error: play("Basso", volume: 0.3)
        }
    }

    /// System sounds are cached by name so a quick run of swipes does not reload them.
    private static func play(_ name: String, volume: Float) {
        let sound = sounds[name] ?? NSSound(named: NSSound.Name(name))
        guard let sound else { return }
        sounds[name] = sound
        sound.stop()
        sound.volume = volume
        sound.play()
    }
}
