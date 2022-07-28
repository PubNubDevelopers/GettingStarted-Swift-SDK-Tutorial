//
//  MessageRow.swift
//  Getting Started Swift Chat
//
//  Created by Darryn Campbell on 26/07/2022.
//

import SwiftUI

struct MessageRow: View {
    var message: Message
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        HStack {
            VStack (alignment: .leading){
                Text(self.viewModel.resolveFriendlyName(deviceId: message.senderDeviceId ))
                Text(message.message).fontWeight(.bold)
                Text(message.humanReadableTime).font(.footnote).frame(maxWidth: .infinity, alignment: .trailing).foregroundColor(Color.gray)
            }
            .frame(minWidth: 0,
                   maxWidth: .infinity)
            Spacer()
        }
    }
}


struct MessageRow_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ChatViewModel()
        let message = Message(message: "Test Message", senderDeviceId: "Simulator 1", timetoken: "16590086742278148", humanReadableTime: "Jul 28, 2022 at 12:44:34 PM")
        MessageRow(message: message, viewModel: viewModel)
            .previewLayout(.fixed(width: 300, height: 70))
        
    }
}

