//
//  Downloader.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 12/5/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//
//	Download track in cache

import Foundation
import UIKit

class Downloader: NSObject {
	
	static let sharedInstance = Downloader()
	//	var taskQueue: OperationQueue?
	let baseURL = URL(string: "http://api.ownradio.ru/v5/tracks/")
	let applicationSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
	let tracksPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Tracks/")
	let tracksUrlString =  FileManager.applicationSupportDir().appending("/Tracks/")
	
//	let limitMemory =  UInt64(DiskStatus.freeDiskSpaceInBytes / 3)
	var maxMemory = UInt64(1000000000)
	var memoryBuffer = UInt()
	
	var requestCount = 0
	var deleteCount = 0
	var maxRequest = 9
	var completionHandler:(()->Void)? = nil

	func load(isSelfFlag: Bool, complition: @escaping (() -> Void)) {
		print("call load")
		
		
		let memoryAvailable = UInt64(DiskStatus.folderSize(folderPath: tracksUrlString)) + UInt64(DiskStatus.freeDiskSpaceInBytes)
		let percentage = Double((UserDefaults.standard.object(forKey: "maxMemorySize") as? Double)! / 100)
		maxMemory = UInt64(Double(memoryAvailable) * percentage)
		
//		if limitMemory < 1000000000 * ((UserDefaults.standard.object(forKey: "maxMemorySize") as? UInt64)! / 10) {
//			maxMemory = limitMemory
//		} else {
//			let memoryAvailable = UInt64(DiskStatus.folderSize(folderPath: tracksUrlString)) + UInt64(DiskStatus.freeDiskSpaceInBytes)
//			let percentage = Double((UserDefaults.standard.object(forKey: "maxMemorySize") as? Double)! / 100)
//			maxMemory = UInt64(Double(memoryAvailable) * percentage)
//		}
//		+ DiskStatus.folderSize(folderPath: tracksUrlString)))
//		* (DiskStatus.freeDiskSpaceInBytes)
		
		//если треки занимают больше места, чем максимально допустимо -
		//удаляем "лишние" треки - в первую очередь прослушанные, затем, если необходимо - самые старые из загруженных
		while (!isSelfFlag && DiskStatus.folderSize(folderPath: tracksUrlString) > maxMemory) {
			// получаем трек проиграный большее кол-во раз
			let song: SongObject? = CoreDataManager.instance.getOldTrack(onlyListen: false)
			// получаем путь файла
			guard song != nil && song?.trackID != nil else {
				self.createPostNotificationSysInfo(message: "Не найден трек для удаления")
				return
			}
			self.createPostNotificationSysInfo(message: "Память заполнена. Удаляем трек \(self.deleteCount)")
			let songObjectEncoded = UserDefaults.standard.data(forKey: "interruptedSongObject")
			let currentSongObject = try! PropertyListDecoder().decode(SongObject.self, from: songObjectEncoded!)
			if UserDefaults.standard.bool(forKey: "trackPlayingNow") && (song?.isEqual(currentSongObject))! != true{
				deleteOldTrack(song: song)
			}
			else{
				CoreDataManager.instance.setLogRecord(eventDescription: "Удаляемый трек сейчас играет, uuid = \(song?.trackID.description)", isError: false, errorMessage: "")
				CoreDataManager.instance.saveContext()
			}
			
		}
		
		//проверка подключения к интернету
		guard currentReachabilityStatus != NSObject.ReachabilityStatus.notReachable else {
			self.requestCount = 0
			return
		}
		
		
		//делаем 10 попыток скачивания треков, если место свободное место закончилось, но есть прослушанные треки - удаляем их и загружаем новые, иначе перестаем пытаться скачать
		if DiskStatus.folderSize(folderPath: tracksUrlString) < maxMemory  {
			self.deleteCount = 0
			//получаем trackId следующего трека и информацию о нем
			self.completionHandler = complition
			ApiService.shared.getTrackIDFromServer(requestCount: self.requestCount) { [unowned self] (dict) in
				guard dict["id"] != nil else {
					return
				}
				print(dict["id"])
				let trackURL = self.baseURL?.appendingPathComponent(dict["id"] as! String).appendingPathComponent((UIDevice.current.identifierForVendor?.uuidString.lowercased())!)
				if let audioUrl = trackURL {
					//задаем директорию для сохранения трека
					let destinationUrl = self.tracksPath.appendingPathComponent(dict["id"] as! String)
					//если этот трек не еще не загружен - загружаем трек
					//						let mp3Path = destinationUrl.appendingPathExtension("mp3")
					guard FileManager.default.fileExists(atPath: destinationUrl.path ) == false else {
						self.createPostNotificationSysInfo(message: "Трек уже загружен - пропустим")
						return
					}
					//добавляем трек в очередь загрузки
					let downloadRequest = self.createDownloadTask(audioUrl: audioUrl, destinationUrl: destinationUrl, dict: dict)
					
					downloadRequest.resume()
					
					//						}
				}
			}
			
		} else {
			// если память заполнена удаляем трек
			if self.deleteCount < 9 {
				if self.completionHandler != nil {
					self.completionHandler!()
				}
				self.deleteCount += 1
				
				
				// получаем трек проиграный большее кол-во раз
				let song: SongObject? = CoreDataManager.instance.getOldTrack(onlyListen: true)
				// получаем путь файла
				guard song != nil && song?.trackID != nil else {
					self.createPostNotificationSysInfo(message: "Память заполнена, нет прослуш треков")
					self.requestCount = 0
					return
				}
				self.createPostNotificationSysInfo(message: "Память заполнена. Удаляем трек \(self.deleteCount)")
				
				let songObjectEncoded = UserDefaults.standard.data(forKey: "interruptedSongObject")
				let currentSongObject = try! PropertyListDecoder().decode(SongObject.self, from: songObjectEncoded!)
				if UserDefaults.standard.bool(forKey: "trackPlayingNow") && (song?.isEqual(currentSongObject))! != true{
					deleteOldTrack(song: song)
				}
				else{
					CoreDataManager.instance.setLogRecord(eventDescription: "Удаляемый трек сейчас играет, uuid = \(song?.trackID.description)", isError: false, errorMessage: "")
					CoreDataManager.instance.saveContext()
				}
				
				self.load (isSelfFlag: true){
					
				}
				
			}else {
				self.deleteCount = 0
			}
			
		}
	}
	
