//
//  ViewController.swift
//  InteractiveNavigationControllerTransition+UIViewPropertyAnimator
//
//  Created by starikova on 2/20/20.
//  Copyright © 2020 starikova. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.addCustomTransitioning()
        
        view.backgroundColor = .blue
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }
    
    func setupNavigationBar() {
        let item = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showDetail))
        navigationItem.rightBarButtonItem = item
    }
    
    @objc func showDetail() {
        let detailViewController = DetailViewController()
        navigationController?.pushViewController(detailViewController, animated: true)
    }
}

class DetailViewController: UIViewController {
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
    }
       
}
extension UINavigationController {
    // 1
    static private var coordinatorHelperKey = "UINavigationController.TransitionCoordinatorHelper"

    // 2
    var transitionCoordinatorHelper: InteractiveNavigationTransitionController? {
        return objc_getAssociatedObject(self, &UINavigationController.coordinatorHelperKey) as? InteractiveNavigationTransitionController
    }

    func addCustomTransitioning() {
        // 3
        var object = objc_getAssociatedObject(self, &UINavigationController.coordinatorHelperKey)

        guard object == nil else {
            return
        }

        object = InteractiveNavigationTransitionController(navigationController: self)
        let nonatomic = objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
        objc_setAssociatedObject(self, &UINavigationController.coordinatorHelperKey, object, nonatomic)

        // 4
        delegate = object as? InteractiveNavigationTransitionController
    }
}

