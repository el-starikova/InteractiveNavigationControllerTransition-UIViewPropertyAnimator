//
//  InteractiveModalTransitionDriver.swift
//  InteractiveNavigationControllerTransition+UIViewPropertyAnimator
//
//  Created by starikova on 2/20/20.
//  Copyright © 2020 starikova. All rights reserved.
//

/*
     Abstract:
     The InteractiveModalTransitionDriver class manages the transition from start to finish. This object will live the lifetime of the transition, and is resposible for driving the interactivity and animation. It utilizes UIViewPropertyAnimator to smoothly interact and interrupt the transition.
 */

import UIKit

final class InteractiveModalTransitionDriver: NSObject {
    
    var transitionAnimator: UIViewPropertyAnimator!
    let transitionContext: UIViewControllerContextTransitioning
    var isInteractive: Bool { return transitionContext.isInteractive }
    
    private let operation: UINavigationController.Operation
    private let panGestureRecognizer: UIPanGestureRecognizer
    private var frameAnimator: UIViewPropertyAnimator?
    
    init(operation: UINavigationController.Operation, context: UIViewControllerContextTransitioning, panGestureRecognizer panGesture: UIPanGestureRecognizer) {
        self.transitionContext = context
        self.operation = operation
        self.panGestureRecognizer = panGesture
        super.init()
        
        // Retrieve the views involved in the transition.
        let fromView = context.view(forKey: .from)!
        let toView = context.view(forKey: .to)!
        let containerView = context.containerView
        
        // Add ourselves as a target of the pan gesture
        self.panGestureRecognizer.addTarget(self, action: #selector(updateInteraction(fromGestureRecognizer:)))
        
        // Create a dimming view and animate the alpha in the transition animator
        let dimmingView = UIView()
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.66)
        dimmingView.frame = containerView.bounds
        dimmingView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        
        // Ensure transition views has the correct size and position
        fromView.frame = initialFrame(for: .from)
        toView.frame = initialFrame(for: .to)
        dimmingView.alpha = operation == .push ? 0.0 : 1.0
        
        // Insert transition views into the transition container view
        if operation == .push {
            containerView.addSubview(dimmingView)
            containerView.addSubview(toView)
        } else {
            containerView.addSubview(toView)
            containerView.addSubview(dimmingView)
            containerView.addSubview(fromView)
        }
        
        // Add animations and completion to the transition animator
        setupTransitionAnimator({
            dimmingView.alpha = operation == .push ? 1.0 : 0.0
            toView.frame = self.finalFrame(for: .to)
        }) { (position) in
            // Remove all transition views
            dimmingView.removeFromSuperview()
        }

        if !context.isInteractive {
            animate(.end)
        }
    }
    
    // MARK: UIViewPropertyAnimator Setup

    /// UIKit calls startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning)
    /// on our interaction controller (InteractiveNavigationTransitionController). The InteractiveNavigationTransitionDriver (self) is
    /// then created with the transitionContext to manage the transition. It calls this func from Init().
    func setupTransitionAnimator(_ transitionAnimations: @escaping ()->(), transitionCompletion: @escaping (UIViewAnimatingPosition)->()) {

        // The duration of the transition, if uninterrupted
        let transitionDuration = InteractiveModalTransitionDriver.animationDuration()

        // Create a UIViewPropertyAnimator that lives the lifetime of the transition
        transitionAnimator = UIViewPropertyAnimator(duration: transitionDuration, curve: .easeOut, animations: transitionAnimations)

        transitionAnimator.addCompletion { [unowned self] (position) in
            // Call the supplied completion
            transitionCompletion(position)

            // Inform the transition context that the transition has completed
            let completed = (position == .end)
            self.transitionContext.completeTransition(completed)
        }
    }

    class func animationDuration() -> TimeInterval {
        return InteractiveModalTransitionDriver.propertyAnimator().duration
    }

    class func propertyAnimator(initialVelocity: CGVector = .zero) -> UIViewPropertyAnimator {
        let timingParameters = UISpringTimingParameters(mass: 2.5, stiffness: 2000, damping: 95, initialVelocity: initialVelocity)
        return UIViewPropertyAnimator(duration: TimeInterval(UINavigationController.hideShowBarDuration), timingParameters:timingParameters)
    }
    
    private func timingCurveVelocity() -> CGVector {
        return .zero
    }
    
