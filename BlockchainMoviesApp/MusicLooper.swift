//
//  MusicLooper.swift
//  BlockchainMoviesApp
//
//  Created by Nicholas Alexander Raptis on 4/23/24.
//

import Foundation
import AVFoundation

class MusicLooper: NSObject {
    
    var audioPlayer: AVAudioPlayer?
    
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func stopAudioPlayer() {
        if let audioPlayer = audioPlayer {
            audioPlayer.stop()
            audioPlayer.delegate = nil
            self.audioPlayer = nil
        }
    }
    
    func startAudioPlayer() {
        if let audioPlayer = audioPlayer {
            if audioPlayer.isPlaying {
                stopAudioPlayer()
                return
            }
        }
        
        guard let url = Bundle.main.url(forResource: "happy_jack", withExtension: "m4a") else {
            print("failed to load happy_jack.m4a")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            if let audioPlayer = audioPlayer {
                audioPlayer.delegate = self
                audioPlayer.play()
            }
        } catch let error {
            print("audio player error: \(error.localizedDescription)")
        }
    }
}

extension MusicLooper: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        startAudioPlayer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stopAudioPlayer()
    }
    
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        audioPlayer?.pause()
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        audioPlayer?.play()
    }
}
