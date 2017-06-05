package ownradio.web.rest.v4;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import ownradio.domain.*;
import ownradio.service.DeviceService;
import ownradio.service.DownloadTrackService;
import ownradio.service.LogService;
import ownradio.service.UserService;

import java.util.List;
import java.util.UUID;

/**
 * Created by a.polunina on 17.03.2017.
 */
@Slf4j
//@CrossOrigin
@RestController
@RequestMapping("/v4/statistics")
public class StatisticsController {

	private final UserService userService;
	private final DeviceService deviceService;
	private final DownloadTrackService downloadTrackService;
	private final LogService logService;

	@Autowired
	public StatisticsController(UserService userService, DeviceService deviceService, DownloadTrackService downloadTrackService, LogService logService){
		this.userService = userService;
		this.deviceService = deviceService;
		this.downloadTrackService = downloadTrackService;
		this.logService = logService;
	}

	@RequestMapping(value = "/{userId}/getuserdevices", method = RequestMethod.GET)
	public ResponseEntity<?> getUserDevices(@PathVariable UUID userId) {
		try {
			List<Device> devices = deviceService.getByUserid(userId);

			return new ResponseEntity<>(devices, HttpStatus.OK);
		}catch (Exception ex){
			return new ResponseEntity<>(HttpStatus.NOT_FOUND);
		}
	}


	@RequestMapping(value = "/{deviceId}/{countTracks}/getlasttracks", method = RequestMethod.GET)
	public ResponseEntity<?> getLastTracksByDevice(@PathVariable UUID deviceId, @PathVariable Integer countTracks) {
		try {
			List<DownloadTrack> downloadedTracks = downloadTrackService.getLastTracksByDevice(deviceId, countTracks);
//			Device device = new Device();
//			device.setRecid(deviceid);
//			List<DownloadTrack> downloadedTracks = downloadTrackRepository.findFirst3ByDeviceOrderByReccreatedDesc(device);

			return new ResponseEntity<>(downloadedTracks, HttpStatus.OK);
		}catch (Exception ex){
			return new ResponseEntity<>(HttpStatus.NOT_FOUND);
		}
	}


	@RequestMapping(value = "/usersrating/{countRows}", method = RequestMethod.GET)
	public ResponseEntity<?> getUsersRating(@PathVariable Integer countRows) {
		try {
			List<UsersRating> usersRating = userService.getUsersRating(countRows);

			return new ResponseEntity<>(usersRating, HttpStatus.OK);
		}catch (Exception ex){
			return new ResponseEntity<>(HttpStatus.NOT_FOUND);
		}
	}

	@RequestMapping(value = "/{deviceId}/{countTracks}/gettrackshistorybydevice", method = RequestMethod.GET)
	public ResponseEntity<?> getTracksHistoryByDevice(@PathVariable UUID deviceId, @PathVariable Integer countTracks) {
		try {
			List<TracksHistory> tracksHistories = downloadTrackService.getTracksHistoryByDevice(deviceId, countTracks);
			return new ResponseEntity<>(tracksHistories, HttpStatus.OK);
		}catch (Exception ex){
			return new ResponseEntity<>(HttpStatus.NOT_FOUND);
		}
	}

	//возвращает историю выдачи и рейтинг прослушивания треков для данного устройства
	@RequestMapping(value = "/{deviceId}/{countTracks}/gettracksratingbydevice", method = RequestMethod.GET)
	public ResponseEntity<?> getTracksRatingByDevice(@PathVariable UUID deviceId, @PathVariable Integer countTracks) {
		try {
			List<TracksRating> tracksRatings = downloadTrackService.getTracksRatingByDevice(deviceId, countTracks);
			return new ResponseEntity<>(tracksRatings, HttpStatus.OK);
		}catch (Exception ex){
			return new ResponseEntity<>(HttpStatus.NOT_FOUND);
		}
	}

	@RequestMapping(value = "/getlastdevices", method = RequestMethod.GET)
	public ResponseEntity<?> getLastDevices() {
		try{
			List<Device> lastActiveDevices = deviceService.getLastDevices();
			return new ResponseEntity<>(lastActiveDevices, HttpStatus.OK);
		}catch (Exception ex){
			return new ResponseEntity<>(HttpStatus.NOT_FOUND);
		}
	}

	//возвращает пользователей, количество дослушанных ими треков, количество скачанных треков
	//отсортированных по убыванию активности (по последнему запросу трека)
	@RequestMapping(value = "/getlastusers/{countUsers}", method = RequestMethod.GET)
	public ResponseEntity<?> getLastUsers(@PathVariable Integer countUsers) {
		try{
			List<UsersRating> lastActiveDevices = userService.getLastUsers(countUsers);
			return new ResponseEntity<>(lastActiveDevices, HttpStatus.OK);
		}catch (Exception ex){
			return new ResponseEntity<>(HttpStatus.NOT_FOUND);
		}
	}

	//возвращает логи по deviceid
	@RequestMapping(value = "/getlogbydeviceid/{deviceId}", method = RequestMethod.GET)
	public ResponseEntity<?> getLogsByDeviceId(@PathVariable UUID deviceId) {
		try{
			List<Log> logList = logService.getByDeviceId(deviceId);
			return new ResponseEntity<>(logList, HttpStatus.OK);
		}catch (Exception ex){
			return new ResponseEntity<>(HttpStatus.NOT_FOUND);
		}
	}

}

