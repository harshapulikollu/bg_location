import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive_io.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
part 'location_state.dart';

class LocationCubit extends Cubit<LocationState> {
  LocationCubit() : super(LocationInitial()){
    initializeService();
  }

  final service = FlutterBackgroundService();
  bool isRunning = false;

  final String _csvFilePath = 'hp_db_location.csv';

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'hp_bg_location',
      'HP BG LOCATION FG SERVICE',
      description:
      'This channel is used for important notifications.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
        ),
      );
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background in separated isolate
        onStart: onStart,

        // auto start service
        autoStart: false,
        isForegroundMode: true,

        notificationChannelId: 'hp_bg_location',
        initialNotificationTitle: 'HP BG LOCATION FG SERVICE',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 0123,
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: false,

        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,

        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );

    // service.startService();
  }

  @pragma('vm:entry-point')
  Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // get location and save it in DB
    checkLocationPermission();
    return true;
  }


  Future<void> checkLocationPermission() async{
    try {
      bool locationServiceStatus = await Geolocator.isLocationServiceEnabled();
      if(!locationServiceStatus){
        emit(const LocationError(message: 'GPS service is not enabled'));
        return;
      }
      await _getLocationPermission();
    } on Exception catch (e) {
      emit(LocationError(message: e.toString()));
    }
  }

  Future<void> _getLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(const LocationError(message: 'Location permissions are denied'));
        }else if(permission == LocationPermission.deniedForever){
          emit(const LocationError(message: 'Location permissions are permanently denied'));
        }else{
          startBackgroundService();
          getLocationCoordinates();
        }
      }else{
        startBackgroundService();
        getLocationCoordinates();
      }
    } on Exception catch (e) {
      emit(LocationError(message: e.toString()));
    }
  }

  // Future<void> _getLocationCoordinates() async {
  //   try {
  //     Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  //     await _saveToCsvFile(position.latitude, position.longitude);
  //   } on Exception catch (e) {
  //     emit(LocationError(message: e.toString()));
  //   }
  // }
  //
  // Future<void> _saveToCsvFile(double latitude, double longitude) async{
  //  try{
  //    final path = (await getApplicationDocumentsDirectory()).path;
  //    File csvFile = File('$path/$_csvFilePath');
  //    if(!csvFile.existsSync()){
  //      csvFile = await File('$path/$_csvFilePath').create(recursive: true);
  //    }
  //    /// Reading the file
  //    String contents = await csvFile.readAsString();
  //     debugPrint("contents of file: $contents");
  //    /// Appending to file
  //    contents += '${DateTime.now()}, $latitude, $longitude\n';
  //
  //    /// Writing back to file
  //    csvFile.writeAsString(contents);
  //  }on Exception catch (e) {
  //    emit(LocationError(message: e.toString()));
  //  }
  // }

  Future<void> _zipTheFile() async {
    final ZipFileEncoder encoder = ZipFileEncoder();
    // String? downloadPath = await getDownloadPath() ?? (await getApplicationDocumentsDirectory()).path;
    final String zipFilePath = join((await getExternalStorageDirectory())!.path, 'hp_bg_location_${DateTime.now()}.zip');
    encoder.create(zipFilePath);

    final path = (await getApplicationDocumentsDirectory()).path;
    File csvFile = File('$path/$_csvFilePath');
    encoder.addFile(csvFile);
    encoder.close();
    emit(LocationStopped(message: 'Saved ZIP file to $zipFilePath'));
  }

  Future<String?> getDownloadPath() async {
    Directory? directory;
    try {
      if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) directory = (await getExternalStorageDirectory())!;
      }
    } catch (err, stack) {
      debugPrint('Cannot get download folder path');
    }
    return directory?.path;
  }

  void stopBackgroundService() {
    service.invoke("stopService");
    isRunning = false;
    _zipTheFile();
  }

  void startBackgroundService() {
    service.startService();
    isRunning = true;
    emit(LocationStarted());
  }
}


@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();


  /// OPTIONAL when use custom notification
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) async{
    service.stopSelf();
  });

  // bring to foreground
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        /// OPTIONAL for use custom notification
        /// the notification id must be equals with AndroidConfiguration when you call configure() method.
        flutterLocalNotificationsPlugin.show(
          0123,
          'HP BG LOCATION FG SERVICE',
          'Last location updated at ${DateTime.now()}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'hp_bg_location',
              'HP BG LOCATION FG SERVICE',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );
      }
    }

    /// you can see this log in logcat
    debugPrint('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');
    getLocationCoordinates();
  });
}

Future<void> getLocationCoordinates() async {
  try {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    await saveToCsvFile(position.latitude, position.longitude);
  } on Exception catch (e) {
    // emit(LocationError(message: e.toString()));
  }
}

Future<void> saveToCsvFile(double latitude, double longitude) async{
  try{
    const String csvFilePath = 'hp_db_location.csv';
    final path = (await getApplicationDocumentsDirectory()).path;
    File csvFile = File('$path/$csvFilePath');
    if(!csvFile.existsSync()){
      csvFile = await File('$path/$csvFilePath').create(recursive: true);
    }
    /// Reading the file
    String contents = await csvFile.readAsString();
    debugPrint("contents of file: $contents");
    /// Appending to file
    contents += '${DateTime.now()}, $latitude, $longitude\n';

    /// Writing back to file
    csvFile.writeAsString(contents);
  }on Exception catch (e) {
    // emit(LocationError(message: e.toString()));
  }
}

