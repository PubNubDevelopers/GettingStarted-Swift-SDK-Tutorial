//
//  MessageInput.swift
//  Getting Started Swift Chat
//
//  Created by Darryn Campbell on 27/07/2022.
//

import SwiftUI

struct MessageInput: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var messageText: String = ""
    @FocusState private var messageIsFocused: Bool
    
    var body: some View {
        HStack {
            TextField("Message", text: $messageText).focused($messageIsFocused).disableAutocorrection(true)
            Button("Send") {
                print("Button pressed " + messageText)
                messageIsFocused = false;
                if(messageText == "")
                {
                    return;
                }
                
                //  Publish message to PubNub using the pre-defined channel for this group chat
                //  Attach our device Id as meta info to the message, this is used by other platforms
                //  if the history API does not return the UUID
                viewModel.pubnub?.publish(
                    channel: viewModel.channel ?? "default_channel",
                    message: messageText,
                    shouldStore: true,
                    meta: ["deviceId", viewModel.deviceId ?? "defaultId"]
                ) { result in
                    switch result {
                    case .success(_):
                        //  Message successfully sent
                        break;
                    case let .failure(error):
                        print("publish failed: \(error.localizedDescription)")
                    }
                }
                messageText = ""
            }
        }.padding()
    }
}

struct MessageInput_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ChatViewModel()
        MessageInput(viewModel: viewModel)
    }
}

