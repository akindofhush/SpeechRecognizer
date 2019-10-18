//
//  ViewController.swift
//  SpeechRecognizer
//
//  Created by Tzu-Yen Huang on 2019/10/16.
//  Copyright © 2019年 Tzu-Yen Huang. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {

    @IBOutlet var outputTextField: UITextField!
    @IBOutlet var microphoneButton: UIButton!
    // 按下 microphoneButton 出現的動圖
    let imageView = UIImageView()
    // 計時器
    var detectionTimer: Timer?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "zh-TW")) //1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //imageView按下的Action
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapGestureRecognizer)
        
        //禁用 microphone 按鈕，一直到語音識別器被激活
        microphoneButton.isEnabled = false
        speechRecognizer?.delegate = self
        
        //要求語音識別的授權
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            
            var isButtonEnabled = false
            
            switch authStatus {  //判斷授權狀態，如果用戶已授權，啟用麥克風按鈕。否則顯示錯誤信息並禁用麥克風按鈕
            case .authorized:
                isButtonEnabled = true
                
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                self.microphoneButton.isEnabled = isButtonEnabled
            }
        }
    }
    
    //負責發起語音識別請求。它為語音識別器指定一個音頻輸入源(開啟、結束)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    //保存發起語音識別請求后的返回值。通過這個物件，你可以取消或中止當前的語音識別任務(識別開始後有返回值)
    private var recognitionTask: SFSpeechRecognitionTask?
    //提供錄音輸入
    private let audioEngine = AVAudioEngine()
    
    func startRecording() { //開始語音識別和監聽麥克風
        
        //檢查recognitionTask是否處於運行狀態。如果是，取消任務，開始新的語音識別任務
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // 錄音或播出音頻時的行為處理
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setMode(AVAudioSession.Mode.measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        // 發送語音辨識請求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // 設置device的錄音設備
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        //在用戶說話的同時，將識別結果分批返回
        recognitionRequest.shouldReportPartialResults = true
        var value : String = ""
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false //用於檢查語音是否結束
            
            if result != nil {
                self.detectionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false, block: { (timer) in
                    recognitionRequest.endAudio()
                    timer.invalidate()
                })
                
                isFinal = (result?.isFinal)!
                if (isFinal) {
                    //將字串放入textfield
                    value = (result?.bestTranscription.formattedString)!
                    self.outputTextField.text = value
                }
            }
            
            // 識別結束後要做的事： 如果沒有錯誤發生，或者 result 已經結束，停止 audioEngine (錄音) 並終止 recognitionRequest 和 recognitionTask。同時，使 「開始錄音」按鈕可用。
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.imageView.stopAnimating()
                self.imageView.removeFromSuperview()
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.microphoneButton.isEnabled = true
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        //啟動 audioEngine
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        outputTextField.text = "Say something, I'm listening!"
        
    }
    
    //必須確保語音識別是可用的。當語音識別不可用或者狀態發生改變時，應當改變 microphoneButton.enable 屬性。
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            microphoneButton.isEnabled = true
        } else {
            microphoneButton.isEnabled = false
        }
    }

    @IBAction func microphoneButtonHandler(_ sender: UIButton) {
        let imgListArray :NSMutableArray = []
        for countValue in 1...3 {
            let strImageName : String = "voice_\(countValue).png"
            let image = UIImage(named:strImageName)
            imgListArray.add(image ?? UIImage())
        }
        imageView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        imageView.backgroundColor = UIColor.darkGray
        imageView.contentMode = UIView.ContentMode.center
        imageView.animationImages = imgListArray as? [UIImage]
        imageView.animationDuration = 1.0
        imageView.startAnimating()
        self.view.addSubview(imageView)
        startRecording()
    }
    
    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        if audioEngine.isRunning {
            recognitionRequest?.endAudio()
        }
    }
    
}
