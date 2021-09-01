import 'dart:io';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:flutter_webview_plugin/src/javascript_channel.dart';
import 'package:flutter_webview_plugin/src/javascript_message.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:location_permissions/location_permissions.dart';
import 'package:connectivity/connectivity.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_dialogs/flutter_dialogs.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cron/cron.dart';
import 'package:http/http.dart' as http;

// COMO GENERAR APK: https://stackoverflow.com/questions/55536637/how-to-build-signed-apk-from-android-studio-for-flutter
// RUTA QUE SE GENERA: C:\Users\Luigi\Desktop\appki\android\app\release


import 'package:flutter_downloader/flutter_downloader.dart';
//import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
//import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:printing/printing.dart';


// CONVERTIR DE BASE DE DATOS:
// Ejm: sql server a Mysql
// http://www.sqlines.com/online

// MODO DESARROLLADOR
// final String urlAki = 'about:blank'; // LOCAL BLANCK PAGE
//final String urlAki = 'http://192.168.0.102:81/appAki/layouts/login'; // LOCAL
//final String urlRepartidorCoordenadas = 'http://192.168.0.102:81/appAki/servicios/Repartidor.php'; // LOCAL
//final String rutaPDF = 'http://192.168.0.102:81/appAki/servicios/archivos/despacho_recojo/'; // LOCAL

// MODO EN PRODUCCIÓN
final String urlAki = 'https://demo1.reidemotech.com/layouts/login';
final String urlRepartidorCoordenadas = 'https://demo1.reidemotech.com/servicios/Repartidor.php';
final String rutaPDF = 'https://demo1.reidemotech.com/servicios/archivos/despacho_recojo/';

// GENERAL
//final String pdfPrueba = 'https://eqpro.es/wp-content/uploads/2018/11/Ejemplo.pdf';
final String androidUserAgent = "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Mobile Safari/537.36";

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // https://pub.dev/packages/permission_handler
  // https://stackoverflow.com/a/59080641/16488926
  await Permission.camera.request();
  await Permission.microphone.request();

  // https://pub.dev/packages/location_permissions
  // https://pub.dev/packages/location_permissions/example
  await LocationPermissions().requestPermissions();
  await LocationPermissions().checkPermissionStatus();
  await LocationPermissions().checkServiceStatus();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  await FlutterDownloader.initialize(
      debug: true // optional: set false to disable printing logs to console
  );
  await Permission.storage.request();
  runApp(MyApp());
}

class MyApp extends StatefulWidget{
  @override
  _MyAppState createState() => _MyAppState();
}

String result = "";
String locationMessage = "";
bool _isOnline = true;

class ConnectionStatusModel extends ChangeNotifier{
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription _connectionSubscription;

  ConnectionStatusModel(){
    _connectionSubscription = _connectivity.onConnectivityChanged
    .listen((_) => _checkInternetConnection());
    _checkInternetConnection();
  }
  bool get isOnline => _isOnline;

  Future<void> _checkInternetConnection() async{
    try{
      await Future.delayed(const Duration(seconds: 60));
      final result = await InternetAddress.lookup(urlAki);
      if(result.isNotEmpty && result[0].rawAddress.isNotEmpty){
        _isOnline = true;
      }else{
        _isOnline = false;
      }
    }on SocketException catch(_){
      _isOnline = false;
    }
    notifyListeners();
  }

  @override
  void dispose(){
    _connectionSubscription.cancel();
    super.dispose();
  }

}

class _MyAppState extends State<MyApp>{
  get device => null;

  late WebViewController controller;
  final FlutterWebviewPlugin webviewPlugin = new FlutterWebviewPlugin();
  bool ocultar = false;
  late Position _currentPosition;
  late Timer timer;

  late String Latitud = "";
  late String Longitud = "";

  late StreamSubscription<String> _onStateChanged;
  final flutterWebviewPlugin = new FlutterWebviewPlugin();

