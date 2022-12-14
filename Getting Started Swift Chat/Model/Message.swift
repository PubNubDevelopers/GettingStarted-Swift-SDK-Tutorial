//
//  SwiftChat.swift
//  Getting Started Swift Chat
//
//  Created by Darryn Campbell on 26/07/2022.
//

import Foundation

//  Represents a messages, used in the viewModel to display messages
struct Message: Hashable {
    var message: String = ""
    var senderDeviceId: String = ""
    var timetoken: String = ""
    var humanReadableTime: String = ""
}
