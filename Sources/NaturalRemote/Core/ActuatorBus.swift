import Foundation

/// Protocol for any remote actuator the Crooks loop may drive.
public protocol RemoteActuator: AnyObject, Sendable {
    var service: RemoteService { get }
    func execute(_ command: RemoteCommand) async throws
}

/// Thread-safe in-memory bus that records events and fans out commands.
public final class ActuatorBus: @unchecked Sendable {
    private let lock = NSLock()
    private var actuators: [RemoteService: any RemoteActuator] = [:]
    private var events: [ActuatorEvent] = []

    public init() {}

    public func register(_ actuator: any RemoteActuator) {
        lock.lock()
        actuators[actuator.service] = actuator
        lock.unlock()
    }

    public func execute(_ command: RemoteCommand) async throws {
        lock.lock()
        let actuator = actuators[command.service]
        lock.unlock()

        var detail: String
        var failure: Error?
        if let actuator {
            do {
                try await actuator.execute(command)
                detail = "executed"
            } catch {
                failure = error
                detail = "failed"
            }
        } else {
            detail = "no_actuator_registered"
        }

        let event = ActuatorEvent(
            service: command.service,
            action: command.action,
            detail: detail
        )
        lock.lock()
        events.append(event)
        lock.unlock()

        if let failure {
            throw failure
        }
    }

    public func recordedEvents() -> [ActuatorEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    public func resetEvents() {
        lock.lock()
        events.removeAll()
        lock.unlock()
    }
}

/// Test double / default sink that always succeeds and records locally.
public final class RecordingActuator: RemoteActuator, @unchecked Sendable {
    public let service: RemoteService
    private let lock = NSLock()
    private var _commands: [RemoteCommand] = []

    public init(service: RemoteService) {
        self.service = service
    }

    public func execute(_ command: RemoteCommand) async throws {
        lock.lock()
        _commands.append(command)
        lock.unlock()
    }

    public var commands: [RemoteCommand] {
        lock.lock()
        defer { lock.unlock() }
        return _commands
    }
}