	func createDownloadTask(audioUrl:URL, destinationUrl:URL, dict:[String:AnyObject]) -> URLSessionDownloadTask {
		print("call createDownloadTask")
		CoreDataManager.instance.setLogRecord(eventDescription: "Начата загрузка трека, url: " + audioUrl.description, isError: false, errorMessage: "")
		CoreDataManager.instance.saveContext()
		return URLSession.shared.downloadTask(with: audioUrl, completionHandler: { (location, response, error) -> Void in
			guard error == nil else {
				
				self.createPostNotificationSysInfo(message: error.debugDescription)
				CoreDataManager.instance.setLogRecord(eventDescription: "Download failed, url: \(audioUrl.absoluteString)", isError: true, errorMessage: error.debugDescription)
				CoreDataManager.instance.saveContext()
				return
			}
			guard let newLocation = location, error == nil else {return }
			
			if let httpResponse = response as? HTTPURLResponse {
				if httpResponse.statusCode == 200 {
					do {
						let file = NSData(contentsOf: newLocation)
						let mp3Path = destinationUrl.appendingPathExtension("mp3")
						guard FileManager.default.fileExists(atPath: mp3Path.path ) == false else {
							self.createPostNotificationSysInfo(message: "MP3 file exist")
							CoreDataManager.instance.setLogRecord(eventDescription: "MP3 file exist", isError: true, errorMessage: mp3Path.path.description)
							CoreDataManager.instance.saveContext()
							return
						}
						
						//сохраняем трек
						//задаем конечных путь хранения файла (добавляем расширение)
						let endPath = destinationUrl.appendingPathExtension("mp3")
						try file?.write(to: endPath, options:.noFileProtection)
						
						//Проверяем, полностью ли скачан трек
						if let contentLength = Int(httpResponse.allHeaderFields["Content-Length"] as! String) {
							if file!.length != contentLength || file!.length == 0 {
								if FileManager.default.fileExists(atPath: mp3Path.path) {
									do{
										// удаляем обьект по пути
										try FileManager.default.removeItem(atPath: mp3Path.path)
										self.createPostNotificationSysInfo(message: "Файл с длиной = \(file!.length), ContentLength = \(contentLength) удален")
									}
									catch {
										CoreDataManager.instance.setLogRecord(eventDescription: "Ошибка при удалении недокачанного трека", isError: true, errorMessage: error.localizedDescription)
										CoreDataManager.instance.saveContext()
										print("Ошибка при удалении недокачанного трека")
									}
								}
								return
							}
						}
						//сохраняем информацию о файле в базу данных
						
						guard FileManager.default.fileExists(atPath: mp3Path.absoluteString ) == false else {
							self.createPostNotificationSysInfo(message: "MP3 file exist")
							return
						}
						
						let trackEntity = TrackEntity()
						
						trackEntity.path = String(describing: endPath.lastPathComponent)
						trackEntity.countPlay = 0
						trackEntity.artistName = dict["artist"] as? String
						trackEntity.trackName = dict["name"] as? String
						trackEntity.trackLength = NSString(string: dict["length"] as! String).doubleValue
						trackEntity.recId = dict["id"] as! String?
						trackEntity.playingDate = NSDate.init(timeIntervalSinceNow: -315360000.0042889)
						
						CoreDataManager.instance.saveContext()
						
						
						self.createPostNotificationSysInfo(message: "Трек (\(self.requestCount+1)) загружен \(trackEntity.recId ?? "")")
						if self.requestCount < self.maxRequest {
							if self.completionHandler != nil {
								self.completionHandler!()
							}
							self.requestCount += 1
							self.load(isSelfFlag: true, complition: self.completionHandler!)
							
						} else {
							if self.completionHandler != nil {
								self.completionHandler!()
							}
							self.requestCount = 0
							self.maxRequest = 9
						}
						
						//				complition()
						CoreDataManager.instance.setLogRecord(eventDescription: "Информация о треке сохранена в БД", isError: false, errorMessage: "")
						CoreDataManager.instance.saveContext()
						print("File moved to documents folder")

					} catch let error as NSError {
						CoreDataManager.instance.setLogRecord(eventDescription: "Информация о треке не сохранена: " + error.localizedDescription, isError: true, errorMessage: error.localizedDescription)
						CoreDataManager.instance.saveContext()
						print(error.localizedDescription)
					}
				}
			}
		})
	}

