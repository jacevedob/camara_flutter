import 'dart:async';
import 'dart:io';
import 'dart:collection';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:amazon_s3_cognito/amazon_s3_cognito.dart';
import 'package:amazon_s3_cognito/image_data.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
      ),
    ),
  );
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
  super.key,
  required this.camera,
  });

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  String _platformVersion = 'Unknown';

  final EventChannel _amazonS3Stream = EventChannel('amazon_s3_cognito_images_upload_steam');
  StreamSubscription? uploadListenerSubscription;

  List<ImageData> filesToUpload = [];

  @override
  void initState() {
    super.initState();
    _listenToFileUpload();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  void _listenToFileUpload() {
    //when you want to upload multi-files or listen to upload then
    //you get the image progress via this stream
    uploadListenerSubscription =
        _amazonS3Stream.receiveBroadcastStream().listen((event) {
          LinkedHashMap<Object?, Object?> map = event;
          print(map);
          ImageData imageData = ImageData.fromMap(map);
          //update the ui based on the object returned in stream
        });
  }

  void uploadMultipleFileUploads() async {
    String bucketName = "test";
    String cognitoPoolId = "your pool id";
    String bucketRegion = "imageUploadRegion";
    String bucketSubRegion = "Sub region of bucket";

    //fileUploadFolder - this is optional parameter
    String fileUploadFolder =
        "folder inside bucket where we want file to be uploaded";

    String filePath = ""; //path of file you want to upload
    ImageData imageData = ImageData("uniqueFileName", filePath,
        uniqueId: "uniqueIdToTrackImage", imageUploadFolder: fileUploadFolder);
    filesToUpload.add(imageData);
    filesToUpload.add(imageData);
    filesToUpload.add(imageData);

    //needProgressUpdateAlso - in event stream you will get progress of the image also
    //needMultipartUpload - only applicable for IOS, when your uploads are so large that they take more than 1 hour to complete set its value to true
    await AmazonS3Cognito.uploadImages(bucketName, cognitoPoolId, bucketRegion,
        bucketSubRegion, filesToUpload, false);
  }

  void uploadSingleImage() async {
    String bucketName = "dermosolutionsweb";
    String cognitoPoolId = "eu-west-1:998b7d2e-b826-4467-ab20-13fb55a66e85";
    String bucketRegion = "US_EAST_1";
    String bucketSubRegion = "Sub region of bucket";

    //fileUploadFolder - this is optional parameter
    String fileUploadFolder =
        "imagenes/";

    String filePath = ""; //path of file you want to upload
    ImageData imageData = ImageData("uniqueFileName", filePath,
        uniqueId: "uniqueIdToTrackImage", imageUploadFolder: fileUploadFolder);

    //result is either amazon s3 url or failure reason
    String? result = await AmazonS3Cognito.upload(
        bucketName, cognitoPoolId, bucketRegion, bucketSubRegion, imageData,
        needMultipartUpload: true);
    //once upload is success or failure update the ui accordingly
    print(result);
  }

  void deleteImage() async {
    String cognitoPoolId = "eu-west-1:cee179be-7130-4698-a0a9-635c282ac98c";
    String bucketRegion = "";
    String bucketSubRegion = "Sub region of bucket";

    //fileUploadFolder - this is optional parameter
    //folder inside bucket where file exists
    //example - if file is there in test/101/abc.jpg. where test is bucket name
    //then fileUploadFolder = "101/"

    String bucketName = "dermosolutionsweb";
    String fileUploadFolder = "imagenes/";
    String fileName = "abcd.jpeg";

    String? result = await AmazonS3Cognito.delete(bucketName, cognitoPoolId,
        fileName, fileUploadFolder, bucketRegion, bucketSubRegion);

    if (result != null) {
      print(result);
    }
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a picture')),
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;

            // Attempt to take a picture and get the file `image`
            // where it was saved.
            final image = await _controller.takePicture();

            if (!mounted) return;
            deleteImage();

            // If the picture was taken, display it on a new screen.
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(
                  // Pass the automatically generated path to
                  // the DisplayPictureScreen widget.
                  imagePath: image.path,
                ),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image.file(File(imagePath)),
    );
  }
}