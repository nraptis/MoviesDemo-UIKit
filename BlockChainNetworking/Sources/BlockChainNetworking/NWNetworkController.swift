//
//  File.swift
//  
//
//  Created by Nicholas Alexander Raptis on 4/8/24.
//

import Foundation

protocol NWNetworkControllerImplementing {
    static func fetchPopularMovies(page: Int) async throws -> NWMoviesResponse
    static func fetchMovieDetails(id: Int) async throws -> NWMovieDetails
}

public struct NWNetworkController: NWNetworkControllerImplementing {
    
    public static let page_size = 20
    private static let apiKey = "82951838f8541db71be0a09ae99f6519"
    
    private static let jsonDecoder = JSONDecoder()
    
    public static func fetchPopularMovies(page: Int) async throws -> NWMoviesResponse {
        
        let urlString = "https://api.themoviedb.org/3/movie/popular?api_key=\(Self.apiKey)&page=\(page)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // Comment out for release
        request.timeoutInterval = 5.0
        return try await fetch(urlRequest: request, responseType: NWMoviesResponse.self)
    }
    
    public static func fetchMovieDetails(id: Int) async throws -> NWMovieDetails {
        let urlString = "https://api.themoviedb.org/3/movie/\(id)?api_key=\(Self.apiKey)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // Comment out for release
        request.timeoutInterval = 10.0
        return try await fetch(urlRequest: request, responseType: NWMovieDetails.self)
    }
    
    private static func fetch<Response: Decodable>(urlRequest: URLRequest, responseType: Response.Type) async throws -> Response {
        let urlSession = URLSession(configuration: .ephemeral)
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode(Response.self, from: data)
    }
}
