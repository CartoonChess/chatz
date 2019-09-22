//
//  WelcomeViewController.swift
//  Flash Chat
//
//  This is the welcome view controller - the first thign the user sees
//

import UIKit
import Firebase

class WelcomeViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // If we're logged in, automatically:
        if Auth.auth().currentUser != nil {
            //- Get existing permissions for notifications
            Permissions.ask(for: .notification)
            //- Then move to the chat
            performSegue(withIdentifier: "goToChat", sender: nil)
        }
    }

    
    @IBAction func unwindToWelcome(_ unwindSegue: UIStoryboardSegue) {
//        let sourceViewController = unwindSegue.source
        // Use data from the view controller which initiated the unwind segue
    }
    
}
