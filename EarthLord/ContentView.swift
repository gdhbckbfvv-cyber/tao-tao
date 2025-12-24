//
//  ContentView.swift
//  EarthLord
//
//  Created by Zhuanz密码0000 on 12/24/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")

                Spacer()
                    .frame(height: 40)

                Text("Developed by Claude")
                    .font(.headline)
                    .foregroundColor(.blue)

                Spacer()
                    .frame(height: 30)

                NavigationLink(destination: TestView()) {
                    Text("进入测试页")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
