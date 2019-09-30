//
//  LogInViewController.swift
//  Flash Chat
//
//  This is the view controller where users login


import UIKit
import Firebase
import JGProgressHUD

class LogInViewController: UIViewController {

    //Textfields pre-linked with IBOutlets
    @IBOutlet var emailTextfield: UITextField!
    @IBOutlet var passwordTextfield: UITextField!
    
    @IBAction func logInPressed(_ sender: AnyObject) {
        let email = emailTextfield.text ?? ""
        let password = passwordTextfield.text ?? ""
        
        // Show spinner
        let spinner = JGProgressHUD()
        spinner.show(in: self.view)
        
        let authorizer = Auth.auth()
        authorizer.signIn(withEmail: email, password: password) { (result, error) in
            guard let result = result else {
                print("Failed to log in: \(error?.localizedDescription ?? "unknown")")
                spinner.indicatorView = JGProgressHUDErrorIndicatorView()
                spinner.dismiss(afterDelay: 1)
                return
            }
            
            print("Logged in with email \(email) (ID \(result.user.uid)).")
            
            // Update notifications token if this device is already registered
            Permissions.didAsk(for: .notification) { (didAsk) in
                if didAsk {
                    guard let user = authorizer.currentUser else {
                        print("❌ Couldn't update token on login because current user couldn't be found.")
                        return
                    }
//                    Users.updateMessagingToken(for: user)
                    user.updateNotificationTokens()
                }
            }
            
            spinner.dismiss()
            self.performSegue(withIdentifier: "goToContacts", sender: self)
        }
    }
    
}  
