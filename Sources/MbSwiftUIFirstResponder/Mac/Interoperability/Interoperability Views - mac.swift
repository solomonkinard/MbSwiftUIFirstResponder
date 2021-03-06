//
//  Interoperability.swift
//  MbSwiftFirstResponder
//
//  Created by QuickPlan.app on 2020/12/2.
//
#if os(macOS)
import SwiftUI

// NARK: - implementation
// MARK: textfield
struct MbFRHackView<ID: Hashable, Field: FirstResponderableField>: NSViewRepresentable {
    private let id: ID
    @Binding private var firstResponder: ID?
//    {
//        didSet {
//            print("First Responder changed to \(String(describing: firstResponder))")
//        }
//    }
    
    private let resignableUserOperations: Field.ResignableUserOperations
    
    init(id: ID, firstResponder: Binding<ID?>, resignableUserOperations: Field.ResignableUserOperations) {
//        print("init")
        self.id = id
        self._firstResponder = firstResponder
        self.resignableUserOperations = resignableUserOperations
    }
    
    func makeNSView(context: Context) -> MbFRHackNSView<Field> {
//        print("makeNSView")
        return MbFRHackNSView(
            isFirstResponder: id == firstResponder,
            eventsAllowedToResignFirstResponder: resignableUserOperations) { focused in
            // change the binding value after the first responder status changed by windows event (NOT changed programmaly)
            if focused {
                if firstResponder != id {
                    firstResponder = id
                }
            }
            else {
                if firstResponder == id {
                    firstResponder = nil
                }
            }
        }
    }
    
    func updateNSView(_ nsView: MbFRHackNSView<Field>, context: Context) {
//        print("updateNSView")
        nsView.update(firstResponder: id == firstResponder, resignableUserOperations: resignableUserOperations)
    }
}

final class MbFRHackNSView<Field: FirstResponderableField>: NSView, FrEventObserver {
    private weak var field: Field? = nil
    private let initialFirstResponderStatus: Bool
    private var resignableUserOperations: Field.ResignableUserOperations
    
    // use the monitor if the first responder changed by the window event (NOT changed programmaly)
    // for example, click outside the field, the text field will resign the first responder
    // if the first responder status changed, the binding value should be changed
    private let firstResponderDidChangedByEvent: (Bool) -> Void
    
    init(
        isFirstResponder: Bool,
        eventsAllowedToResignFirstResponder: Field.ResignableUserOperations,
        firstResponderDidChangedByEvent: @escaping (Bool) -> Void) {
        self.initialFirstResponderStatus = isFirstResponder
        self.resignableUserOperations = eventsAllowedToResignFirstResponder
        self.firstResponderDidChangedByEvent = firstResponderDidChangedByEvent
        super.init(frame: .zero)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
//        Swift.print("viewDidMoveToWindow")
        super.viewDidMoveToWindow()
        
        guard field == nil else { return }
        // this hack view will be as the background of the SwiftUI field (TextField, TextEditor), so here to find the linked SwiftUI field
        field = self.frFindLinkedField()
        
        guard field != nil else { return }
        guard let window = self.window else { return }
        trackRelatedEvents(in: window)
        
        DispatchQueue.main.async { [weak self] in
            if let initialFirstResponder = self?.initialFirstResponderStatus, let events = self?.resignableUserOperations, let tf = self?.field, let window = self?.window {
                self?._update(isFirstResponder: initialFirstResponder, newResignableUserOperations: events, of: tf, in: window)
            }
        }
    }
    
    // setup to observe the events from the window
    // Considering the performance, here attach a coordinator object to window, to make sure only ONE coordinate exists.
    private func trackRelatedEvents(in window: NSWindow) {
        if let coordinator = window.frCoordinator {
            coordinator.add(observer: self)
        }
        else {
            let coordinator = FRWindowEventPublisher(from: self)
            window.frCoordinator = coordinator
        }
    }
    
    // Response to the event from the window
    func frEventDidReceived(event: NSEvent) {
        guard let field = self.field else { return }
        guard let window = self.window else { return }
        
        field.frHandleEvent(event: event, in: window, resignableUserOperations: resignableUserOperations) { result in
            switch result {
            case .resigned:
                self.firstResponderDidChangedByEvent(false)
            case .focused:
                self.firstResponderDidChangedByEvent(true)
            }
        }
    }
    
    // Update the first responder status programmaly
    func update(firstResponder: Bool, resignableUserOperations newResignableUserOperations: Field.ResignableUserOperations) {
        guard let field = self.field, let window = field.window else {
            return
        }
        _update(isFirstResponder: firstResponder, newResignableUserOperations: newResignableUserOperations, of: field, in: window)
    }
    private func _update(isFirstResponder: Bool, newResignableUserOperations: Field.ResignableUserOperations, of field: Field, in window: NSWindow) {
        if self.resignableUserOperations != newResignableUserOperations {
            self.resignableUserOperations = newResignableUserOperations
        }
        
        let alreadyFocused = field.frIsFirstResponder(in: window)
        if alreadyFocused != isFirstResponder {
            if isFirstResponder {
                window.makeFirstResponder(field)
            }
            else {
                window.makeFirstResponder(nil)
            }
        }
    }
}


#endif
