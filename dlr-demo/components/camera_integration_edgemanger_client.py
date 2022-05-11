#
# Copyright 2010-2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
import cv2,os
import numpy as np
import random
import argparse
import time
import json
import awsiot.greengrasscoreipc
from awsiot.greengrasscoreipc.model import (
    QOS,
    PublishToIoTCoreRequest
)
import math
import agent_pb2_grpc
import grpc
from agent_pb2 import (ListModelsRequest, LoadModelRequest, PredictRequest,
                       UnLoadModelRequest, DescribeModelRequest, CaptureDataRequest, Tensor, 
                       TensorMetadata, Timestamp)
import signal
import sys
import uuid

import gi
import cairo
gi.require_version('Gst', '1.0')
gi.require_foreign('cairo')
gi.require_version('GstRtspServer', '1.0')
from gi.repository import Gst, GObject, GstRtspServer, GLib


parser = argparse.ArgumentParser()
parser.add_argument('-s', '--stream', action='store', type=str, required=True, dest='stream_path', help='Video source URL')
parser.add_argument('-c', '--model-component', action='store', type=str, required=True, dest='model_component_name', help='Name of the GGv2 component containing the model')
parser.add_argument('-m', '--model-name', action='store', type=str, required=True, dest='model_name', help='Friendly name of the model from Edge Packaging Job')
parser.add_argument('-q', '--quantized', action='store', type=str, required=True, dest='quant', help='Is the model quantized?')
parser.add_argument('-p', '--port', action='store', type=str, required=True, dest='port', default=False, help='Port for RTSP server')


args = parser.parse_args()

stream_path = args.stream_path
rtsp_port = args.port
model_component_name = args.model_component_name
model_name = args.model_name
quant = args.quant == 'True'
ting_name = os.getenv('AWS_IOT_THING_NAME')

print ('Greengrass thing name is ' + ting_name)
print ('Video source is at ' + stream_path)
print ('Model Greengrass v2 component name is ' + model_component_name)
print ('Model name is ' + model_name)
print ('Model is quantized: ' + str(quant))

model_url = '/greengrass/v2/work/' + model_component_name
tensor_name = 'normalized_input_image_tensor'
SIZE = 300
tensor_shape = [1, SIZE, SIZE, 3]

inference_result_topic = "em/inference"
ipc_client = awsiot.greengrasscoreipc.connect()

channel = grpc.insecure_channel('unix:///tmp/sagemaker_edge_agent_example.sock')
edge_manager_client = agent_pb2_grpc.AgentStub(channel)


