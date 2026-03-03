//
//  ClipboardListViewModel.swift
//  SenseFlow
//
//  Created on 2026-02-05.
//

import SwiftUI
import Combine

/// 剪贴板列表视图模型
class ClipboardListViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var items: [ClipboardItem] = []
    @Published var searchQuery: String = ""

    // MARK: - Private Properties

    private let repository: ClipboardRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    private let defaultItemLimit = 200  // 消除魔法数字

    // MARK: - Initialization

    init(repository: ClipboardRepositoryProtocol) {
        self.repository = repository
        setupSearchObserver()
    }

    // MARK: - Private Methods

    private func setupSearchObserver() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                Task {
                    await self?.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func loadItems() async {
        let items = await repository.fetchRecent(limit: defaultItemLimit)
        await MainActor.run {
            withAnimation(.smooth(duration: 0.3)) {
                self.items = items
            }
        }
    }

    func performSearch(query: String) async {
        let items = query.isEmpty
            ? await repository.fetchRecent(limit: defaultItemLimit)
            : await repository.search(query: query, limit: defaultItemLimit)

        await MainActor.run {
            withAnimation(.smooth(duration: 0.3)) {
                self.items = items
            }
        }
    }
}
