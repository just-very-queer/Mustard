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
    
    init(mastodonService: MastodonServiceProtocol,
         modelContext: ModelContext) {
        self.mastodonService = mastodonService
        self.modelContext = modelContext
        
        // We call fetchAccounts() (which is synchronous) in a Task if we want concurrency
        Task {
            fetchAccounts()
        }
        
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
    
    /// Fetches accounts from SwiftData synchronously. No 'await' needed.
    func fetchAccounts() {
        do {
            let fetchRequest = FetchDescriptor<Account>()
            let fetchedAccounts = try modelContext.fetch(fetchRequest)
            accounts = fetchedAccounts
            
            if let firstAccount = fetchedAccounts.first, selectedAccount == nil {
                selectAccount(firstAccount)
            }
        } catch {
            errorMessage = AppError(message: "Failed to fetch accounts: \(error.localizedDescription)")
            print("[AccountsViewModel] Error: \(error.localizedDescription)")
        }
    }
    
    /// Select an account, updating the Mastodon service with baseURL & token
    func selectAccount(_ account: Account) {
        selectedAccount = account
        mastodonService.baseURL = account.instanceURL
        mastodonService.accessToken = account.accessToken
        
        modelContext.insert(account)
        do {
            try modelContext.save()
            print("[AccountsViewModel] Selected account saved: \(account.id)")
        } catch {
            errorMessage = AppError(message: "Failed to persist selected account: \(error.localizedDescription)")
        }
        
        NotificationCenter.default.post(name: .didSelectAccount, object: nil)
    }
    
    /// Deletes accounts from SwiftData and from the local array.
    func deleteAccounts(at offsets: IndexSet) {
        let accountsToDelete = offsets.map { accounts[$0] }
        
        for account in accountsToDelete {
            modelContext.delete(account)
            if let selected = selectedAccount, selected.id == account.id {
                selectedAccount = nil
                mastodonService.baseURL = nil
                mastodonService.accessToken = nil
            }
        }
        
        accounts.remove(atOffsets: offsets)
        
        do {
            try modelContext.save()
            print("[AccountsViewModel] Accounts removed & saved.")
        } catch {
            errorMessage = AppError(message: "Failed to delete accounts: \(error.localizedDescription)")
        }
    }
    
    /// Registers a new account by calling an async method in MastodonService.
    /// We use `try await` to handle concurrency.
    func registerAccount(username: String,
                         password: String,
                         instanceURL: URL) async {
        do {
            // Because MastodonService.registerAccount(...) is async throws,
            // we do 'try await' here.
            let newAccount = try await mastodonService.registerAccount(
                username: username,
                password: password,
                instanceURL: instanceURL
            )
            
            // Once returned, we add & select it
            accounts.append(newAccount)
            selectAccount(newAccount)
            print("[AccountsViewModel] Registered + selected new account: \(newAccount.id)")
        } catch {
            errorMessage = AppError(message: "Failed to register account: \(error.localizedDescription)")
            print("[AccountsViewModel] Registration error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    @objc private func handleAccountSelection(notification: Notification) {
        // Possibly do more actions upon selection
    }
}