  // INICIA LA CONECTIVIDAD A INTERNET
  @override
  void initState() {
    CheckStatus();
    webviewPlugin.dispose();
    super.initState();

    flutterWebviewPlugin.onStateChanged.listen((WebViewStateChanged wvs) {});

    // https://www.codegrepper.com/code-examples/whatever/flutter+run+function+every+second
    timer = Timer.periodic(Duration(seconds: 20), (Timer t) => {
      checkForNewSharedLists()
    });

    // VERIFICO SI EXISTE EL DOCUMENTO
    timer = Timer.periodic(Duration(seconds: 3), (Timer t) => {
      pdfExist()
    });
  }
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      home: WillPopScope(
        onWillPop: () async{
          String url = await controller.currentUrl() as String;
          if(url == urlAki){
            return true;
          }else{
            controller.goBack();
            return false;
          }
        },
        child: Scaffold(
          body: Container(
            child: SafeArea(
            //child: WebView(
              child: WebviewScaffold(
                userAgent: androidUserAgent,
                url: ocultar == false ? urlAki : Uri.dataFromString('<html><body><center>Ups! No tiene conexion a internet, Intente de Nuevo.</center></body></html>', mimeType: 'text/html').toString(),
                withJavascript: true,
                withZoom: false,
                hidden: _isOnline,
                withLocalStorage: true,
                mediaPlaybackRequiresUserGesture: false,
                enableAppScheme: true,
                appCacheEnabled: true,
                clearCookies: true,
                clearCache: true,
                allowFileURLs: true,
                initialChild: Container(
                  color: Colors.white,
                  child: const Center(
                    child: Text(
                      'Cargando......',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
            ),
            ),
          ),
        ),

      ),
    );
  }

  Future check() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        ocultar = true;
      }
    } on SocketException catch (_) {
      ocultar = false;
    }
  }

  Future<File> getFileFromUrl(String url) async {
    try {
      var data = await http.get(Uri.parse(url));
      var bytes = data.bodyBytes;
      var dir = await getApplicationSupportDirectory();
      File file = File("${dir.path}/some.pdf");

      File urlFile = await file.writeAsBytes(bytes);
      return urlFile;
    } catch (e) {
      throw Exception("Error opening url file");
    }
  }

  void pdfExist() async{
    try {
      var pdfExist =  await webviewPlugin.evalJavascript("document.getElementById('idpdfexist').value");

      if(
        pdfExist.toString().replaceAll('"', '') != "null" &&
        pdfExist.toString().replaceAll('"', '') != ""
      ){
        var macPrint =  await webviewPlugin.evalJavascript("document.getElementById('macimpresora').value");
        macPrint = macPrint.toString().replaceAll('"', '');
        pdfExist = pdfExist.toString().replaceAll('"', '');



        var data = await http.get(Uri.parse(rutaPDF + pdfExist.toString()));
        await Printing.sharePdf(bytes: data.bodyBytes, filename: 'ticket.pdf');

        await webviewPlugin.evalJavascript("document.getElementById('idpdfexist').value = '';");
        await webviewPlugin.evalJavascript("document.getElementById('closeTicket').click();");
        await webviewPlugin.evalJavascript("document.getElementById('recargarpagina').click();");

      }
    } on Exception catch (_) {}
  }

  // PARA VERIFICAR SI TIENE INTERNET - TIEMPO REAL SOCKET
  void CheckStatus(){
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
        ocultar = false;
        webviewPlugin.show();
        String result = "Connected";
        // https://stackoverflow.com/a/49940765/16488926
        log('data: En Linea');
      } else {
        ocultar = true;
        try {
          webviewPlugin.hide();
        } catch (e) {
          log('Hubo un problema Toast'+ e.toString());
        }
        String result = "No Internet";
        log('data: Sin Internet');
      }
    });
  }

  getCurrentLocation() async{
    var position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    var lastPosition = await Geolocator.getLastKnownPosition();

    setState(() {
      Latitud = position.latitude.toString();
      Longitud = position.longitude.toString();
    });
  }

  checkForNewSharedLists() async{
    // Ejm: https://stackoverflow.com/a/61680740/16488926
    // Ejm Pasar Datos: https://flutter.dev/docs/cookbook/networking/fetch-data
    try {
      getCurrentLocation();
      var getIdRepartidor =  await webviewPlugin.evalJavascript("document.getElementById('idrepartidor').value");
      await http.get(Uri.parse(urlRepartidorCoordenadas+'?cmd=obtenercoordenadasrepartidor&latitud='+Latitud+'&longitud='+Longitud+'&idrepartidor='+getIdRepartidor.toString().replaceAll('"', '')));
      log("Coordenadas Registradas");
    } on Exception catch (_) {}

  }

}