//
//  AccountsViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import Combine
import SwiftData

@MainActor
class AccountsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var accounts: [Account] = []
    @Published var selectedAccount: Account?
    @Published var errorMessage: AppError?
    
    // MARK: - Private Properties
    private var mastodonService: MastodonServiceProtocol
    private var modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(mastodonService: MastodonServiceProtocol, modelContext: ModelContext) {
        self.mastodonService = mastodonService
        self.modelContext = modelContext
        
        Task {
            await fetchAccounts()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountAdded(notification:)),
            name: .didAddAccount,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountSelection(notification:)),
            name: .didSelectAccount,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Fetches accounts from SwiftData asynchronously.
    func fetchAccounts() async {
        do {
            let fetchRequest = FetchDescriptor<Account>()
            let fetchedAccounts = try modelContext.fetch(fetchRequest)
            DispatchQueue.main.async {
                self.accounts = fetchedAccounts
                // Automatically select the first account if none is selected
                if self.selectedAccount == nil, let first = fetchedAccounts.first {
                    self.selectAccount(first)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = AppError(message: "Failed to fetch accounts: \(error.localizedDescription)")
            }
        }
    }
    
    /// Selects an account for use, setting up the Mastodon service with its credentials.
    /// - Parameter account: The `Account` to select.
    func selectAccount(_ account: Account) {
        selectedAccount = account
        if let service = mastodonService as? MastodonService {
            service.baseURL = account.instanceURL
            service.accessToken = account.accessToken
        }
        
        // Persist the selected account if needed
        do {
            try modelContext.save()
        } catch {
            errorMessage = AppError(message: "Failed to persist selected account: \(error.localizedDescription)")
        }
        
        NotificationCenter.default.post(name: .didSelectAccount, object: nil)
    }
    
    /// Deletes accounts from SwiftData and the local array.
    /// - Parameter offsets: The indices of the accounts to delete.
    func deleteAccounts(at offsets: IndexSet) {
        let accountsToDelete = offsets.map { accounts[$0] }
        
        for account in accountsToDelete {
            modelContext.delete(account)
            if let selected = selectedAccount, selected.id == account.id {
                selectedAccount = nil
                if let service = mastodonService as? MastodonService {
                    service.baseURL = nil
                    service.accessToken = nil
                }
            }
        }
        
        accounts.remove(atOffsets: offsets)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = AppError(message: "Failed to delete accounts: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    @objc private func handleAccountAdded(notification: Notification) {
        Task {
            await fetchAccounts()
        }
    }
    
    @objc private func handleAccountSelection(notification: Notification) {
        // Handle additional logic upon selection if needed
    }
    
    /// Checks if the account is authenticated based on the presence of a valid access token.
    /// - Parameter account: The `Account` to check.
    /// - Returns: `true` if authenticated, else `false`.
    private func isAuthenticated(account: Account) -> Bool {
        guard let token = account.accessToken, !token.isEmpty else { return false }
        // Optionally, add more checks to verify token validity
        return true
    }
}