	func createPostNotificationSysInfo (message:String) {
		NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updateSysInfo"), object: nil, userInfo: ["message":message])
	}
	
	// удаление трека если память заполнена
	func deleteOldTrack (song: SongObject?) {
		print("call deleteOldTrack")
		CoreDataManager.instance.setLogRecord(eventDescription: "Удаление старого трека", isError: false, errorMessage: "")
		CoreDataManager.instance.saveContext()
		let path = self.tracksUrlString.appending((song?.path)!)
		self.createPostNotificationSysInfo(message: "Удаляем \(song!.trackID.description)")
		print("Удаляем \(song!.trackID.description)")
		CoreDataManager.instance.setLogRecord(eventDescription: "Удаляем старый трек \(song!.trackID.description)", isError: false, errorMessage: "")
		CoreDataManager.instance.saveContext()
		
		let songObjectEncoded = UserDefaults.standard.data(forKey: "interruptedSongObject")
		let currentSongObject = try! PropertyListDecoder().decode(SongObject.self, from: songObjectEncoded!)
		if UserDefaults.standard.bool(forKey: "trackPlayingNow") && (song?.isEqual(currentSongObject))!{
			print("Не удаляем сейчас играющий трек")
			CoreDataManager.instance.setLogRecord(eventDescription: "Старый удаляемый трек играет сейчас", isError: false, errorMessage: "")
			CoreDataManager.instance.saveContext()
		}
		else{
			if FileManager.default.fileExists(atPath: path) {
				do{
					// удаляем обьект по пути
					try FileManager.default.removeItem(atPath: path)
					self.createPostNotificationSysInfo(message: "Файл успешно удален")
					print("Файл успешно удален")
					CoreDataManager.instance.setLogRecord(eventDescription: "Старый трек удален", isError: false, errorMessage: "")
					CoreDataManager.instance.saveContext()
				}
				catch {
					self.createPostNotificationSysInfo(message: "Ошибка удаления трека: \(error)")
					print("Ошибка удаления трека: \(error)")
					CoreDataManager.instance.setLogRecord(eventDescription: "Ошибка удаления старого трека: " + error.localizedDescription, isError: true, errorMessage: error.localizedDescription)
					CoreDataManager.instance.saveContext()
				}
			} else {
				self.createPostNotificationSysInfo(message: "Трек уже удалён с устройства")
				print("Трек уже удалён с устройства")
				CoreDataManager.instance.setLogRecord(eventDescription: "Старый трек уже удален", isError: false, errorMessage: "")
				CoreDataManager.instance.saveContext()
			}
			// удаляем трек с базы
			//			CoreDataManager.instance.managedObjectContext.performAndWait {
			CoreDataManager.instance.deleteTrackFor(trackID: (song?.trackID)!)
			CoreDataManager.instance.setLogRecord(eventDescription: "Трек удален из БД, id: " + (song?.trackID.description)!, isError: false, errorMessage: "")
			CoreDataManager.instance.saveContext()
			//			}
			
			//		}
		}
	}
	
	func fillCache () {
//		let limitMemory =  UInt64(DiskStatus.freeDiskSpaceInBytes / 2)
//		let maxMemory = 1000000000 * (UserDefaults.standard.object(forKey: "maxMemorySize") as? UInt64)!
		let memoryAvailable = UInt64(DiskStatus.folderSize(folderPath: tracksUrlString)) + UInt64(DiskStatus.freeDiskSpaceInBytes)
		let percentage = Double((UserDefaults.standard.object(forKey: "maxMemorySize") as? Double)! / 100)
		maxMemory = UInt64(Double(memoryAvailable) * percentage)
		let folderSize = DiskStatus.folderSize(folderPath: tracksUrlString)
		CoreDataManager.instance.setLogRecord(eventDescription: "Заполнение кеша, объем: " + DiskStatus.GBFormatter(Int64(folderSize)).description + ", свободное место: " + maxMemory.description + ", разрешенный процент: " + percentage.description, isError: false, errorMessage: "")
		CoreDataManager.instance.saveContext()
		
		if folderSize < maxMemory  {
			self.load (isSelfFlag: true){
				sleep(2)
				self.fillCache()
			}
		}
		else{
			CoreDataManager.instance.setLogRecord(eventDescription: "Недостаточно памяти для заполнения кеша", isError: false, errorMessage: "")
			CoreDataManager.instance.saveContext()
		}
	}
	
}
