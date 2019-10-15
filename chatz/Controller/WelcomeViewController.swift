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
//        if let user = Auth.auth().currentUser {
//            user.joinGroupChat()
            //- Get existing permissions for notifications
            Permissions.ask(for: .notification)
            //- Then move to the chat
//            performSegue(withIdentifier: "goToChat", sender: nil)
            performSegue(withIdentifier: "ContactsListSegue", sender: nil)
        } else {
            // TODO: This should be asked in a more proper place
            /*
             We need to revise how we ask for permissions… we should be doing it at login/register success as well. Ideally it will happen before the contacts list is shown. Need to figure out if we should even be using didRequestPermission, instead using ask() always?
             */
            Permissions.ask(for: .notification)
        }
    }

    
    @IBAction func unwindToWelcome(_ unwindSegue: UIStoryboardSegue) {
//        let sourceViewController = unwindSegue.source
        // Use data from the view controller which initiated the unwind segue
    }
    
}
