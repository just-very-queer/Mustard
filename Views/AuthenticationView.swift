//
//  AuthenticationView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on [Date].
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Mustard")
                .font(.largeTitle)
                .bold()

            Text("Please authenticate to continue.")
                .multilineTextAlignment(.center)
                .padding()

            Button(action: {
                Task {
                    await authViewModel.authenticate()
                }
            }) {
                if authViewModel.isAuthenticating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                } else {
                    Text("Authenticate")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .disabled(authViewModel.isAuthenticating)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .alert(item: $authViewModel.alertError) { (error: AppError) in
            Alert(title: Text("Error"),
                  message: Text(error.message),
                  dismissButton: .default(Text("OK")))
        }
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        // Initialize PreviewService
        let previewService = PreviewService()
        
        // Initialize AuthenticationViewModel with PreviewService
        let authViewModel = AuthenticationViewModel(mastodonService: previewService)
        
        // Simulate unauthenticated state
        authViewModel.isAuthenticated = false
        authViewModel.instanceURL = previewService.baseURL

        return AuthenticationView()
            .environmentObject(authViewModel)
    }
}