class ObjectDetection(GstRtspServer.RTSPMediaFactory):
    """NNStreamer example for Object Detection."""

    def __init__(self, argv=None):
        GstRtspServer.RTSPMediaFactory.__init__(self)
        self.pipeline = None
        self.video_caps = None
        self.inference_result = None

        self.VIDEO_WIDTH = 1280
        self.VIDEO_HEIGHT = 720
        self.MODEL_WIDTH = 300
        self.MODEL_HEIGHT = 300
        self.count = 0

    def do_create_element(self, url):
        """Init pipeline and run example.
        :return: None
        """
        print("Run: NNStreamer example for object detection.")
        gst_launch_cmdline = ''
        if os.path.exists(stream_path):
            gst_launch_cmdline = ' filesrc location={:s} ! matroskademux ! h264parse !'.format(stream_path)
            gst_launch_cmdline += '  queue name=thread-decode max-size-buffers=2 ! vpudec ! imxvideoconvert_g2d !'
        else:
            gst_launch_cmdline = ' rtspsrc location=rtsp://admin:a12345678@10.193.20.59:554/h264/ch1/main/av_stream ! decodebin !'.format(stream_path)
            gst_launch_cmdline += '  queue name=thread-decode max-size-buffers=2 ! imxvideoconvert_g2d !'

        gst_launch_cmdline += '  video/x-raw,width={:d},height={:d} ! tee name=t '.format(self.VIDEO_WIDTH, self.VIDEO_HEIGHT)
        gst_launch_cmdline += ' t. ! queue name=thread-nn max-size-buffers=2 leaky=2 !'
        gst_launch_cmdline += '  imxvideoconvert_g2d !'
        gst_launch_cmdline += '  video/x-raw,width={:d},height={:d},format=RGBA !'.format(self.MODEL_WIDTH, self.MODEL_HEIGHT)
        gst_launch_cmdline += '  videoconvert ! video/x-raw,format=RGB !'
        gst_launch_cmdline += '  appsink name=sink drop=True max-buffers=1 emit-signals=True sync=False'
        gst_launch_cmdline += ' t. ! queue name=thread-img max-size-buffers=2 !'
        gst_launch_cmdline += ' cairooverlay name=drawlay ! videoconvert !'
        gst_launch_cmdline += " vpuenc_h264 ! rtph264pay name=pay0 pt=96"

        print(gst_launch_cmdline)

        self.pipeline = Gst.parse_launch(gst_launch_cmdline)

        appsink = self.pipeline.get_by_name('sink')
        appsink.connect("new-sample", self.on_new_frame, appsink)
        drawlay = self.pipeline.get_by_name('drawlay')
        drawlay.connect('draw', self.draw_overlay_cb)
        drawlay.connect('caps-changed', self.prepare_overlay_cb)
        #get the static source pad of the element
        drawpad = drawlay.get_static_pad('src')

        self.inference_result = None

        return self.pipeline


    # Inference
    def inference(self, img):
        nn_input = img
        #Run the model
        request = PredictRequest(name=model_name, tensors=[Tensor(tensor_metadata=TensorMetadata(
            name=tensor_name, data_type=5, shape=tensor_shape), byte_data=img.tobytes())])
        response = edge_manager_client.Predict(request)
        self.inference_result = process_output_tensor(response)

    # Pipeline 1 output
    def on_new_frame(self, sink, data):
        sample = sink.emit("pull-sample")
        captured_gst_buf = sample.get_buffer()
        caps = sample.get_caps()
        im_height_in = caps.get_structure(0).get_value('height')
        im_width_in = caps.get_structure(0).get_value('width')
        mem = captured_gst_buf.get_all_memory()
        success, arr = mem.map(Gst.MapFlags.READ)
        img = np.ndarray((im_height_in,im_width_in,3),buffer=arr.data,dtype=np.uint8)
        self.inference(img)
        mem.unmap(arr)
        return Gst.FlowReturn.OK


    def probe_callback(self, pad, info):
        buf = info.get_buffer()
        pts = buf.pts
        buf.pts = pts + self.inference_ns

        return Gst.PadProbeReturn.OK

    # @brief Store the information from the caps that we are interested in.
    def prepare_overlay_cb(self, overlay, caps):
        self.video_caps = caps
        print("caps is enabled")

    # @brief Callback to draw the overlay.
    def draw_overlay_cb(self, overlay, context, timestamp, duration):
        if self.video_caps == None or self.inference_result is None:
            return

        timestamp = timestamp - duration

        drawed = 0
        context.select_font_face('Sans', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        context.set_font_size(12.0)

        num = self.inference_result["number"][0]
        labels = self.inference_result["labels"]
        scores = self.inference_result["scores"]
        boxes = self.inference_result["boxes"]

        msg = ting_name + ":"
        for i in range(num):
            if scores[i] <= 0.5:
                continue
            label = label2string[labels[i]]
            box = [boxes[i*4], boxes[i*4+1], boxes[i*4+2], boxes[i*4+3]]

            x=int(box[1] * self.VIDEO_WIDTH)
            y=int(box[0] * self.VIDEO_HEIGHT)
            width=int(box[3] * self.VIDEO_WIDTH) - x
            height=int(box[2] * self.VIDEO_HEIGHT) - y

            if label == "Person":
              color= [0,255,255]
            elif label == "Car":
              color=[255,255,0]
            elif label=="Bus":
              color=[255,0,255]
            else:
              color=[1,0,0]
            # draw rectangle
            context.rectangle(x, y, width, height)
            context.set_source_rgb(color[0], color[1], color[2]) #1, 0, 0)
            context.set_line_width(0.8)
            context.stroke()
            context.fill_preserve()

            # draw title
            context.move_to(x , y-2 )
            context.text_path(label)
            context.set_source_rgb(color[0], color[1], color[2]) #1, 0, 0)
            context.fill_preserve()
            context.set_source_rgb(color[0], color[1], color[2]) #1, 0, 0)
            context.set_line_width(0.2)
            context.stroke()
            context.fill_preserve()

            msg += label2string[labels[i]] + ","

        if (self.count == 30):
            publish_results_to_iot_core(msg)
            self.count = 0
        self.count += 1

class GstServer():
    def __init__(self):
        # Gstreamer Init
        self.loop = GLib.MainLoop()
        Gst.init(None)

        self.server = GstRtspServer.RTSPServer()
        self.server.set_service(rtsp_port)
        self.f = ObjectDetection()
        self.f.set_shared(True)
        m = self.server.get_mount_points()
        m.add_factory("/object_detection", self.f)
        self.server.attach(None)

    def run(self):
        self.loop.run()

# When the component is stopped.
def sigterm_handler(signum, frame):
    global edge_manager_client
    try:
        print ('In sigterm_handler..........')
        time.sleep(1)
        response = edge_manager_client.UnLoadModel(UnLoadModelRequest(name=model_name))
        sys.exit(0)
    except Exception as e:
        print ('Model failed to unload')
        print (e)
        sys.exit(-1)

signal.signal(signal.SIGINT, sigterm_handler)
signal.signal(signal.SIGTERM, sigterm_handler)

def preprocess_frame(captured_frame):

    if not quant:
        frame = resize_short_within(captured_frame, short=SIZE, max_size=SIZE * 2)
        scaled_frame = cv2.resize(frame, (SIZE, int(SIZE/4 * 3 )))
        scaled_frame = cv2.copyMakeBorder(scaled_frame, int(SIZE / 8), int(SIZE / 8),
                                    0, 0, cv2.BORDER_CONSTANT, value=(0, 0, 0))
        scaled_frame = np.asarray(scaled_frame)
        # normalization according to https://github.com/tensorflow/tensorflow/blob/
        # a4dfb8d1a71385bd6d122e4f27f86dcebb96712d/tensorflow/python/keras/applications/imagenet_utils.py#L259
        scaled_frame = (scaled_frame/127.5).astype(np.float32)
        scaled_frame -= 1.
        return scaled_frame
    
    else:
        img = cv2.cvtColor(captured_frame, cv2.COLOR_BGR2RGB)
        img = cv2.resize(img, (SIZE,SIZE))
        scaled_frame = img.astype(np.uint8)
        return scaled_frame

label2string = {
        0:   "person",
        1:   "bicycle",
        2:   "car",
        3:   "motorcycle",
        4:   "airplane",
        5:   "bus",
        6:   "train",
        7:   "truck",
        8:   "boat",
        9:   "traffic light",
        10:  "fire hydrant",
        12:  "stop sign",
        13:  "parking meter",
        14:  "bench",
        15:  "bird",
        16:  "cat",
        17:  "dog",
        18:  "horse",
        19:  "sheep",
        20:  "cow",
        21:  "elephant",
        22:  "bear",
        23:  "zebra",
        24:  "giraffe",
        26:  "backpack",
        27:  "umbrella",
        30:  "handbag",
        31:  "tie",
        32:  "suitcase",
        33:  "frisbee",
        34:  "skis",
        35:  "snowboard",
        36:  "sports ball",
        37:  "kite",
        38:  "baseball bat",
        39:  "baseball glove",
        40:  "skateboard",
        41:  "surfboard",
        42:  "tennis racket",
        43:  "bottle",
        45:  "wine glass",
        46:  "cup",
        47:  "fork",
        48:  "knife",
        49:  "spoon",
        50:  "bowl",
        51:  "banana",
        52:  "apple",
        53:  "sandwich",
        54:  "orange",
        55:  "broccoli",
        56:  "carrot",
        57:  "hot dog",
        58:  "pizza",
        59:  "donut",
        60:  "cake",
        61:  "chair",
        62:  "couch",
        63:  "potted plant",
        64:  "bed",
        66:  "dining table",
        69:  "toilet",
        71:  "tv",
        72:  "laptop",
        73:  "mouse",
        74:  "remote",
        75:  "keyboard",
        76:  "cell phone",
        77:  "microwave",
        78:  "oven",
        79:  "toaster",
        80:  "sink",
        81:  "refrigerator",
        83:  "book",
        84:  "clock",
        85:  "vase",
        86:  "scissors",
        87:  "teddy bear",
        88:  "hair drier",
        89:  "toothbrush"}

# read output tensors and append them to matrix
def process_output_tensor(response):

    tensors = response.tensors
    detections = {}
    deserialized_bytes = np.frombuffer(tensors[0].byte_data, dtype=np.float32)
    detections["boxes"] = np.asarray(deserialized_bytes).tolist()
    deserialized_bytes = np.frombuffer(tensors[1].byte_data, dtype=np.float32)
    detections["labels"] = np.asarray(deserialized_bytes)
    deserialized_bytes = np.frombuffer(tensors[2].byte_data, dtype=np.float32)
    detections["scores"] = np.asarray(deserialized_bytes).tolist()
    deserialized_bytes = np.frombuffer(tensors[3].byte_data, dtype=np.int32)
    detections["number"] = np.asarray(deserialized_bytes).tolist()

    return detections

# IPC publish to IoT Core
def publish_results_to_iot_core (message):
    # Publish highest confidence result to AWS IoT Core
    global ipc_client
    request = PublishToIoTCoreRequest()
    request.topic_name = inference_result_topic
    request.payload = bytes(json.dumps(message), "utf-8")
    request.qos = QOS.AT_LEAST_ONCE
    operation = ipc_client.new_publish_to_iot_core()
    operation.activate(request)
    future = operation.get_response()
    future.result(10)

def run():
    try:
        print("Tring to unload model first.")
        response = edge_manager_client.UnLoadModel(UnLoadModelRequest(name=model_name))
    except Exception as e:
        pass

    while (True):
        try:
            response = edge_manager_client.LoadModel(
                LoadModelRequest(url=model_url, name=model_name))
            break
        except Exception as e:
            print('Model failed to load')
            sys.exit(-1)

    print("Model loaded....")
    s = GstServer()
    s.run()


## Scaling functions
def _get_interp_method(interp, sizes=()):
    """Get the interpolation method for resize functions.
    The major purpose of this function is to wrap a random interp method selection
    and a auto-estimation method.
​
    Parameters
    ----------
    interp : int
        interpolation method for all resizing operations
​
        Possible values:
        0: Nearest Neighbors Interpolation.
        1: Bilinear interpolation.
        2: Area-based (resampling using pixel area relation). It may be a
        preferred method for image decimation, as it gives moire-free
        results. But when the image is zoomed, it is similar to the Nearest
        Neighbors method. (used by default).
        3: Bicubic interpolation over 4x4 pixel neighborhood.
        4: Lanczos interpolation over 8x8 pixel neighborhood.
        9: Cubic for enlarge, area for shrink, bilinear for others
        10: Random select from interpolation method metioned above.
        Note:
        When shrinking an image, it will generally look best with AREA-based
        interpolation, whereas, when enlarging an image, it will generally look best
        with Bicubic (slow) or Bilinear (faster but still looks OK).
        More details can be found in the documentation of OpenCV, please refer to
        http://docs.opencv.org/master/da/d54/group__imgproc__transform.html.
    sizes : tuple of int
        (old_height, old_width, new_height, new_width), if None provided, auto(9)
        will return Area(2) anyway.
​
    Returns
    -------
    int
        interp method from 0 to 4
    """
    if interp == 9:
        if sizes:
            assert len(sizes) == 4
            oh, ow, nh, nw = sizes
            if nh > oh and nw > ow:
                return 2
            elif nh < oh and nw < ow:
                return 3
            else:
                return 1
        else:
            return 2
    if interp == 10:
        return random.randint(0, 4)
    if interp not in (0, 1, 2, 3, 4):
        raise ValueError('Unknown interp method %d' % interp)


def resize_short_within(img, short=512, max_size=1024, mult_base=32, interp=2):
    """
    resizes the short side of the image so the aspect ratio remains the same AND the short
    side matches the convolutional layer for the network
​
    Args:
    -----
    img: np.array
        image you want to resize
    short: int
        the size to reshape the image to
    max_size: int
        the max size of the short side
    mult_base: int
        the size scale to readjust the resizer
    interp: int
        see '_get_interp_method'
    Returns:
    --------
    img: np.array
        the resized array
    """
    h, w, _ = img.shape
    im_size_min, im_size_max = (h, w) if w > h else (w, h)
    scale = float(short) / float(im_size_min)
    if np.round(scale * im_size_max / mult_base) * mult_base > max_size:
        # fit in max_size
        scale = float(np.floor(max_size / mult_base) * mult_base) / float(im_size_max)
    new_w, new_h = (
        int(np.round(w * scale / mult_base) * mult_base),
        int(np.round(h * scale / mult_base) * mult_base)
    )
    img = cv2.resize(img, (new_w, new_h),
                     interpolation=_get_interp_method(interp, (h, w, new_h, new_w)))
    return img


if __name__ == '__main__':

    run()
