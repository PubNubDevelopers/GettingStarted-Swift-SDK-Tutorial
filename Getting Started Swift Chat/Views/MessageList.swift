//
//  MessageList.swift
//  Getting Started Swift Chat
//
//  Created by Darryn Campbell on 26/07/2022.
//

import SwiftUI

struct MessageList: View {
    @ObservedObject var viewModel: ChatViewModel
    var body: some View {
        ScrollViewReader { scrollView in
            //  Note the timetoken is not guaranteed to be unique for very high volumes and simultaneous messages
            List(self.viewModel.messages, id: \.timetoken) { message in
                MessageRow(message: message, viewModel: viewModel)
            }.onChange(of: self.viewModel.messages.count) { _ in
                scrollView.scrollTo(self.viewModel.messages[self.viewModel.messages.count - 1].timetoken)
            }
        }
    }
}

struct MessageList_Previews: PreviewProvider {
    static var previews: some View {
        let message = Message(message: "Test Message", senderDeviceId: "sim123", timetoken: "16590086742278148", humanReadableTime: "Jul 28, 2022 at 12:44:34 PM")
        let viewModel: ChatViewModel = ChatViewModel()
        viewModel.messages = [message];
        viewModel.memberNames["sim123"] = "Simulator 1"
        return MessageList(viewModel: viewModel)
    }
}