    func animate(_ toPosition: UIViewAnimatingPosition) {
        // Create a property animator to animate each image's frame change
        let frameAnimator = InteractiveModalTransitionDriver.propertyAnimator(initialVelocity: timingCurveVelocity())
        frameAnimator.addAnimations {
            if self.operation == .pop {
                if let fromView = self.transitionContext.view(forKey: .from)  {
                    let frame = toPosition == .end ? self.finalFrame(for: .from) : self.initialFrame(for: .from)
                    fromView.frame = frame
                }
            }
        }

        // Start the property animator and keep track of it
        frameAnimator.startAnimation()
        self.frameAnimator = frameAnimator

        // Reverse the transition animator if we are returning to the start position
        transitionAnimator.isReversed = (toPosition == .start)

        // Start or continue the transition animator (if it was previously paused)
        if transitionAnimator.state == .inactive {
            transitionAnimator.startAnimation()
        } else {
            // Calculate the duration factor for which to continue the animation.
            // This has been chosen to match the duration of the property animator created above

            let durationFactor = CGFloat(frameAnimator.duration / transitionAnimator.duration)
            transitionAnimator.continueAnimation(withTimingParameters: nil, durationFactor: durationFactor)
        }
    }
    
    func initialFrame(for key: UITransitionContextViewKey) -> CGRect {
        let context = transitionContext
        var initialFrame = context.containerView.frame
        switch key {
        case .from:
            return initialFrame
        case .to:
            if operation == .push {
                initialFrame.origin.y = initialFrame.maxY
            }
            return initialFrame
        default:
            return .zero
        }
    }

    func finalFrame(for key: UITransitionContextViewKey) -> CGRect {
        let context = transitionContext
        var initialFrame = context.containerView.frame
        switch key {
        case .from:
            if operation == .pop {
                initialFrame.origin.y = initialFrame.maxY
            }
            return initialFrame
        case .to:
            return initialFrame
        default:
            return .zero
        }
    }
    
    @objc func updateInteraction(fromGestureRecognizer gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
            case .began, .changed:
                // Ask the gesture recognizer for it's translation
                let translation = gestureRecognizer.translation(in: transitionContext.containerView)
                // Calculate the percent complete
                let percentComplete = transitionAnimator.fractionComplete + progressStepFor(translation: translation)
                // Update the transition animator's fractionCompete to scrub it's animations
                transitionAnimator.fractionComplete = percentComplete
                // Inform the transition context of the updated percent complete
                transitionContext.updateInteractiveTransition(percentComplete)

                // Update each transition item for the
                updateFrameForInteractive(translation: translation)

                // Reset the gestures translation
                gestureRecognizer.setTranslation(CGPoint.zero, in: transitionContext.containerView)
            case .ended, .cancelled:
                // End the interactive phase of the transition
                endInteraction()
            default: break
        }
    }

    func endInteraction() {
        // Ensure the context is currently interactive
        guard transitionContext.isInteractive else { return }

        // Inform the transition context of whether we are finishing or cancelling the transition
        let completionPosition = self.completionPosition()
        if completionPosition == .end {
            transitionContext.finishInteractiveTransition()
        } else {
            transitionContext.cancelInteractiveTransition()
        }

        // Begin the animation phase of the transition to either the start or finsh position
        animate(completionPosition)
    }
    
    private func completionPosition() -> UIViewAnimatingPosition {
        let completionThreshold: CGFloat = 0.2
        let flickMagnitude: CGFloat = 1200 //pts/sec
        let velocity = panGestureRecognizer.velocity(in: transitionContext.containerView).vector
        let isFlick = (velocity.magnitude > flickMagnitude)
        let isFlickDown = isFlick && (velocity.dy > 0.0)
        let isFlickUp = isFlick && (velocity.dy < 0.0)

        if (operation == .push && isFlickUp) || (operation == .pop && isFlickDown) {
            return .end
        } else if (operation == .push && isFlickDown) || (operation == .pop && isFlickUp) {
            return .start
        } else if transitionAnimator.fractionComplete > completionThreshold {
            return .end
        } else {
            return .start
        }
    }

    private func progressStepFor(translation: CGPoint) -> CGFloat {
        return (operation == .push ? -1.0 : 1.0) * translation.y / (transitionContext.containerView.bounds.maxY * 1.1)
    }

    private func updateFrameForInteractive(translation: CGPoint) {
        if let fromView = transitionContext.view(forKey: .from) {
            fromView.frame.origin.y = fromView.frame.origin.y + translation.y
        }
    }
}
