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
                
                //  TUTORIAL: STEP 2C CODE GOES HERE
                
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

