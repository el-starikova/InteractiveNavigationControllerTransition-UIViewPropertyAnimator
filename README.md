How to create a fully interactive and interruptible custom UINavigationController transition using UIViewPropertyAnimator!
--------------------------------------------------------------------------------------------------------------------------

### The challenge

Our goal is to provide a fully interactive and interruptible `present` and `dismiss` animation between the view controllers inside a navigation stack.

### Let’s code!

First of all, we need to make a basic `present` and `dismiss` animation. To do this, let’s create an object that manages the transition from start to finish. This object will live the lifetime of the transition and is responsible for driving the interactivity and animation. It utilizes `UIViewPropertyAnimator` to smoothly interact and interrupt the transition.

```swift
final class InteractiveModalTransitionDriver: NSObject {
    
    // 1
    let transitionContext: UIViewControllerContextTransitioning
    
    // 2
    private let operation: UINavigationController.Operation
    
    init(operation: UINavigationController.Operation, context: UIViewControllerContextTransitioning) {
        self.transitionContext = context
        self.operation = operation

        super.init()
    }
}

```

1. The given transition context for the transition.
2. Property that indicates if the animator is responsible for a push or a pop navigation.

### Creating the Transition Animation

When animating the main view, the basic actions we take to configure our animation are the same. We need to fetch the objects and data from the transitioning context object to create our animation.

```swift
final class InteractiveModalTransitionDriver: NSObject {
    
    ...
    
    init(operation: UINavigationController.Operation, context: UIViewControllerContextTransitioning) {
    
        ...
    
        super.init()
        
        let fromView = context.view(forKey: .from)!
        let toView = context.view(forKey: .to)!
        let containerView = context.containerView
        
        let dimmingView = UIView()
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.66)
        dimmingView.frame = containerView.bounds
        dimmingView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
    }
}
```

Now let’s set the starting position for the controller’s views and the starting alpha value for the dimming view.

```swift
final class InteractiveModalTransitionDriver: NSObject {
    
    ...
    
    init(operation: UINavigationController.Operation, context: UIViewControllerContextTransitioning) {

        ...
    
        super.init()
        
        ...
        
        fromView.frame = initialFrame(for: .from)
        toView.frame = initialFrame(for: .to)
        dimmingView.alpha = operation == .push ? 0.0 : 1.0
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
}
```

After that, we need to add the views involved in the transition as a subview of the `containerView`. Depending on the navigation action, we either add the destination (`toView`) view to our container or add it below the source (`fromView`) view.

```swift
final class InteractiveModalTransitionDriver: NSObject {
    
    ...
    
    init(operation: UINavigationController.Operation, context: UIViewControllerContextTransitioning) {

        ...
    
        super.init()
        
        ...
        
        if operation == .push {
            containerView.addSubview(dimmingView)
            containerView.addSubview(toView)
        } else {
            containerView.addSubview(toView)
            containerView.addSubview(dimmingView)
            containerView.addSubview(fromView)
        }
    }
    
    ...
}
```

Now we need to add and setup the `UIViewPropertyAnimator` for our transition.

```swift
final class InteractiveModalTransitionDriver: NSObject {
    
    ...
    
    var transitionAnimator: UIViewPropertyAnimator!
    var isInteractive: Bool { return transitionContext.isInteractive }
    private var frameAnimator: UIViewPropertyAnimator?
    
    init(operation: UINavigationController.Operation, context: UIViewControllerContextTransitioning) {

        ...
    
        super.init()
        
        ...
        
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
        // Create a property animator to animate view's frame change
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
    
    ...
}
```

### Performing the Transition Animation

To perform the animation, we will create an object that conforms to `UINavigationControllerDelegate` and `UIViewControllerAnimatedTransitioning`.

```swift
final class InteractiveNavigationTransitionController: NSObject {
    
    weak var navigationController: UINavigationController?
    var operation: UINavigationController.Operation = .none
    var transitionDriver: InteractiveModalTransitionDriver?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
        
        navigationController.delegate = self
    }
}

extension InteractiveNavigationTransitionController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        // Remember the direction of the transition (.push or .pop)
        self.operation = operation
        
        // Return ourselves as the animation controller for the pending transition
        return self
    }
}

extension InteractiveNavigationTransitionController: UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return TimeInterval(UINavigationController.hideShowBarDuration)
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        // Create our helper object to manage the transition for the given transitionContext.
        transitionDriver = InteractiveModalTransitionDriver(operation: operation, context: transitionContext)
    }
    
    func animationEnded(_ transitionCompleted: Bool) {
        
        // Clean up our helper object and any additional state
        transitionDriver = nil
        operation = .none
    }
}
```

To be able to easily attach our custom transition to any `UINavigationController`​, we need to create the UINavigationController extension. An explanation of each part of the extension is below.

```swift
extension UINavigationController {
    // 1
    static private var modalTransitionControllerKey = "UINavigationController.InteractiveNavigationTransitionController"

    // 2
    var modalTransitionController: InteractiveNavigationTransitionController? {
        return objc_getAssociatedObject(self, &UINavigationController.modalTransitionControllerKey) as? InteractiveNavigationTransitionController
    }

    func addModalTransitioning() {
        // 3
        var object = objc_getAssociatedObject(self, &UINavigationController.modalTransitionControllerKey)

        guard object == nil else {
            return
        }

        object = InteractiveNavigationTransitionController(navigationController: self)
        let nonatomic = objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
        objc_setAssociatedObject(self, &UINavigationController.modalTransitionControllerKey, object, nonatomic)

        // 4
        delegate = object as? InteractiveNavigationTransitionController
    }
}
```

