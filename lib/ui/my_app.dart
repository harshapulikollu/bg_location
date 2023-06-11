import 'package:bg_location/cubit/location_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter BG Location',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: BlocProvider<LocationCubit>(
        create: (context) => LocationCubit(),
        child: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('HP BG Location '),
      ),
      body: BlocBuilder<LocationCubit, LocationState>(
        builder: (context, state) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                    onPressed: () async{
                      if (context.read<LocationCubit>().isRunning) {
                        Map<Permission, PermissionStatus> statuses = await [
                          Permission.storage,
                        ].request();
debugPrint('permission $statuses, ${statuses[Permission.storage]}');
                        if (statuses[Permission.storage] != PermissionStatus.granted){
                          bool isShown = await Permission.storage.shouldShowRequestRationale;
                          if(!isShown){
                            context.read<LocationCubit>().emit(const LocationError(message: 'Storage permission not granted'));
                          }
                          return;
                        }
                        context.read<LocationCubit>().stopBackgroundService();
                      } else {
                        context.read<LocationCubit>().checkLocationPermission();
                      }
                    },
                    child: Text(context.read<LocationCubit>().isRunning
                        ? 'Stop service'
                        : 'Start Service'),),
                if(state is LocationError)
                  Text(state.message)
                else if(state is LocationStopped)
                  Text(state.message)
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }
}
