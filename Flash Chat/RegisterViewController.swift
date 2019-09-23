//
//  RegisterViewController.swift
//  Flash Chat
//
//  This is the View Controller which registers new users with Firebase
//

import UIKit
import Firebase
import JGProgressHUD

class RegisterViewController: UIViewController {

    
    //Pre-linked IBOutlets

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet var emailTextfield: UITextField!
    @IBOutlet var passwordTextfield: UITextField!
    
//    var spinner: JGProgressHUD?
    
    
    // MARK: - Methods
  
    @IBAction func registerPressed(_ sender: AnyObject) {
        let name = nameTextField.text ?? "(no name)"
        let email = emailTextfield.text ?? ""
        let password = passwordTextfield.text ?? ""
        
        // Show loading spinner
        let spinner = JGProgressHUD()
        spinner.show(in: self.view)
        
        // Register user
        createUser(named: name, email: email, password: password) { (error) in
            if let error = error {
                print(error)
                spinner.indicatorView = JGProgressHUDErrorIndicatorView()
                spinner.dismiss(afterDelay: 1)
                // TODO: Handle profileName/userDocument errors
                //- Alert and move to login, which will try updating name/document again
            } else {
                // Update notifications token if this device is already registered
                Permissions.didAsk(for: .notification) { (didAsk) in
                    if didAsk {
                        guard let user = Auth.auth().currentUser else {
                            print("❌ Couldn't update token on login because current user couldn't be found.")
                            return
                        }
//                        Users.updateMessagingToken(for: user)
                        user.updateNotificationTokens()
                    }
                }
                // On successful registration, push to chat window
                spinner.dismiss()
                self.performSegue(withIdentifier: "goToChat", sender: self)
            }
        }
        
    }
    
    func createUser(named name: String, email: String, password: String, completion: @escaping (String?) -> Void) {
        let authorizer = Auth.auth()
        authorizer.createUser(withEmail: email, password: password) { (result, error) in
            guard let result = result else {
//                print("❌ Error registering user: \(error?.localizedDescription ?? "unknown")")
//                self.spinner?.indicatorView = JGProgressHUDErrorIndicatorView()
//                self.spinner?.dismiss(afterDelay: 1)
                completion("❌ Error registering user: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            let user = result.user
            print("👋 User with email \(email) registered (ID \(user.uid)).")
            // Add user name as displayName in Auth
            user.setProfileName(name) { (error) in completion(error) }
            
//            UserProfile.setProfileName(name, for: user, updateUserDocument: true) { (error) in
////                if let error = error {
//                    completion(error)
////                    return
////                }
//            }
        }
    }
    
//    func setProfileName(_ name: String, for user: User, completion: @escaping (String?) -> Void) {
//        let setNameRequest = user.createProfileChangeRequest()
//        setNameRequest.displayName = name
//        setNameRequest.commitChanges { (error) in
//            if let error = error {
//                completion("❌ Error updating users collection: \(error.localizedDescription)")
//                return
//            }
//
//            self.addUserDocument(for: user) { (error) in
////                if let error = error {
//                    completion(error)
////                    return
////                }
//            }
//        }
//    }
//
//    /// Add user to users collection, so others can access their profile info
//    func addUserDocument(for user: User, completion: @escaping (String?) -> Void) {
//        guard let name = user.displayName,
//            let email = user.email else {
//            completion("❌ Couldn't get user name or email to add user document.")
//        }
//
//        let users = Firestore.firestore().collection("users")
//        let uid = user.uid
//        let user = UserProfile(id: uid, email: email, name: name)
//        // Document ID matches user ID
//        users.document(uid).setData(user.document) { (error) in
//            if let error = error {
//                completion("❌ Error updating users collection: \(error.localizedDescription)")
//                return
//            }
//            print("👋 User profile added to users collection.")
//            completion(nil)
//        }
//    }
    
    
}