1. A static key that will be used to associate an object.
2. A computed property that will return our associated InteractiveNavigationTransitionController object.
3. Creation of the instance of InteractiveNavigationTransitionController and association it with the mentioned key.
4. Setting the associated object as a delegate of UINavigationController.

To make things work, let’s just call our extension’s method on any navigation controller we want `navigationController.addModalTransitioning()`.

The next step is supporting interactive transitions as well.

### Adding Interactivity to Our Transition

Let’s setup the interaction by adding a pan gesture recognizer used to initiate the custom interactive pop transition.

```swift
final class InteractiveNavigationTransitionController: NSObject {
    
    ...
    
    var initiallyInteractive: Bool = false
    var panGestureRecognizer: UIPanGestureRecognizer = UIPanGestureRecognizer()

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
        
        navigationController.delegate = self
        configurePanGestureRecognizer()
    }
    
    func configurePanGestureRecognizer() {
        panGestureRecognizer.delegate = self
        panGestureRecognizer.maximumNumberOfTouches = 1
        panGestureRecognizer.addTarget(self, action: #selector(initiateTransitionInteractively(_:)))
        navigationController?.view.addGestureRecognizer(panGestureRecognizer)
        
        guard let interactivePopGestureRecognizer = navigationController?.interactivePopGestureRecognizer else { return }
        panGestureRecognizer.require(toFail: interactivePopGestureRecognizer)
    }
    
    @objc func initiateTransitionInteractively(_ panGestureRecognizer: UIPanGestureRecognizer) {
        if panGestureRecognizer.state == .began && transitionDriver == nil {
            initiallyInteractive = true

            let _ = navigationController?.popViewController(animated: true)
        }
    }
}

extension InteractiveNavigationTransitionController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let transitionDriver = self.transitionDriver else {
            let translation = panGestureRecognizer.translation(in: panGestureRecognizer.view)
            return translation.isVertical && (navigationController?.viewControllers.count ?? 0 > 1)
        }

        return transitionDriver.isInteractive
    }
}

extension CGPoint {
    var isVertical: Bool {
        return (y > 0) && (abs(y) > abs(x))
    }
}
```

Convenience math operators.

```swift
import QuartzCore

func clip<T : Comparable>(_ x0: T, _ x1: T, _ v: T) -> T {
    return max(x0, min(x1, v))
}

func lerp<T : FloatingPoint>(_ v0: T, _ v1: T, _ t: T) -> T {
    return v0 + (v1 - v0) * t
}


func -(lhs: CGPoint, rhs: CGPoint) -> CGVector {
    return CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
}

func -(lhs: CGPoint, rhs: CGVector) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.dx, y: lhs.y - rhs.dy)
}

func -(lhs: CGVector, rhs: CGVector) -> CGVector {
    return CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
}

func +(lhs: CGPoint, rhs: CGPoint) -> CGVector {
    return CGVector(dx: lhs.x + rhs.x, dy: lhs.y + rhs.y)
}

func +(lhs: CGPoint, rhs: CGVector) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
}

func +(lhs: CGVector, rhs: CGVector) -> CGVector {
    return CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
}

func *(left: CGVector, right:CGFloat) -> CGVector {
    return CGVector(dx: left.dx * right, dy: left.dy * right)
}

extension CGPoint {
    var vector: CGVector {
        return CGVector(dx: x, dy: y)
    }
}

extension CGVector {
    var magnitude: CGFloat {
        return sqrt(dx*dx + dy*dy)
    }
    
    var point: CGPoint {
        return CGPoint(x: dx, y: dy)
    }
    
    func apply(transform t: CGAffineTransform) -> CGVector {
        return point.applying(t).vector
    }
}

```

```swift
final class InteractiveModalTransitionDriver: NSObject {
    
    ...
    
    private let panGestureRecognizer: UIPanGestureRecognizer
    
    init(operation: UINavigationController.Operation, context: UIViewControllerContextTransitioning, panGestureRecognizer panGesture: UIPanGestureRecognizer) {

        ...
        
        self.panGestureRecognizer = panGesture
        super.init()
        
        // Add ourselves as a target of the pan gesture
        self.panGestureRecognizer.addTarget(self, action: #selector(updateInteraction(fromGestureRecognizer:)))
        
        ...
        
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
    
    ...
}
```

```swift
extension InteractiveNavigationTransitionController: UINavigationControllerDelegate {
    
    ...
    
    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {

        // Return ourselves as the interaction controller for the pending transition
        return self
    }
}

extension InteractiveNavigationTransitionController: UIViewControllerInteractiveTransitioning {

    func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {

        // Create our helper object to manage the transition for the given transitionContext.
        transitionDriver = InteractiveModalTransitionDriver(operation: operation, context: transitionContext, panGestureRecognizer: panGestureRecognizer)
    }

    var wantsInteractiveStart: Bool {

        // Determines whether the transition begins in an interactive state
        return initiallyInteractive
    }
}

extension InteractiveNavigationTransitionController: UIViewControllerAnimatedTransitioning {
    
    ...
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) { }
    
    func animationEnded(_ transitionCompleted: Bool) {
        
        // Clean up our helper object and any additional state
        transitionDriver = nil
        initiallyInteractive = false
        operation = .none
    }
    
    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {

        // The transition driver (helper object), creates the UIViewPropertyAnimator (transitionAnimator)
        // to be used for this transition. It must live the lifetime of the transitionContext.
        return (transitionDriver?.transitionAnimator)!
    }
}
```

### Now we have a fully interactive custom transition between the view controllers inside a navigation stack!

