//
//  AccountsViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on [Date].
//

import Foundation
import Combine

@MainActor
class AccountsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var accounts: [Account] = []
    @Published var selectedAccount: Account?
    @Published var errorMessage: AppError?
    
    // MARK: - Private Properties
    
    private var mastodonService: MastodonServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService
        
        // Fetch accounts upon initialization
        Task {
            await fetchAccounts()
        }
    }
    
    // MARK: - Public Methods
    
    /// Selects an account, setting it as the active account.
    /// - Parameter account: The account to select.
    func selectAccount(_ account: Account) {
        selectedAccount = account
        // Update the mastodonService's baseURL and accessToken
        mastodonService.baseURL = account.instanceURL
        mastodonService.accessToken = account.accessToken
        // Post a notification if needed
        NotificationCenter.default.post(name: .didAuthenticate, object: nil)
    }
    
    /// Deletes accounts at the specified offsets.
    /// - Parameter offsets: The index set of accounts to delete.
    func deleteAccounts(at offsets: IndexSet) {
        accounts.remove(atOffsets: offsets)
        // Optionally, handle deletion from persistent storage or remote service
    }
    
    /// Registers a new account.
    /// - Parameters:
    ///   - username: The username for the new account.
    ///   - password: The password for the new account.
    ///   - instanceURL: The Mastodon instance URL.
    func registerAccount(username: String, password: String, instanceURL: URL) async {
        do {
            let newAccount = try await mastodonService.registerAccount(username: username, password: password, instanceURL: instanceURL)
            accounts.append(newAccount)
            selectAccount(newAccount)
        } catch {
            errorMessage = AppError(message: error.localizedDescription)
        }
    }
    
    /// Fetches the list of user accounts.
    func fetchAccounts() async {
        do {
            let fetchedAccounts = try await mastodonService.fetchAccounts()
            accounts = fetchedAccounts
            if let firstAccount = fetchedAccounts.first {
                selectAccount(firstAccount)
            }
        } catch {
            errorMessage = AppError(message: error.localizedDescription)
        }
    }
}

