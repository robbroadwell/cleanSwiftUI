//
//  BloombergService.swift
//  CleanSwiftUI
//
//  Created by Rob Broadwell on 10/16/22.
//

import Combine
import Foundation
import SwiftUI

protocol BloombergService {
    func refreshCountriesList() -> AnyPublisher<Void, Error>
    func load(countries: LoadableSubject<LazyList<Country>>, search: String, locale: Locale)
    func load(countryDetails: LoadableSubject<Country.Details>, country: Country)
}

struct RealBloombergService: BloombergService {
    
    let webRepository: BloombergWebRepository
    let dbRepository: BloombergDBRepository
    let appState: Store<AppState>
    
    init(webRepository: BloombergWebRepository, dbRepository: BloombergDBRepository, appState: Store<AppState>) {
        self.webRepository = webRepository
        self.dbRepository = dbRepository
        self.appState = appState
    }

    func load(countries: LoadableSubject<LazyList<Country>>, search: String, locale: Locale) {
        
        let cancelBag = CancelBag()
        countries.wrappedValue.setIsLoading(cancelBag: cancelBag)
        
        Just<Void>
            .withErrorType(Error.self)
            .flatMap { [dbRepository] _ -> AnyPublisher<Bool, Error> in
                dbRepository.hasLoadedCountries()
            }
            .flatMap { hasLoaded -> AnyPublisher<Void, Error> in
                if hasLoaded {
                    return Just<Void>.withErrorType(Error.self)
                } else {
                    return self.refreshCountriesList()
                }
            }
            .flatMap { [dbRepository] in
                dbRepository.countries(search: search, locale: locale)
            }
            .sinkToLoadable { countries.wrappedValue = $0 }
            .store(in: cancelBag)
    }
    
    func refreshCountriesList() -> AnyPublisher<Void, Error> {
        return webRepository
            .loadCountries()
            .ensureTimeSpan(requestHoldBackTimeInterval)
            .flatMap { [dbRepository] in
                dbRepository.store(countries: $0)
            }
            .eraseToAnyPublisher()
    }

    func load(countryDetails: LoadableSubject<Country.Details>, country: Country) {
        
        let cancelBag = CancelBag()
        countryDetails.wrappedValue.setIsLoading(cancelBag: cancelBag)

        dbRepository
            .countryDetails(country: country)
            .flatMap { details -> AnyPublisher<Country.Details?, Error> in
                if details != nil {
                    return Just<Country.Details?>.withErrorType(details, Error.self)
                } else {
                    return self.loadAndStoreCountryDetailsFromWeb(country: country)
                }
            }
            .sinkToLoadable { countryDetails.wrappedValue = $0.unwrap() }
            .store(in: cancelBag)
    }
    
    private func loadAndStoreCountryDetailsFromWeb(country: Country) -> AnyPublisher<Country.Details?, Error> {
        return webRepository
            .loadCountryDetails(country: country)
            .ensureTimeSpan(requestHoldBackTimeInterval)
            .flatMap { [dbRepository] in
                dbRepository.store(countryDetails: $0, for: country)
            }
            .eraseToAnyPublisher()
    }
    
    private var requestHoldBackTimeInterval: TimeInterval {
        return ProcessInfo.processInfo.isRunningTests ? 0 : 0.5
    }
}

struct StubBloombergService: BloombergService {
    
    func refreshCountriesList() -> AnyPublisher<Void, Error> {
        return Just<Void>.withErrorType(Error.self)
    }
    
    func load(countries: LoadableSubject<LazyList<Country>>, search: String, locale: Locale) {
    }
    
    func load(countryDetails: LoadableSubject<Country.Details>, country: Country) {
    }
}
