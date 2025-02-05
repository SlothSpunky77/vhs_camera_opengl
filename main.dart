//TODO: fix the issue with the app glitching out when the shutter is pressed consecutively
//TODO: fix the zoom taking time to zoom out after hitting the max zoom value
//TODO: allow the user to set custom framerate
//TODO: allow the user to set custom resolution
//TODO: add a fisheye lens effect as an option as well
//TODO: fix the focus point issue where on max zoom, it doesn't retain the focus value, most likely because of autofocus
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
// import 'package:flutter_gl/flutter_gl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  //bool fourToThree = true;

  //camera toggle
  bool photoMode = false;
  int camIndex = 0;
  //zoom
  double minZoom = 1.0;
  double maxZoom = 20.0; //change these later to generalize for all phones
  double zoom = 1.0;
  Timer? zoomTimer;
  //focus
  Offset? focusPoint;
  //video
  bool isRecording = false;
  //TODO: implement sounds later
  //filters
  // final FlutterGlPlugin _glPlugin = FlutterGlPlugin();
  // late int _framebufferTexture;
  // late int _shaderProgram;
  // late int _uBlurAmountLocation;

  // Future<void> _initGL() async {
  //   await _glPlugin.initialize(options: {
  //     "antialias": true,
  //     "alpha": false,
  //   });

  //   await _glPlugin.prepareContext();

  //   final gl = _glPlugin.gl;

  //   // Create a framebuffer
  //   final framebuffer = gl.createFramebuffer();
  //   gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);

  //   // Create a texture to render the camera feed
  //   _framebufferTexture = gl.createTexture();
  //   gl.bindTexture(gl.TEXTURE_2D, _framebufferTexture);
  //   gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  //   gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  // }

  // void _setupShader() {
  //   final gl = _glPlugin.gl;

  //   // Load shader source
  //   String vertexShaderSource = '''
  // attribute vec4 position;
  // attribute vec2 texCoord;
  // varying vec2 vTexCoord;

  // void main() {
  //     vTexCoord = texCoord;
  //     gl_Position = position;
  // }
  // ''';

  //   String fragmentShaderSource = 'assets/blur.glsl';

  //   int vertexShader = _compileShader(gl, vertexShaderSource, gl.VERTEX_SHADER);
  //   int fragmentShader =
  //       _compileShader(gl, fragmentShaderSource, gl.FRAGMENT_SHADER);

  //   _shaderProgram = gl.createProgram();
  //   gl.attachShader(_shaderProgram, vertexShader);
  //   gl.attachShader(_shaderProgram, fragmentShader);
  //   gl.linkProgram(_shaderProgram);

  //   _uBlurAmountLocation = gl.getUniformLocation(_shaderProgram, "uBlurAmount");
  // }

  // int _compileShader(dynamic gl, String source, int type) {
  //   int shader = gl.createShader(type);
  //   gl.shaderSource(shader, source);
  //   gl.compileShader(shader);
  //   return shader;
  // }

  Future<void> _setupCameraController() async {
    List<CameraDescription> _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      setState(() {
        cameras = _cameras;
        controller = CameraController(cameras[camIndex], ResolutionPreset.low);
      });
      controller?.initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
      }).catchError((Object e) {
        //error handling
      });
    }
  }

  Future<void> _switchCamera() async {
    if (controller != null || controller?.value.isInitialized == false) {
      controller!.dispose();
    }
    camIndex = camIndex == 0 ? 1 : 0;
    setState(() {
      controller = CameraController(
        cameras[camIndex],
        ResolutionPreset.medium,
        enableAudio: true,
      );
    });
    controller?.initialize().then((_) {
      if (mounted) {
        setState(() {});
      }
    }).catchError((Object e) {
      //error handling
    });
  }

  Future<void> _setFocusPoint(Offset tapPosition) async {
    if (controller != null || controller?.value.isInitialized == false) {
      try {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Size previewSize = renderBox.size;

        // Normalize the focus point
        final double dx = tapPosition.dx / previewSize.width;
        final double dy = tapPosition.dy / previewSize.height;
        controller!.setFocusPoint(Offset(dx, dy));
        setState(() {
          focusPoint = Offset(dx, dy);
        });
        await Future.delayed(Duration(seconds: 1));
        setState(() {
          focusPoint = null;
        });
      } catch (e) {
        print("Focus point failed to set: $e");
      }
    }
  }

  Future<void> _startRecording() async {
    if (controller != null || controller?.value.isInitialized == false) {
      //if (controller.value.isRecordingVideo) return;
      await controller!.startVideoRecording();
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (controller != null || controller?.value.isInitialized == false) {
        //if (controller!.value.isRecordingVideo) {
        XFile video = await controller!.stopVideoRecording();
        // Define a new path with an .mp4 extension
        final videoPath = video.path.replaceAll('.temp', '.mp4');
        final videoFile = File(video.path);
        await videoFile.rename(videoPath);
        Gal.putVideo(videoPath);
        //}
      }
    } catch (e) {
      print("Error saving video file: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (controller == null || controller?.value.isInitialized == false) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCameraController();
    }
  }

  @override
  void initState() {
    super.initState();
    _setupCameraController();
    // _initGL();
  }

  // @override
  // void dispose() {
  //   controller.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    if (controller == null || controller?.value.isInitialized == false) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('VHS Camera'),
        ),
        body: SafeArea(
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // -- aspect ratio toggle code
                // IconButton(
                //     onPressed: () {
                //       setState(() {
                //         fourToThree = !fourToThree;
                //         _setupCameraController();
                //       });
                //     },
                //     icon: Icon(Icons.aspect_ratio_rounded)),
                // fourToThree
                //     ? SizedBox(
                //         width: (3 * MediaQuery.sizeOf(context).height) / 4,
                //         height: (4 * MediaQuery.sizeOf(context).width) / 3,
                //         child: CameraPreview(controller!),
                //       )
                //     : SizedBox(
                //         width: (9 * MediaQuery.sizeOf(context).height) / 16,
                //         height: (16 * MediaQuery.sizeOf(context).width) / 9,
                //         child: CameraPreview(controller!),
                //       ),
                // --

                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Row(
                    children: [
                      Text('video'),
                      Switch(
                        value: photoMode,
                        onChanged: (value) {
                          setState(() {
                            photoMode = value;
                          });
                        },
                      ),
                      Text('photo'),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Expanded(
                        child: AspectRatio(
                          // aspectRatio: fourToThree ? 3 / 4 : 9 / 16,
                          aspectRatio: 1 / controller!.value.aspectRatio,

                          child: Stack(
                            children: [
                              GestureDetector(
                                onTapDown: (details) {
                                  final Offset tapPosition =
                                      details.localPosition;
                                  _setFocusPoint(tapPosition);
                                  //print(controller!.value.aspectRatio);
                                },
                                child: CameraPreview(controller!),
                              ),
                              // if (_glPlugin.isInitialized)
                              //   Texture(textureId: _glPlugin.textureId!),
                            ],
                          ),
                        ),
                      ),
                      if (focusPoint != null)
                        Expanded(
                          child: Positioned(
                            left: focusPoint!.dx *
                                    MediaQuery.of(context).size.width -
                                15,
                            top: focusPoint!.dy *
                                    MediaQuery.of(context).size.height -
                                15,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: IconButton(
                        onPressed: () {
                          _switchCamera();
                        },
                        icon: Icon(Icons.flip_camera_android_rounded),
                        iconSize: 50,
                      ),
                    ),
                    photoMode
                        ? Expanded(
                            child: Align(
                              alignment: Alignment.center,
                              child: IconButton(
                                onPressed: () async {
                                  XFile picture =
                                      await controller!.takePicture();
                                  Gal.putImage(picture.path);
                                },
                                iconSize: 80,
                                icon: Icon(Icons.camera_outlined),
                              ),
                            ),
                          )
                        : Expanded(
                            child: Align(
                              alignment: Alignment.center,
                              child: IconButton(
                                onPressed: () async {
                                  setState(() {
                                    isRecording = !isRecording;
                                  });
                                  isRecording
                                      ? await _startRecording()
                                      : await _stopRecording();
                                },
                                iconSize: 80,
                                icon: isRecording
                                    ? Icon(Icons.stop_circle_outlined)
                                    : Icon(Icons.fiber_manual_record),
                                color: Colors.red,
                              ),
                            ),
                          ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: EdgeInsets.only(right: 10),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    width: 1,
                                    color: Colors.black,
                                  ),
                                ),
                                child: Expanded(
                                  child: GestureDetector(
                                    child: Icon(
                                      Icons.remove,
                                      size: 50,
                                    ),
                                    onTapDown: (details) {
                                      int duration;
                                      if (zoom > 3) {
                                        duration = 10;
                                      } else {
                                        duration = 25;
                                      }
                                      zoomTimer = Timer.periodic(
                                          Duration(milliseconds: duration),
                                          (timer) {
                                        if (zoom >= minZoom &&
                                            zoom <= maxZoom) {
                                          if (zoom > 3) {
                                            timer.cancel();
                                            // int newDuration = (duration -
                                            //         (zoom / maxZoom) *
                                            //             duration)
                                            //     .floor();
                                            int newDuration = 10;
                                            zoomTimer = Timer.periodic(
                                                Duration(
                                                    milliseconds: newDuration),
                                                (timer) {
                                              if (zoom >= minZoom &&
                                                  zoom <= maxZoom) {
                                                setState(() {
                                                  zoom -= 0.05;
                                                  controller!
                                                      .setZoomLevel(zoom);
                                                });
                                              }
                                            });
                                          } else {
                                            setState(() {
                                              zoom >= minZoom
                                                  ? zoom -= 0.05
                                                  : zoom = minZoom;
                                              controller!.setZoomLevel(zoom);
                                            });
                                          }
                                        } else {
                                          setState(() {
                                            zoom < maxZoom
                                                ? zoom = 1
                                                : zoom = 20;
                                          });
                                          zoomTimer?.cancel();
                                        }
                                      });
                                    },
                                    onTapUp: (details) {
                                      zoomTimer?.cancel();
                                    },
                                    onTapCancel: () => zoomTimer?.cancel(),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    width: 1,
                                    color: Colors.black,
                                  ),
                                ),
                                child: Expanded(
                                  child: StatefulBuilder(
                                    builder: (context, setState) {
                                      return GestureDetector(
                                        child: Icon(
                                          Icons.add,
                                          size: 50,
                                        ),
                                        onTapDown: (details) {
                                          int duration;
                                          if (zoom > 3) {
                                            duration = 20;
                                          } else {
                                            duration = 50;
                                          }
                                          zoomTimer = Timer.periodic(
                                              Duration(milliseconds: duration),
                                              (timer) {
                                            if (zoom >= minZoom &&
                                                zoom <= maxZoom) {
                                              if (zoom > 3) {
                                                timer.cancel();
                                                // int newDuration = (duration -
                                                //         (zoom / maxZoom) *
                                                //             duration)
                                                //     .floor();
                                                int newDuration = 20;
                                                zoomTimer = Timer.periodic(
                                                    Duration(
                                                        milliseconds:
                                                            newDuration),
                                                    (timer) {
                                                  if (zoom >= minZoom &&
                                                      zoom <= maxZoom) {
                                                    setState(() {
                                                      zoom <= maxZoom
                                                          ? zoom += 0.05
                                                          : zoom = maxZoom;
                                                      controller!
                                                          .setZoomLevel(zoom);
                                                    });
                                                  }
                                                });
                                              } else {
                                                setState(() {
                                                  zoom += 0.05;
                                                  controller!
                                                      .setZoomLevel(zoom);
                                                });
                                              }
                                            } else {
                                              setState(() {
                                                zoom > maxZoom
                                                    ? zoom = 20
                                                    : zoom = 1;
                                              });
                                              zoomTimer?.cancel();
                                            }
                                          });
                                        },
                                        onTapUp: (details) {
                                          zoomTimer?.cancel();
                                        },
                                        onTapCancel: () => zoomTimer?.cancel(),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
