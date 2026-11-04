import AppKit

/// Small sounds that go with swiping. They can be turned off in Settings.
@MainActor
enum Feedback {
    enum Cue {
        case decision(Decision)
        case undo
        case done
        case error
    }

    private static var sounds: [String: NSSound] = [:]

    static func play(_ cue: Cue, sounds soundsOn: Bool) {
        guard soundsOn else { return }
        switch cue {
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
