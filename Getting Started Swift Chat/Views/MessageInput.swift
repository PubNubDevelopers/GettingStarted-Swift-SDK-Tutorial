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
                
                //  Publish message to PubNub
                
                viewModel.pubnub?.publish(
                    channel: viewModel.channel ?? "default_channel",
                    message: messageText,
                    shouldStore: true,
                    meta: ["deviceID", viewModel.deviceId ?? "defaultId"]
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
            
        }
    }
}

/*
struct MessageInput_Previews: PreviewProvider {
    static var previews: some View {
        MessageInput()
    }
}
 */
