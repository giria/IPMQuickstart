//
//  ViewController.swift
//  IPMQuickstart
//
//  Created by Kevin Whinnery on 12/9/15.
//  Copyright © 2015 Twilio. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
  // MARK: IP messaging memebers
  var client: TwilioIPMessagingClient? = nil
  var generalChannel: TWMChannel? = nil
  var identity = ""
  var messages: [TWMMessage] = []
  
  // MARK: UI controls
  @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var textField: UITextField!
  @IBOutlet weak var tableView: UITableView!

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    // Return number of rows in the table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messages.count
    }
    
    // Create table view rows
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)    -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath)
        let message = self.messages[(indexPath as NSIndexPath).row]
        
        // Set table cell values
        cell.detailTextLabel?.text = message.author
        cell.textLabel?.text = message.body
        cell.selectionStyle = .none
        return cell
    }
    
    
    
    override func viewDidLoad() {
    super.viewDidLoad()
    
    // Fetch Access Token form the server and initialize IPM Client - this assumes you are running
    // the PHP starter app on your local machine, as instructed in the quick start guide
    let deviceId = UIDevice.current.identifierForVendor!.uuidString
    let urlString = "http://555a02ae.ngrok.io/token.php?device=\(deviceId)"
    
    // Get JSON from server
    let config = URLSessionConfiguration.default
    let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    let url = URL(string: urlString)
    let request  = NSMutableURLRequest(url: url!)
    request.httpMethod = "GET"
    
    // Make HTTP request
    session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
      if (data != nil) {
        // Parse result JSON
        let json = JSON(data: data!)
        let token = json["token"].stringValue
        self.identity = json["identity"].stringValue
        // Set up Twilio IPM client
        let accessManager = TwilioAccessManager.init(token: token, delegate: nil)
        self.client = TwilioIPMessagingClient(accessManager: accessManager, properties: nil, delegate: self)
        
        // Update UI on main thread
        DispatchQueue.main.async {
          self.navigationItem.prompt = "Logged in as \"\(self.identity)\""
        }
      } else {
        print("Error fetching token :\(error)")
      }
    }).resume()
    
    // Listen for keyboard events and animate text field as necessary
    NotificationCenter.default.addObserver(self,
      selector: #selector(ViewController.keyboardWillShow(_:)),
      name:NSNotification.Name.UIKeyboardWillShow,
      object: nil);
    
    NotificationCenter.default.addObserver(self,
      selector: #selector(ViewController.keyboardDidShow(_:)),
      name:NSNotification.Name.UIKeyboardDidShow,
      object: nil);
    
    NotificationCenter.default.addObserver(self,
      selector: #selector(ViewController.keyboardWillHide(_:)),
      name:NSNotification.Name.UIKeyboardWillHide,
      object: nil);
    
    // Set up UI controls
    self.tableView.rowHeight = UITableViewAutomaticDimension
    self.tableView.estimatedRowHeight = 66.0
    self.tableView.separatorStyle = .none
  }
  
  // MARK: Keyboard Dodging Logic
  
  func keyboardWillShow(_ notification: Notification) {
    let keyboardHeight = ((notification as NSNotification).userInfo?[UIKeyboardFrameBeginUserInfoKey] as AnyObject).cgRectValue.height
    UIView.animate(withDuration: 0.1, animations: { () -> Void in
      self.bottomConstraint.constant = keyboardHeight + 10
      self.view.layoutIfNeeded()
    })
  }
  
  func keyboardDidShow(_ notification: Notification) {
    self.scrollToBottomMessage()
  }
  
  func keyboardWillHide(_ notification: Notification) {
    UIView.animate(withDuration: 0.1, animations: { () -> Void in
      self.bottomConstraint.constant = 20
      self.view.layoutIfNeeded()
    })
  }
  
  // MARK: UI Logic
  
  // Dismiss keyboard if container view is tapped
  @IBAction func viewTapped(_ sender: AnyObject) {
    self.textField.resignFirstResponder()
  }
  
  // Scroll to bottom of table view for messages
  func scrollToBottomMessage() {
    if self.messages.count == 0 {
      return
    }
    let bottomMessageIndex = IndexPath(row: self.tableView.numberOfRows(inSection: 0) - 1,
      section: 0)
    self.tableView.scrollToRow(at: bottomMessageIndex, at: .bottom,
      animated: true)
  }

}




// MARK: Twilio IP Messaging Delegate
extension ViewController: TwilioIPMessagingClientDelegate {
  func ipMessagingClient(_ client: TwilioIPMessagingClient!, synchronizationStatusChanged status: TWMClientSynchronizationStatus) {
    if status == .completed {
      // Join (or create) the general channel
      let defaultChannel = "general"
      
      self.generalChannel = client.channelsList().channel(withUniqueName: defaultChannel)
      if let generalChannel = self.generalChannel {
        generalChannel.join(completion: { result in
          print("Channel joined with result \(result)")
        })
      } else {
        // Create the general channel (for public use) if it hasn't been created yet
        client.channelsList().createChannel(options: [TWMChannelOptionFriendlyName: "General Chat Channel", TWMChannelOptionType: TWMChannelType.public.rawValue], completion: { (result, channel) -> Void in
          if (result?.isSuccessful())! {
            self.generalChannel = channel
            self.generalChannel?.join(completion: { result in
              self.generalChannel?.setUniqueName(defaultChannel, completion: { result in
                print("channel unqiue name set")
              })
            })
          }
        })
      }
    }
  }
  
  // Called whenever a channel we've joined receives a new message
  func ipMessagingClient(_ client: TwilioIPMessagingClient!, channel: TWMChannel!,
    messageAdded message: TWMMessage!) {
      self.messages.append(message)
      self.tableView.reloadData()
      DispatchQueue.main.async {
        if self.messages.count > 0 {
          self.scrollToBottomMessage()
        }
      }
  }
}

// MARK: UITextField Delegate
extension ViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    let msg = self.generalChannel?.messages.createMessage(withBody: textField.text!)
    self.generalChannel?.messages.send(msg) { result in
      textField.text = ""
      textField.resignFirstResponder()
    }
    return true
  }
}





