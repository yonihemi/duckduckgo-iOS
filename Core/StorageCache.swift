//
//  StorageCache.swift
//  DuckDuckGo
//
//  Copyright © 2019 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

protocol EtagOOSCheckStore {
    
    var hasDisconnectMeData: Bool { get }
    var hasEasylistData: Bool { get }
}

protocol StorageCacheUpdating {
    
    func update(_ configuration: ContentBlockerRequest.Configuration, with data: Any) -> Bool
}

public class StorageCache: StorageCacheUpdating {
    
    let easylistStore = EasylistStore()
    let surrogateStore = SurrogateStore()
    
    public let disconnectMeStore = DisconnectMeStore()
    public let httpsUpgradeStore: HTTPSUpgradeStore = HTTPSUpgradePersistence()
    public let entityMappingStore: EntityMappingStore = DownloadedEntityMappingStore()
    public var entityMapping: EntityMapping
    
    public let configuration: ContentBlockerConfigurationStore = ContentBlockerConfigurationUserDefaults()
    
    // Read only
    public let tld: TLD
    public let termsOfServiceStore: TermsOfServiceStore
    public let prevalenceStore: PrevalenceStore
    
    public init() {
        entityMapping = EntityMapping(store: entityMappingStore)
        tld = TLD()
        termsOfServiceStore = EmbeddedTermsOfServiceStore()
        prevalenceStore = EmbeddedPrevalenceStore()
    }
    
    public init(tld: TLD, termsOfServiceStore: TermsOfServiceStore, prevalenceStore: PrevalenceStore) {
        entityMapping = EntityMapping(store: entityMappingStore)
        self.tld = tld
        self.termsOfServiceStore = termsOfServiceStore
        self.prevalenceStore = prevalenceStore
    }
    
    public var hasData: Bool {
        return disconnectMeStore.hasData && easylistStore.hasData
    }
    
    // swiftlint:disable cyclomatic_complexity
    func update(_ configuration: ContentBlockerRequest.Configuration, with data: Any) -> Bool {
        
        switch configuration {
        case .trackersWhitelist:
            guard let data = data as? Data else { return false }
            return easylistStore.persistEasylistWhitelist(data: data)
            
        case .disconnectMe:
            guard let data = data as? Data else { return false }
            do {
                try disconnectMeStore.persist(data: data)
                return true
            } catch {
                return false
            }
        case .httpsWhitelist:
            guard let whitelist = data as? [String] else { return false }
            return httpsUpgradeStore.persistWhitelist(domains: whitelist)
            
        case .httpsBloomFilter:
            guard let bloomFilter = data as? (spec: HTTPSBloomFilterSpecification, data: Data) else { return false }
            let result = httpsUpgradeStore.persistBloomFilter(specification: bloomFilter.spec, data: bloomFilter.data)
            HTTPSUpgrade.shared.loadData()
            return result
            
        case .surrogates:
            guard let data = data as? Data else { return false }
            return surrogateStore.parseAndPersist(data: data)
            
        case .entitylist:
            guard let data = data as? Data else { return false }
            let result = entityMappingStore.persist(data: data)
            entityMapping = EntityMapping(store: entityMappingStore)
            return result
            
        default:
            return false
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

extension StorageCache: EtagOOSCheckStore {
    
    var hasDisconnectMeData: Bool {
        return disconnectMeStore.hasData
    }
    var hasEasylistData: Bool {
        return easylistStore.hasData
    }
}
